-- lua/plugins/blink.lua
return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "default",
      ["<CR>"] = {}, -- unmap enter to accept autocompleation
      -- The "default" preset maps <Tab> to snippet_forward, which would
      -- shadow sidekick's Next Edit Suggestions in insert mode. Chain them
      -- instead: snippets win, then NES, then a literal <Tab>.
      ["<Tab>"] = {
        "snippet_forward",
        function() return require("sidekick").nes_jump_or_apply() end,
        "fallback",
      },
    },
  },
}
