-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here


----------------------------------
--- User Defined Code Commands ---
----------------------------------
local wk = require("which-key")
wk.add({
  { "<leader>cu", group = "User Keymaps" },
})

-- Restart LSP (python)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(event)
    vim.keymap.set("n", "<leader>cur", function()
      local clients = vim.lsp.get_clients({ name = "pyright" })
      for _, client in ipairs(clients) do
        client.request("workspace/executeCommand", {
          command = "pyright.restartserver",
          arguments = {},
        }, nil, 0)
      end
      vim.notify("Pyright reindexed", vim.log.levels.INFO)
    end, { desc = "Reindex Pyright", buffer = event.buf })
  end,
})
