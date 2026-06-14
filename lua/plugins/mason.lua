return {
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- LSPs
          "pyright",
          "lua-language-server",
          "json-lsp",
          "marksman",
          "rust-analyzer",
          "taplo",
          -- DAP
          "codelldb",
          "debugpy",
          -- Formatters/linters
          "ruff",
          "stylua",
          "shfmt",
          "markdownlint-cli2",
          "markdown-toc",
        },
      })
    end,
  },
}
