-- lua/plugins/blink.lua
return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "default",
      ["<CR>"] = {}, -- unmap enter to accept autocompleation
    },
  },
}
