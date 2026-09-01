return {
  -- Enable the official copilot-language-server (installed via Mason, see
  -- plugins/mason.lua) so sidekick's Next Edit Suggestions have something to
  -- talk to. nvim-lspconfig ships a ready-made `lsp/copilot.lua` config.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        copilot = {},
      },
    },
  },

  -- Sidekick -> <leader>as*
  -- Native Copilot integration: Next Edit Suggestions run through the real
  -- `copilot-language-server` (installed via Mason, see plugins/mason.lua),
  -- and the CLI terminal drives the actual `copilot` CLI agent, running as a
  -- real process in an embedded terminal.
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        -- Persist CLI sessions in tmux so a conversation survives closing the
        -- terminal window (and Neovim itself). The real agent owns its own
        -- history, so tmux just keeps the session alive.
        mux = { backend = "tmux", enabled = true },
        tools = {
          -- Copilot CLI is a full-screen (alternate screen) TUI, so tmux keeps
          -- no scrollback for its pane and sidekick's `capture-pane` dump would
          -- only ever show the current viewport. Worse, sidekick's scrollback
          -- hook swallows the mouse wheel to open that dead-end buffer. The CLI
          -- enables mouse reporting itself, so let it own scrolling.
          copilot = { native_scroll = true },
        },
        -- Custom prompts. Sidekick already ships `diagnostics`, `review`,
        -- `fix`, `tests`, etc., so only add ones with no built-in equivalent.
        prompts = {
          pr = "Write a PR title and description for the staged changes (`git diff --staged`).",
          commit = "Write a conventional commit message for the staged changes (`git diff --staged`).",
        },
      },
    },
    keys = {
      {
        "<tab>",
        function()
          -- Jump to the next edit suggestion, or apply it if the cursor is
          -- already there; fall back to a literal <Tab> otherwise.
          -- Normal mode only: insert-mode <Tab> is owned by blink.cmp, which
          -- chains to sidekick itself (see plugins/blink.lua).
          if not require("sidekick").nes_jump_or_apply() then
            return "<Tab>"
          end
        end,
        expr = true,
        mode = { "n" },
        desc = "Goto/Apply Next Edit Suggestion",
      },
      {
        "<leader>ass",
        function() require("sidekick.cli").toggle({ name = "copilot" }) end,
        desc = "Toggle Copilot CLI (Sidekick)",
      },
      {
        "<leader>asS",
        function() require("sidekick.cli").select({ filter = { installed = true } }) end,
        desc = "Select CLI (Sidekick)",
      },
      {
        "<leader>asF",
        function() require("sidekick.cli").focus() end,
        mode = { "n", "x" },
        desc = "Focus CLI (Sidekick)",
      },
      {
        -- Terminal/insert mode deliberately avoids <leader>: a leader-prefixed
        -- terminal mapping makes every <space> you type wait out 'timeoutlen'
        -- before being forwarded to the CLI process.
        "<c-.>",
        function() require("sidekick.cli").focus() end,
        mode = { "t", "i" },
        desc = "Focus CLI (Sidekick)",
      },
      {
        "<leader>asd",
        function() require("sidekick.cli").close() end,
        desc = "Detach CLI Session (Sidekick)",
      },
      {
        "<leader>ast",
        function() require("sidekick.cli").send({ msg = "{this}" }) end,
        mode = { "n", "x" },
        desc = "Send This (Sidekick)",
      },
      {
        "<leader>asf",
        function() require("sidekick.cli").send({ msg = "{file}" }) end,
        desc = "Send File (Sidekick)",
      },
      {
        "<leader>asv",
        function() require("sidekick.cli").send({ msg = "{selection}" }) end,
        mode = { "x" },
        desc = "Send Visual Selection (Sidekick)",
      },
      {
        "<leader>asp",
        function() require("sidekick.cli").prompt() end,
        mode = { "n", "x" },
        desc = "Select Prompt (Sidekick)",
      },
      -- Direct prompt keymaps for the two most common workflows.
      {
        "<leader>asD",
        function() require("sidekick.cli").send({ prompt = "diagnostics", submit = true }) end,
        desc = "Fix Diagnostics (Sidekick)",
      },
      {
        "<leader>asP",
        function() require("sidekick.cli").send({ prompt = "pr", submit = true }) end,
        desc = "PR Title & Description (Sidekick)",
      },
    },
  },
}

