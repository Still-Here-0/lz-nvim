-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here


----------------------------------
--- User Defined Code Commands ---
----------------------------------
-- The "<leader>cu" group label lives in lua/plugins/which-key.lua.

-- Reindex / restart Pyright. Bound only while pyright is attached to the buffer.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "pyright" then
      return
    end
    vim.keymap.set("n", "<leader>cur", function()
      client:request("workspace/executeCommand", {
        command = "pyright.restartserver",
        arguments = {},
      }, function(err)
        if err then
          vim.notify("Pyright reindex failed: " .. (err.message or "unknown"), vim.log.levels.ERROR)
        else
          vim.notify("Pyright reindexed", vim.log.levels.INFO)
        end
      end, args.buf)
    end, { desc = "Reindex Pyright", buffer = args.buf })
  end,
})
