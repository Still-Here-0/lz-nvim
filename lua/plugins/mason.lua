return {
  -- 1. Core Mason
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },

  -- 2. LSP bridge → auto-installs LSP servers
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "jsonls", -- json-lsp
          "lua_ls", -- lua-language-server
          "marksman",
          "pyright",
          "rust_analyzer", -- rust-analyzer
          "taplo",
        },
        automatic_installation = true,
      })
    end,
  },

  -- 3. DAP bridge → auto-installs debuggers
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = {
          "codelldb",
          "python", -- installs debugpy
        },
        automatic_installation = true,
      })
    end,
  },

  -- 4. Tool installer → formatters, linters, and other tools
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          "markdown-toc",
          "markdownlint-cli2",
          "ruff",
          "shfmt",
          "stylua",
        },
        auto_update = false,
        run_on_start = true,
      })
    end,
  },
}
