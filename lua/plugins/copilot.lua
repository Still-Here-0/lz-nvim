return {
  -- Copilot Chat -> <leader>ag*
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    keys = {
      -- Disable CopilotChat's default <leader>a* keymaps (remapped to <leader>ag* below).
      -- These are all mode { "n", "x" }, so the disable must match the mode or the
      -- visual-mode variant survives.
      { "<leader>a", false, mode = { "n", "x" } },
      { "<leader>aa", false, mode = { "n", "x" } },
      { "<leader>ax", false, mode = { "n", "x" } },
      { "<leader>aq", false, mode = { "n", "x" } },
      { "<leader>ap", false, mode = { "n", "x" } },
      {
        "<leader>agg",
        function() require("CopilotChat").toggle() end,
        desc = "Toggle (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agx",
        function() require("CopilotChat").reset() end,
        desc = "Clear (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agq",
        function()
          vim.ui.input({ prompt = "Quick Chat: " }, function(input)
            if input ~= "" then require("CopilotChat").ask(input) end
          end)
        end,
        desc = "Quick Chat (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agp",
        function() require("CopilotChat").select_prompt() end,
        desc = "Prompt Actions (Copilot Chat)",
        mode = { "n", "x" },
      },
    },
  },

  -- Copilot completion engine (moved here from config/autocmds.lua so it
  -- actually takes effect — config files don't accept plugin specs).
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
}
