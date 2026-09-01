return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSPs
        "pyright",
        "lua-language-server",
        "copilot-language-server",
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
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)

      mr.refresh(function()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          -- guard against re-triggering an install that's already running
          if not p:is_installed() and not p:is_installing() then
            p:install()
          end
        end
      end)
    end,
  },
}
