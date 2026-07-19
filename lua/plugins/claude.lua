return {
  -- Claude Code -> <leader>ac*
    {
        "coder/claudecode.nvim",
        keys = {
            -- Disable claudecode's default <leader>a* keymaps (remapped to <leader>ac* below).
            -- Disabling the default "<leader>ac" toggle is what frees it to be a pure menu
            -- prefix; "<leader>as" exists in both n (tree-add) and v (send) modes.
            { "<leader>a", false, mode = { "n", "v" } },
            { "<leader>ac", false },
            { "<leader>af", false },
            { "<leader>ar", false },
            { "<leader>aC", false },
            { "<leader>ab", false },
            { "<leader>as", false, mode = { "n", "v" } },
            { "<leader>aa", false },
            { "<leader>ad", false },
            { "<leader>acc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
            { "<leader>acf", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
            { "<leader>acr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
            { "<leader>acC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
            { "<leader>acb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
            { "<leader>acs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
            {
                "<leader>acs",
                "<cmd>ClaudeCodeTreeAdd<cr>",
                desc = "Add file",
                ft = { "NvimTree", "neo-tree", "oil", "snacks_picker_list" },
            },
            { "<leader>acy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
            { "<leader>acd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
        },
    },
}
