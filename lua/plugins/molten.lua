-- Jupyter-kernel workflow inside Neovim — the closest thing to VS Code's
-- Data Wrangler for *live* DataFrame exploration. Run Python cells against a
-- kernel and see df/plots rendered inline (as images via image.nvim).
--
-- Two separate Pythons are involved (don't confuse them):
--   * HOST  — runs Molten's own plugin code; needs pynvim + jupyter_client.
--             Neovim has ONE host globally (g:python3_host_prog below). It never
--             runs your code, so pinning it does NOT affect your projects. This
--             config auto-provisions it (see build) so a fresh machine works.
--   * KERNEL — runs your cells; should match the project venv. Bootstrap it per
--             project with <leader>jk (installs ipykernel + registers a kernel),
--             then :MoltenInit <name>.

-- The dedicated HOST venv. Config is synced across machines but this venv is
-- not, so it's created on demand by the build hook below.
local host_dir = vim.fn.expand("~/.venvs/neovim")
local host_py = host_dir .. "/bin/python"

-- Create the host venv + install Molten's Python deps if it doesn't exist yet.
-- Synchronous (runs inside lazy's build step, which shows progress). Idempotent:
-- a no-op once the venv is present, so it's cheap to re-run on plugin updates.
local function ensure_host_venv()
  if vim.fn.filereadable(host_py) == 1 then
    return
  end
  local base = vim.fn.exepath("python3")
  if base == "" then
    error("Molten: no python3 on PATH to create the host venv")
  end
  local r = vim.system({ base, "-m", "venv", host_dir }):wait()
  if r.code ~= 0 then
    error("Molten: venv create failed\n" .. (r.stderr or ""))
  end
  r = vim.system({
    host_py, "-m", "pip", "install", "-q", "--upgrade",
    "pip", "pynvim", "jupyter_client", "ipykernel", "nbformat",
    "pandas", "pyarrow", "matplotlib", "pylatexenc",
  }):wait()
  if r.code ~= 0 then
    error("Molten: host pip install failed\n" .. (r.stderr or ""))
  end
  -- Register the host venv as a general-purpose "molten" scratch kernel
  -- (kernelspecs aren't synced either, so do it here for machine parity).
  vim.system({
    host_py, "-m", "ipykernel", "install", "--user",
    "--name", "molten", "--display-name", "Molten (host venv)",
  }):wait()
end

-- Bootstrap the CURRENT project's interpreter as a Molten kernel.
-- Resolves the project Python (activated venv → ./.venv → PATH `python`, which
-- respects pyenv shims / `pyenv local`), installs ipykernel into it, and
-- registers a Jupyter kernel named after the project directory.
local function setup_project_kernel()
  local cwd = vim.fn.getcwd()
  local py
  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    py = vim.env.VIRTUAL_ENV .. "/bin/python"
  elseif vim.fn.filereadable(cwd .. "/.venv/bin/python") == 1 then
    py = cwd .. "/.venv/bin/python"
  else
    py = vim.fn.exepath("python")
    if py == "" then py = vim.fn.exepath("python3") end
  end
  if not py or py == "" then
    vim.notify("Molten: could not find a project Python", vim.log.levels.ERROR)
    return
  end

  local name = vim.fn.fnamemodify(cwd, ":t")
  vim.notify(("Molten: installing ipykernel into %s …"):format(py), vim.log.levels.INFO)
  vim.system({ py, "-m", "pip", "install", "-q", "ipykernel" }, { text = true }, function(r1)
    if r1.code ~= 0 then
      vim.schedule(function()
        vim.notify("Molten: pip install failed\n" .. (r1.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end
    vim.system({
      py, "-m", "ipykernel", "install", "--user",
      "--name", name, "--display-name", "Molten: " .. name,
    }, { text = true }, function(r2)
      vim.schedule(function()
        if r2.code ~= 0 then
          vim.notify("Molten: kernel register failed\n" .. (r2.stderr or ""), vim.log.levels.ERROR)
        else
          vim.notify(("Molten: kernel '%s' ready → :MoltenInit %s"):format(name, name), vim.log.levels.INFO)
        end
      end)
    end)
  end)
end

-- Show a notebook's SAVED outputs as soon as it opens. jupytext.nvim converts
-- the .ipynb to markdown and drops the outputs; :MoltenImportOutput reads them
-- back from the .ipynb, matching cells by their code. Molten only holds outputs
-- on a running kernel, so this starts one, but only for notebooks that actually
-- have saved outputs. Kernel choice: the project kernel from <leader>jk (named
-- after the cwd) for Python notebooks, else the notebook's own kernelspec.
local function read_notebook(path)
  local ok, nb = pcall(function()
    local text = table.concat(vim.fn.readfile(path), "\n")
    return vim.json.decode(text, { luanil = { object = true, array = true } })
  end)
  return ok and nb or nil
end

local function has_saved_outputs(nb)
  for _, cell in ipairs(nb.cells or {}) do
    if cell.cell_type == "code" and cell.outputs and #cell.outputs > 0 then
      return true
    end
  end
  return false
end

local function pick_kernel(nb)
  local available = vim.fn.MoltenAvailableKernels()
  local meta = nb.metadata or {}
  local spec = meta.kernelspec or {}
  local lang = spec.language or (meta.language_info or {}).name
  local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  if lang == "python" and vim.tbl_contains(available, project) then
    return project
  end
  if spec.name and vim.tbl_contains(available, spec.name) then
    return spec.name
  end
end

local function show_saved_outputs(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if not path:match("%.ipynb$") or vim.b[buf].molten_outputs_imported then
    return
  end
  vim.b[buf].molten_outputs_imported = true
  -- Deferred: FileType fires inside jupytext.nvim's BufReadCmd, before the
  -- buffer is fully set up.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local nb = read_notebook(path)
    if not nb or not has_saved_outputs(nb) then
      return
    end
    vim.api.nvim_buf_call(buf, function()
      local ok, err = pcall(function()
        if #vim.fn.MoltenRunningKernels(true) == 0 then
          local kernel = pick_kernel(nb)
          if not kernel then
            vim.notify(
              "Molten: no kernel matches this notebook; run :MoltenInit, then :MoltenImportOutput",
              vim.log.levels.WARN
            )
            return
          end
          vim.cmd("MoltenInit " .. kernel)
        end
        vim.cmd("MoltenImportOutput")
      end)
      if not ok then
        vim.notify("Molten: could not show saved outputs\n" .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Fixes for the plots Molten shows under cells (image.nvim ids "virt-<file>"):
--   * image.nvim deletes an image when its buffer leaves the window (its
--     BufLeave handler), and Molten never re-adds the image of an output it
--     already showed, so plots vanished for good after switching buffers. Keep
--     those Image objects and render them again when their buffer is back.
--   * Molten's text for the cell (status line, prints) and image.nvim's blank
--     padding were two virtual-line blocks on the cell's last line. Neovim does
--     not keep a stable order between them (that line carries many extmarks),
--     and image.nvim drew the image at the top, over the text. Instead, the
--     image reserves no padding of its own: its blank rows are appended to
--     Molten's text block, and the image is drawn just below the text.
-- One image per cell: several images in one cell share a position and overlap.
local function molten_text_block(img)
  local ns = vim.api.nvim_get_namespaces()["molten-extmarks"]
  if not ns or not img.buffer or not vim.api.nvim_buf_is_valid(img.buffer) then
    return nil
  end
  local row = img.geometry.y
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(img.buffer, ns, { row, 0 }, { row, -1 }, { details = true })) do
    if m[4].virt_lines then
      return ns, m
    end
  end
end

local function keep_cell_images()
  local ok_image, image = pcall(require, "image")
  local ok_bridge, bridge = pcall(require, "load_image_nvim")
  if not ok_image or not ok_bridge or type(bridge) ~= "table" or not bridge.image_api then
    return
  end
  local bridge_api = bridge.image_api
  local cell_images = {} -- image.nvim id -> Image shown under a cell
  local latest = {} -- Molten's identifier (the image file) -> the Image the bridge holds for it
  local appended = {} -- "buf:extmark id" of a Molten text block -> { text = lines, blank = rows added }

  local function text_lines(img)
    local _, m = molten_text_block(img)
    if not m then
      return 0
    end
    local added = appended[img.buffer .. ":" .. m[1]]
    return added and added.text or #m[4].virt_lines
  end

  local function reserve_rows_after_text(img, rows)
    local ns, m = molten_text_block(img)
    if not m or type(rows) ~= "number" or rows <= 0 then
      return
    end
    local key = img.buffer .. ":" .. m[1]
    local added = appended[key]
    if added and added.blank == rows then
      return
    end
    local lines = vim.list_slice(m[4].virt_lines, 1, added and added.text or #m[4].virt_lines)
    local text = #lines
    for _ = 1, rows do
      lines[#lines + 1] = { { " ", "" } }
    end
    vim.api.nvim_buf_set_extmark(img.buffer, ns, m[2], m[3], { id = m[1], virt_lines = lines })
    appended[key] = { text = text, blank = rows }
  end

  -- Every render goes through Image:render (Molten's, image.nvim's own re-renders
  -- on scroll, and the async one after ImageMagick resizes), so wrap the method
  -- once on the shared Image class.
  local render_wrapped = false
  local function render_cell_images_below_text(img)
    local Image = getmetatable(img)
    if render_wrapped or type(Image) ~= "table" or type(Image.render) ~= "function" then
      return
    end
    render_wrapped = true
    local render = Image.render
    Image.render = function(self, geometry)
      if cell_images[self.id] ~= self then
        return render(self, geometry)
      end
      self.render_offset_top = text_lines(self)
      local result = render(self, geometry)
      local rendered = self.rendered_geometry and self.rendered_geometry.height
      reserve_rows_after_text(self, rendered or self.geometry.height)
      return result
    end
  end

  local from_file = image.from_file
  image.from_file = function(path, opts)
    local under_cell = opts and type(opts.id) == "string" and opts.id:sub(1, 5) == "virt-"
    if under_cell then
      -- rows are reserved in Molten's text block instead; inline keeps the
      -- image following its line when text above it changes
      opts.with_virtual_padding = false
      opts.inline = true
    end
    local img = from_file(path, opts)
    if img then
      render_cell_images_below_text(img)
    end
    if img and under_cell then
      -- a re-run cell gets a new image at the same line; drop the old one
      for id, other in pairs(cell_images) do
        if other.buffer == img.buffer and other.geometry.y == img.geometry.y then
          cell_images[id] = nil
        end
      end
      cell_images[img.id] = img
    end
    latest[path] = img
    return img
  end

  local clear = bridge_api.clear
  bridge_api.clear = function(identifier)
    local img = latest[identifier]
    if img and cell_images[img.id] == img then
      cell_images[img.id] = nil
    end
    return clear(identifier)
  end

  local clear_all = bridge_api.clear_all
  bridge_api.clear_all = function()
    cell_images = {}
    appended = {}
    return clear_all()
  end

  local group = vim.api.nvim_create_augroup("MoltenCellImages", { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(a)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(a.buf) then
          return
        end
        for _, img in pairs(cell_images) do
          if img.buffer == a.buf then
            local win = img.window
            if not (win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == a.buf) then
              win = vim.fn.bufwinid(a.buf)
              img.window = win ~= -1 and win or nil
            end
            if img.window then
              pcall(img.render, img)
            end
          end
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(a)
      for id, img in pairs(cell_images) do
        if img.buffer == a.buf then
          cell_images[id] = nil
        end
      end
      local prefix = a.buf .. ":"
      for key in pairs(appended) do
        if key:sub(1, #prefix) == prefix then
          appended[key] = nil
        end
      end
    end,
  })
end

return {
  -- Inline image rendering. Ghostty speaks the kitty graphics protocol.
  {
    "3rd/image.nvim",
    -- magick_cli avoids the fiddly luarocks `magick` rock; it shells out to
    -- the ImageMagick CLI instead. Requires ImageMagick installed.
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      hijack_file_patterns = {},
      integrations = {}, -- don't auto-render images in markdown; molten drives it
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
    },
  },

  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    -- Runs on install/update: provision the host venv (if missing) BEFORE
    -- registering the remote plugin, so a freshly-cloned config on a second
    -- machine self-heals instead of failing on a missing jupyter_client.
    build = function()
      ensure_host_venv()
      -- Regenerate the manifest in a CLEAN subprocess. Doing it in this session
      -- is unreliable: if the python3 host already started with a bad
      -- interpreter (e.g. init pointed at a not-yet-created venv) it stays
      -- poisoned and UpdateRemotePlugins yields an EMPTY manifest that then
      -- persists (build won't re-run on restart). `-u NORC` loads no user
      -- config (so no lazy recursion) but keeps runtime plugins, and inherits
      -- NVIM_APPNAME so the manifest lands in the right data dir.
      local molten_dir = vim.fn.stdpath("data") .. "/lazy/molten-nvim"
      local r = vim.system({
        vim.v.progpath, "--headless", "-u", "NORC",
        "-c", "set rtp+=" .. molten_dir,
        "-c", "let g:python3_host_prog='" .. host_py .. "'",
        "-c", "UpdateRemotePlugins",
        "-c", "qa",
      }):wait()
      if r.code ~= 0 then
        vim.notify("Molten: manifest regeneration failed\n" .. (r.stderr or ""), vim.log.levels.WARN)
      end
    end,
    ft = { "python", "markdown", "quarto" },
    init = function()
      -- HOST interpreter (see header). Must have pynvim + jupyter_client.
      -- System Python is PEP668-locked and can't get jupyter_client, so this
      -- points at a dedicated venv. This is Molten's plumbing only — your
      -- project code still runs in the KERNEL you pick with <leader>jk.
      vim.g.python3_host_prog = host_py
      -- jupyter_client (8.x) writes kernel-<uuid>.json into the runtime dir but
      -- does NOT create it; a missing dir makes MoltenInit fail with ENOENT.
      -- Ensure it exists (respects XDG_DATA_HOME, falls back to ~/.local/share).
      local data_home = vim.env.XDG_DATA_HOME
      if not data_home or data_home == "" then
        data_home = vim.fn.expand("~/.local/share")
      end
      vim.fn.mkdir(data_home .. "/jupyter/runtime", "p")
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      -- Show short outputs as virtual text next to the cell; open the float for big ones.
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = false
    end,
    config = function()
      if vim.g.molten_image_provider == "image.nvim" then
        keep_cell_images()
      end
      local function set_maps(buf)
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end
        map("n", "<leader>ji", "<cmd>MoltenInit<cr>", "Init kernel")
        map("n", "<leader>jk", setup_project_kernel, "Setup project kernel (pip install ipykernel)")
        map("n", "<leader>je", "<cmd>MoltenEvaluateOperator<cr>", "Evaluate operator")
        map("n", "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", "Evaluate line")
        map("n", "<leader>jr", "<cmd>MoltenReevaluateCell<cr>", "Re-evaluate cell")
        map("v", "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>gv", "Evaluate selection")
        map("n", "<leader>jo", "<cmd>MoltenShowOutput<cr>", "Show output")
        map("n", "<leader>jh", "<cmd>MoltenHideOutput<cr>", "Hide output")
        map("n", "<leader>jd", "<cmd>MoltenDelete<cr>", "Delete cell")
      end
      -- Buffer-local keymaps so <leader>j* only exist in molten filetypes.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("MoltenKeys", { clear = true }),
        pattern = { "python", "markdown", "quarto" },
        callback = function(a)
          set_maps(a.buf)
          show_saved_outputs(a.buf)
        end,
      })
      -- Plugin lazy-loads on `ft`, so the triggering buffer's FileType event
      -- has already fired; apply the maps to it now.
      local ft = vim.bo.filetype
      if ft == "python" or ft == "markdown" or ft == "quarto" then
        set_maps(0)
        show_saved_outputs(vim.api.nvim_get_current_buf())
      end
    end,
  },
}
