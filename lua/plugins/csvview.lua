return {
  -- Aligned, navigable table view for CSV/TSV files. Auto-enables on open;
  -- toggle manually with <leader>cv. No Python deps — pure-Lua flat-file viewer.
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
    opts = {
      parser = { comments = { "#", "//" } },
      view = {
        -- "border" draws column separators; "highlight" just tints columns.
        display_mode = "border",
      },
      keymaps = {
        -- Field (cell) text objects, buffer-local to csv/tsv views. Using iC/aC
        -- (C = Cell) instead of the plugin's default if/af, which LazyVim already
        -- binds to mini.ai's function text objects.
        --   iC → inner field (cell contents), e.g. ciC to change a cell
        --   aC → a field (includes the delimiter), e.g. daC
        textobject_field_inner = { "iC", mode = { "o", "x" } },
        textobject_field_outer = { "aC", mode = { "o", "x" } },
      },
    },
    config = function(_, opts)
      require("csvview").setup(opts)
      -- csvview has no built-in auto-enable, so turn it on for every csv/tsv
      -- buffer via FileType. lazy re-fires FileType after loading the plugin,
      -- so this also catches the buffer that triggered the load.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("CsvViewAutoEnable", { clear = true }),
        pattern = { "csv", "tsv" },
        callback = function(ev)
          require("csvview").enable(ev.buf)
        end,
      })
    end,
    keys = {
      { "<leader>cv", "<cmd>CsvViewToggle<cr>", desc = "Toggle CSV view", ft = { "csv", "tsv" } },
    },
  },
}
