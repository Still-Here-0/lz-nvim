-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.winbar = "%=%m %f"
vim.g.autoformat = false
vim.opt.swapfile = false

-- Keep AI suggestions out of the blink.cmp completion menu. LazyVim's AI
-- extras only register a completion source when this is true; completion stays
-- LSP/snippet/path/buffer driven. In-editor AI assistance comes from
-- sidekick.nvim's Next Edit Suggestions instead (see plugins/sidekick.lua).
vim.g.ai_cmp = false
