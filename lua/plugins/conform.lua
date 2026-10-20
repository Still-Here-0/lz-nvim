-- Filetypes Biome can format; for these it takes precedence over prettier when
-- the project has a biome config (require_cwd), otherwise prettier is used.
local biome_fts = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "json",
  "jsonc",
}

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      opts.formatters.biome = vim.tbl_deep_extend("force", opts.formatters.biome or {}, {
        require_cwd = true,
      })

      for _, ft in ipairs(biome_fts) do
        local list = opts.formatters_by_ft[ft] or {}
        if not vim.tbl_contains(list, "biome") then
          table.insert(list, 1, "biome")
        end
        list.stop_after_first = true
        opts.formatters_by_ft[ft] = list
      end

      opts.formatters.prettier = opts.formatters.prettier or {}
      -- Markdown-only line wrapping, kept in nvim config instead of a
      -- global ~/.prettierrc. CLI flags would override project configs
      -- (they're prettier's highest precedence), so skip them when the
      -- project defines its own prettier config.
      opts.formatters.prettier.prepend_args = function(_, ctx)
        if not vim.bo[ctx.buf].filetype:find("^markdown") then
          return {}
        end
        local project_config = vim.fs.find({
          ".prettierrc",
          ".prettierrc.json",
          ".prettierrc.yml",
          ".prettierrc.yaml",
          ".prettierrc.json5",
          ".prettierrc.js",
          ".prettierrc.cjs",
          ".prettierrc.mjs",
          ".prettierrc.toml",
          "prettier.config.js",
          "prettier.config.cjs",
          "prettier.config.mjs",
        }, {
          path = vim.fs.dirname(ctx.filename),
          upward = true,
          stop = vim.uv.os_homedir(),
        })
        if #project_config > 0 then
          return {}
        end
        return { "--print-width", "80", "--prose-wrap", "always" }
      end
    end,
  },
}
