-- Run whole notebook cells with one key. jupytext.nvim shows a .ipynb as a
-- markdown buffer whose code cells are ```python blocks; quarto-nvim finds the
-- block under the cursor and sends it to the Molten kernel (see molten.lua),
-- and otter.nvim gives those blocks Python LSP features (completion, hover,
-- diagnostics) inside the markdown buffer.
--
-- Only activated in notebook buffers (name ends in .ipynb), so plain markdown
-- files are left alone. Start the kernel first (<leader>ji / :MoltenInit).
return {
  {
    "quarto-dev/quarto-nvim",
    dependencies = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
    ft = { "quarto", "markdown" },
    opts = {
      lspFeatures = {
        enabled = true,
        chunks = "all",
        languages = { "python" },
        diagnostics = { enabled = true, triggers = { "BufWritePost" } },
        completion = { enabled = true },
      },
      codeRunner = {
        enabled = true,
        default_method = "molten",
      },
    },
    config = function(_, opts)
      require("quarto").setup(opts)
      local runner = require("quarto.runner")

      local function setup_notebook(buf)
        if not vim.api.nvim_buf_get_name(buf):match("%.ipynb$") then
          return
        end
        vim.api.nvim_buf_call(buf, function()
          require("quarto").activate()
        end)
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
        end
        map("<leader>jc", runner.run_cell, "Run cell")
        map("<leader>ja", runner.run_above, "Run cell and all above")
        map("<leader>jA", runner.run_all, "Run all cells")
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("QuartoNotebook", { clear = true }),
        pattern = "markdown",
        callback = function(a)
          setup_notebook(a.buf)
        end,
      })
      -- Plugin lazy-loads on `ft`, so the triggering buffer's FileType event
      -- has already fired; set it up now.
      if vim.bo.filetype == "markdown" then
        setup_notebook(vim.api.nvim_get_current_buf())
      end
    end,
  },
}
