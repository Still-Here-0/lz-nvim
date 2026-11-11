-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here


----------------------------------
--- User Defined Code Commands ---
----------------------------------
-- The "<leader>cu" group label lives in lua/plugins/which-key.lua.

vim.keymap.set("n", "<leader>fuo", function()
  require("util.open_external")(vim.fn.expand("%:p"))
end, { desc = "Open file outside Neovim" })

local function rename_path(from, to)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].modified and (name == from or vim.startswith(name, from .. "/")) then
      vim.notify("Save " .. name .. " before renaming it", vim.log.levels.WARN)
      return false
    end
  end
  local renamed = false
  Snacks.rename.rename_file({
    from = from,
    to = to,
    on_rename = function(_, _, ok)
      renamed = ok
    end,
  })
  if not renamed then
    return false
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.startswith(name, from .. "/") then
      local new_buf = vim.fn.bufadd(to .. name:sub(#from + 1))
      vim.bo[new_buf].buflisted = true
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        vim.api.nvim_win_set_buf(win, new_buf)
      end
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  return true
end

local function replace_matches(items, old, new)
  table.sort(items, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] < b.pos[1]
    end
    return a.pos[2] > b.pos[2]
  end)
  local changed, swapped = {}, 0
  for _, item in ipairs(items) do
    local buf = vim.fn.bufadd(item.file)
    vim.fn.bufload(buf)
    local row, col = item.pos[1], item.pos[2]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    if line and line:sub(col + 1, col + #old) == old then
      line = line:sub(1, col) .. new .. line:sub(col + #old + 1)
      vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { line })
      changed[buf] = true
      swapped = swapped + 1
    end
  end
  for buf in pairs(changed) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent update")
    end)
  end
  return swapped
end

vim.keymap.set("n", "<leader>fur", function()
  local from = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype == "snacks_picker_list" then
    local explorer = Snacks.picker.get({ source = "explorer" })[1]
    from = explorer and Snacks.picker.util.path(explorer:current()) or ""
  end
  if from == "" then
    return
  end
  from = vim.fs.normalize(from)
  local name_part = vim.fn.isdirectory(from) == 1 and ":t" or ":t:r"
  vim.ui.input({
    prompt = "New name: ",
    default = vim.fn.fnamemodify(from, ":."),
    completion = "file",
  }, function(value)
    if not value or value == "" then
      return
    end
    local to = vim.fs.normalize(vim.fn.fnamemodify(value, ":p"))
    if to == from then
      return
    end

    local old = vim.fn.fnamemodify(from, name_part)
    local new = vim.fn.fnamemodify(to, name_part)
    local exact, options = {}, {}
    for _, out in ipairs(vim.fn.systemlist({ "rg", "--vimgrep", "--fixed-strings", "--", old })) do
      local file, lnum, col, line = out:match("^(.-):(%d+):(%d+):(.*)$")
      if file then
        lnum, col = tonumber(lnum), tonumber(col)
        local item = {
          file = vim.fs.abspath(file),
          pos = { lnum, col - 1 },
          end_pos = { lnum, col - 1 + #old },
          line = line,
          text = file .. " " .. line,
        }
        local before = line:sub(col - 1, col - 1)
        local after = line:sub(col + #old, col + #old)
        if before:match("[%w_]") or after:match("[%w_]") then
          table.insert(options, item)
        else
          table.insert(exact, item)
        end
      end
    end

    local seen = {}
    for _, file in ipairs(vim.fn.systemlist({ "rg", "--files" })) do
      local rel = file
      while rel ~= "." and not seen[rel] do
        seen[rel] = true
        local path = vim.fs.abspath(rel)
        if vim.fs.basename(rel):find(old, 1, true) and path ~= from and not vim.startswith(path, from .. "/") then
          table.insert(options, { file = path, dir = vim.fn.isdirectory(path) == 1, text = rel })
        end
        rel = vim.fs.dirname(rel)
      end
    end

    if #exact + #options == 0 then
      if rename_path(from, to) then
        vim.notify("No references to " .. old, vim.log.levels.INFO)
      end
      return
    end

    Snacks.picker.pick({
      title = old .. " -> " .. new,
      items = vim.list_extend(vim.list_slice(exact), options),
      format = "file",
      on_show = function(picker)
        picker.list:set_selected(exact)
      end,
      confirm = function(picker)
        local items = picker:selected({ fallback = true })
        picker:close()
        if not rename_path(from, to) then
          return
        end
        local matches, paths = {}, {}
        for _, item in ipairs(items) do
          if item.file == from or vim.startswith(item.file, from .. "/") then
            item.file = to .. item.file:sub(#from + 1)
          end
          table.insert(item.pos and matches or paths, item)
        end
        local changed = replace_matches(matches, old, new)
        table.sort(paths, function(a, b)
          return #a.file > #b.file
        end)
        local renamed = 0
        for _, item in ipairs(paths) do
          local name = vim.fs.basename(item.file):gsub(vim.pesc(old), (new:gsub("%%", "%%%%")))
          if rename_path(item.file, vim.fs.joinpath(vim.fs.dirname(item.file), name)) then
            renamed = renamed + 1
          end
        end
        vim.notify("Swapped " .. changed .. " reference(s), renamed " .. renamed .. " path(s)", vim.log.levels.INFO)
      end,
    })
  end)
end, { desc = "Rename matching references" })

-- Reindex / restart Pyright. Bound only while pyright is attached to the buffer.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "basedpyright" then
      return
    end
    vim.keymap.set("n", "<leader>cur", function()
      for ns, info in pairs(vim.diagnostic.get_namespaces()) do
        if vim.startswith(info.name, "nvim.lsp.basedpyright.") then
          vim.diagnostic.reset(ns)
        end
      end
      vim.cmd("lsp restart basedpyright")
    end, { desc = "Reindex Pyright", buffer = args.buf })

    vim.keymap.set("n", "<leader>cut", function()
      local modes = { "off", "basic", "standard", "strict", "recommended", "all" }
      vim.ui.select(modes, { prompt = "Type checking mode" }, function(mode)
        if not mode then
          return
        end
        client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
          basedpyright = { analysis = { typeCheckingMode = mode } },
        })
        client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        vim.notify("Type checking mode: " .. mode, vim.log.levels.INFO)
      end)
    end, { desc = "Type checking mode", buffer = args.buf })
  end,
})
