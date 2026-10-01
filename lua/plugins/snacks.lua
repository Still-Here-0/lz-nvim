-- <c-h>/<c-i> toggle hidden/ignored in the files and grep pickers (on top of
-- the default <a-h>/<a-i>). Mapping <c-i> also stops it from acting as <Tab>
-- (select); needs a terminal that tells the two apart (e.g. ghostty/kitty).
local toggle_win = {
  input = {
    keys = {
      ["<c-h>"] = { "toggle_hidden", mode = { "i", "n" } },
      ["<c-i>"] = { "toggle_ignored", mode = { "i", "n" } },
    },
  },
  list = {
    keys = {
      ["<c-h>"] = "toggle_hidden",
      ["<c-i>"] = "toggle_ignored",
    },
  },
}

return {
  -- Show hidden (dotfiles) and gitignored files by default. Toggle live with
  -- H/I in the explorer, <c-h>/<c-i> in the files and grep pickers.
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
        },
        files = {
          hidden = true,
          ignored = true,
          win = toggle_win,
        },
        grep = {
          hidden = true,
          ignored = true,
          win = toggle_win,
        },
      },
    },
  },
}
