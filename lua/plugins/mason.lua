return {
  {
    "mason-org/mason.nvim",
    opts = {
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
    },
  },
}
