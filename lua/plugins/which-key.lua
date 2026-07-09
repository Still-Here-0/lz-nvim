return {
  -- Single source of truth for the <leader>a "ai" group label.
  -- The claude/copilot specs each suppress their own default label with
  -- `{ "<leader>a", false }`, so this is the only place it's declared.
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "ai", mode = { "n", "v" } },
      { "<leader>ac", group = "claude" },
      { "<leader>ag", group = "github copilot", icon = { icon = "", color = "orange" } },
      { "<leader>cu", group = "User Keymaps" },
      { "<leader>j", group = "jupyter", icon = { icon = "", color = "orange" } },
    },
  },
}
