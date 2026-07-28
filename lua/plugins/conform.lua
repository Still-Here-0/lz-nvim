return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        prettier = {
          -- Markdown-only line wrapping, kept in nvim config instead of a
          -- global ~/.prettierrc. CLI flags would override project configs
          -- (they're prettier's highest precedence), so skip them when the
          -- project defines its own prettier config.
          prepend_args = function(_, ctx)
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
          end,
        },
      },
    },
  },
}
