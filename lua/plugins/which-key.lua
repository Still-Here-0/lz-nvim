return {
  -- Single source of truth for the <leader>a "ai" group label.
  -- The claude/copilot specs each suppress their own default label with
  -- `{ "<leader>a", false }`, so this is the only place it's declared.
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "AI", mode = { "n", "v" } },
      { "<leader>ac", group = "Claude" },
      { "<leader>ag", group = "Github copilot", icon = { icon = "", color = "orange" } },
      { "<leader>agQ", group = "Quickfix copilot" },
      { "<leader>cu", group = "User Keymaps", icon = { icon = "🛠", color = "green" } },
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- Filetype-gated groups must be registered per-buffer, because a
    -- global spec `cond` is only evaluated once at setup time (which
    -- would drop the label + icon permanently). Register them buffer-
    -- locally on FileType instead.
    local groups = {
      {
        fts = { "python", "markdown", "quarto" },
        spec = { "<leader>j", group = "Jupyter", icon = { icon = "📓", color = "orange" } },
      },
      {
        fts = { "markdown", "tex", "quarto" },
        spec = { "<leader>m", group = "Mathjax", icon = { icon = "𝞹", color = "red" } },
      },
    }

    for _, g in ipairs(groups) do
      vim.api.nvim_create_autocmd("FileType", {
        pattern = g.fts,
        callback = function(ev)
          local s = vim.deepcopy(g.spec)
          s.buffer = ev.buf
          wk.add(s)
        end,
      })
    end
  end,
}
