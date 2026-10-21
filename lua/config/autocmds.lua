-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Format-on-save only for text/markup filetypes; vim.g.autoformat = false
-- keeps code files manual (<leader>cf).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("text_autoformat", { clear = true }),
  pattern = { "markdown", "markdown.mdx", "html", "tex" },
  callback = function()
    vim.b.autoformat = true
  end,
})

-- Disable soft-wrap in markdown. render-markdown.nvim paints table borders and
-- cell padding as virtual text keyed to logical lines; when a wide row soft-wraps
-- the overlay desyncs and the table renders with phantom line breaks. LazyVim's
-- `lazyvim_wrap_spell` group turns wrap on for markdown, so re-disable it here
-- (this runs after LazyVim's core autocmds). Wide tables scroll horizontally
-- instead; spell stays on. Tradeoff: long prose no longer wraps either — prettier
-- reflows it to 80 cols on save (see conform.lua).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("markdown_nowrap", { clear = true }),
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    vim.opt_local.wrap = false
  end,
})

if vim.fn.has("wsl") == 1 then
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = vim.api.nvim_create_augroup("wsl_open_images", { clear = true }),
    pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp", "*.tiff", "*.avif", "*.heic" },
    callback = function(event)
      local windows_path = vim.system({ "wslpath", "-w", vim.api.nvim_buf_get_name(event.buf) }):wait().stdout
      vim.system({ "explorer.exe", vim.trim(windows_path) }, { detach = true })
      vim.bo[event.buf].buftype = "nofile"
      vim.schedule(function()
        Snacks.bufdelete(event.buf)
      end)
    end,
  })
end
