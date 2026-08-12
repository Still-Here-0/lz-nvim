-- nabla.nvim — always-on 2D ASCII/Unicode math rendered as a BLOCK below each
-- expression, with the SAME token coloring as nabla's popup (<leader>mp).
--
--   * `$$ ... $$` display blocks -> raw source kept, colored art below.
--   * inline `$...$`             -> raw `$...$` concealed, colored art below.
--
-- We bypass nabla's built-in inline mode and instead drive its parser/ascii
-- modules directly, then place the art with `virt_lines` and reproduce its
-- `colorize_virt` highlighting so numbers/vars/operators are themed, not gray.
--
-- latex2text is disabled (render-markdown.lua) so only ONE renderer draws.
-- Unsupported constructs (matrices, \begin{cases}, \binom) are skipped per
-- expression via pcall — the rest of the buffer still renders.

local math_ft = { markdown = true, tex = true, quarto = true }
local ns = vim.api.nvim_create_namespace("nabla_block_art")
local enabled = {} ---@type table<integer, boolean>

-- Port of nabla's local `colorize_virt`: walk the ascii tree `g` and tag each
-- cell in `cells` (cells[row][col] = { char, hlgroup }) with a highlight.
local function colorize(g, cells, first_dx, dx, dy)
  local function tag(off, y, w, hl)
    local rowcells = cells[y]
    if not rowcells then return end
    for i = 1, w do
      if rowcells[off + i] then rowcells[off + i][2] = hl end
    end
  end

  if g.t == "num" then
    local off = (dy == 0) and first_dx or dx
    tag(off, dy + 1, g.w, "@number")
  elseif g.t == "sym" then
    local off = (dy == 0) and first_dx or dx
    if string.match(g.content[1], "^%a") then
      tag(off, dy + 1, g.w, "@string")
    elseif string.match(g.content[1], "^%d") then
      tag(off, dy + 1, g.w, "@number")
    else
      for y = 1, g.h do
        local o = (y + dy == 1) and first_dx or dx
        tag(o, dy + y, g.w, "@operator")
      end
    end
  elseif g.t == "op" or g.t == "par" then
    for y = 1, g.h do
      local o = (y + dy == 1) and first_dx or dx
      tag(o, dy + y, g.w, "@operator")
    end
  elseif g.t == "var" then
    local off = (dy == 0) and first_dx or dx
    tag(off, dy + 1, g.w, "@string")
  end

  for _, child in ipairs(g.children or {}) do
    colorize(child[1], cells, child[2] + first_dx, child[2] + dx, child[3] + dy)
  end
end

-- Build colored virt_lines for a math expression string. Returns nil on parse
-- failure (unsupported construct).
local function build_virt_lines(expr)
  local ok_l, latex = pcall(require, "nabla.latex")
  local ok_a, ascii = pcall(require, "nabla.ascii")
  if not (ok_l and ok_a) then return nil end

  local ok1, tree = pcall(latex.parse_all, expr)
  if not ok1 or not tree then return nil end
  local ok2, g = pcall(ascii.to_ascii, { tree }, 1)
  if not ok2 or not g then return nil end

  local drawing = {}
  for row in vim.gsplit(tostring(g), "\n") do
    -- U+2015 (HORIZONTAL BAR) renders with gaps in many fonts; swap for the
    -- connecting U+2500 (BOX DRAWINGS LIGHT HORIZONTAL) so bars look solid.
    row = row:gsub("\u{2015}", "\u{2500}")
    drawing[#drawing + 1] = row
  end
  if #drawing == 0 then return nil end

  -- explode each line into per-character { char, hl } cells (default Normal)
  local cells = {}
  for r, line in ipairs(drawing) do
    local rowcells = {}
    for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
      rowcells[#rowcells + 1] = { ch, "Normal" }
    end
    cells[r] = rowcells
  end

  colorize(g, cells, 0, 0, 0)

  -- convert cells -> virt_lines chunks
  local vlines = {}
  for _, rowcells in ipairs(cells) do
    local chunks = {}
    for _, c in ipairs(rowcells) do
      chunks[#chunks + 1] = { c[1], c[2] }
    end
    vlines[#vlines + 1] = chunks
  end
  return vlines
end


-- Build colored ROWS of chunks for a math expression, plus the baseline row
-- index (g.my, 0-based). Returns rows, baseline0 or nil on parse failure.
local function build_rows(expr)
  local ok_l, latex = pcall(require, "nabla.latex")
  local ok_a, ascii = pcall(require, "nabla.ascii")
  if not (ok_l and ok_a) then return nil end

  local ok1, tree = pcall(latex.parse_all, expr)
  if not ok1 or not tree then return nil end
  local ok2, g = pcall(ascii.to_ascii, { tree }, 1)
  if not ok2 or not g then return nil end

  local drawing = {}
  for row in vim.gsplit(tostring(g), "\n") do
    drawing[#drawing + 1] = row
  end
  if #drawing == 0 then return nil end

  local cells = {}
  for r, line in ipairs(drawing) do
    local rowcells = {}
    for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
      rowcells[#rowcells + 1] = { ch, "Normal" }
    end
    cells[r] = rowcells
  end

  colorize(g, cells, 0, 0, 0)

  local rows = {}
  for _, rowcells in ipairs(cells) do
    local chunks = {}
    for _, c in ipairs(rowcells) do
      chunks[#chunks + 1] = { c[1], c[2] }
    end
    rows[#rows + 1] = chunks
  end
  return rows, (g.my or 0)
end

-- Merge accumulated inline art rows into virt_lines. `acc` is a list (one per
-- virtual-row level) of placements { col, row }, where `row` is a chunk list.
-- Each placement is laid onto a shared cell grid at its display column; the
-- grid is then flattened back to a single chunk row. This lets several inline
-- expressions on one buffer line share the SAME virtual rows instead of
-- stacking on separate ones.
local function merge_virt_rows(acc)
  local out = {}
  for _, level in ipairs(acc) do
    local cells = {} -- 1-indexed by display column -> { char, hl }
    local maxc = 0
    for _, place in ipairs(level) do
      local c = place.col -- 0-based display col before the math
      for _, chunk in ipairs(place.row) do
        local text, hl = chunk[1], chunk[2]
        for _, cp in ipairs(vim.fn.str2list(text)) do
          c = c + 1
          local ch = vim.fn.nr2char(cp)
          if ch ~= " " then cells[c] = { ch, hl } end
          if c > maxc then maxc = c end
        end
      end
    end
    local chunks = {}
    for c = 1, maxc do
      local cell = cells[c] or { " ", "Normal" }
      chunks[#chunks + 1] = cell
    end
    out[#out + 1] = chunks
  end
  return out
end

local function render(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not math_ft[vim.bo[buf].filetype] then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  vim.wo.conceallevel = 2
  vim.wo.concealcursor = "nc"

  local i = 1
  while i <= #lines do
    if lines[i]:match("^%s*%$%$%s*$") then
      -- display block: keep source, art below closing fence
      local j = i + 1
      local body = {}
      while j <= #lines and not lines[j]:match("^%s*%$%$%s*$") do
        body[#body + 1] = lines[j]
        j = j + 1
      end
      if #body > 0 then
        local vl = build_virt_lines(table.concat(body, " "))
        if vl then
          local anchor = (j <= #lines) and (j - 1) or (j - 2)
          vim.api.nvim_buf_set_extmark(buf, ns, anchor, 0, { virt_lines = vl })
        end
      end
      i = j
    else
      -- inline `$...$` (all occurrences on the line): conceal each raw span and
      -- draw the art IN PLACE. The baseline row becomes inline virt_text at the
      -- math column; rows above/below are ACCUMULATED across all expressions on
      -- the line and merged, so two expressions never stack on separate virtual
      -- rows (which looked garbled). `above_acc`/`below_acc` are lists of
      -- { col = display_col, row = chunk_row }, nearest-to-baseline first.
      local above_acc, below_acc = {}, {}
      -- Track the running ON-SCREEN column. Earlier `$...$` on this line get
      -- concealed and replaced by inline virt_text of a DIFFERENT width, so the
      -- source column is not the display column. We advance `disp_col` by the
      -- display width of literal text plus each baseline's virt_text width.
      local disp_col = 0
      local prev_e = 0
      local from = 1
      while true do
        local s, e = lines[i]:find("%$[^%$]+%$", from)
        if not s then break end
        from = e + 1
        -- literal text between the previous match (or line start) and this `$`
        disp_col = disp_col + vim.fn.strdisplaywidth(lines[i]:sub(prev_e + 1, s - 1))
        prev_e = e or prev_e
        local expr = vim.trim(lines[i]:sub(s + 1, e - 1))
        local rows, base0 = build_rows(expr)
        if rows then
          local base = base0 + 1 -- 1-indexed baseline row
          local col = disp_col -- on-screen column where the baseline starts
          -- advance past this expression's inline baseline width
          local basew = 0
          for _, ch in ipairs(rows[base]) do
            basew = basew + vim.fn.strdisplaywidth(ch[1])
          end
          disp_col = disp_col + basew
          -- baseline row: inline virt_text where the math was + conceal source
          vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s - 1, {
            end_col = e,
            conceal = "",
            virt_text = rows[base],
            virt_text_pos = "inline",
          })
          local ai = 0
          for r = base - 1, 1, -1 do -- nearest first
            ai = ai + 1
            above_acc[ai] = above_acc[ai] or {}
            table.insert(above_acc[ai], { col = col, row = rows[r] })
          end
          local bi = 0
          for r = base + 1, #rows do
            bi = bi + 1
            below_acc[bi] = below_acc[bi] or {}
            table.insert(below_acc[bi], { col = col, row = rows[r] })
          end
        end
      end
      local above = merge_virt_rows(above_acc)
      local below = merge_virt_rows(below_acc)
      if #above > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
          virt_lines = above,
          virt_lines_above = true,
        })
      end
      if #below > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { virt_lines = below })
      end
    end
    i = i + 1
  end
  enabled[buf] = true
end

local function clear(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  enabled[buf] = false
end

local function toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if enabled[buf] then clear(buf) else render(buf) end
end

return {
  {
    "jbyuki/nabla.nvim",
    ft = { "markdown", "tex", "quarto" },
    config = function()
      local grp = vim.api.nvim_create_augroup("NablaBlock", { clear = true })

      vim.api.nvim_create_autocmd({ "FileType" }, {
        group = grp,
        pattern = { "markdown", "tex", "quarto" },
        callback = function(a)
          -- Buffer-local keymaps so <leader>m* only exist in math filetypes.
          vim.keymap.set("n", "<leader>mm", function() toggle(a.buf) end,
            { buffer = a.buf, desc = "Toggle inline math (nabla)" })
          vim.keymap.set("n", "<leader>mp", function() require("nabla").popup() end,
            { buffer = a.buf, desc = "Popup math under cursor (nabla)" })
          vim.schedule(function() render(a.buf) end)
        end,
      })

      vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
        group = grp,
        pattern = { "*.md", "*.markdown", "*.tex", "*.qmd" },
        callback = function(a)
          if enabled[a.buf] then
            vim.schedule(function() render(a.buf) end)
          end
        end,
      })
      vim.schedule(function() render() end)
    end,
  },
}
