return {
  -- Single source of truth for the <leader>a "ai" group label.
  -- The claude/copilot specs each suppress their own default label with
  -- `{ "<leader>a", false }`, so this is the only place it's declared.
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "AI", mode = { "n", "v" } },
      { "<leader>ac", group = "Claude" },
      { "<leader>ag", group = "Github copilot", icon = { icon = "", color = "orange" } },
      { "<leader>agQ", group = "Quickfix copilot" },
      { "<leader>cu", group = "User Keymaps" },
      { "<leader>j", group = "Jupyter", icon = { icon = "", color = "orange" } },
    },
  },
}
