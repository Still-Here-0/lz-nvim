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
    -- Always use markdown for scratch buffers instead of inheriting the
    -- filetype of the current buffer, so one scratch per cwd/branch can hold
    -- both notes and fenced code blocks.
    scratch = {
      ft = "markdown",
      -- Values < 1 are a fraction of the screen (default style is a fixed
      -- width = 100, height = 30).
      win = {
        width = 0.92,
        height = 0.88,
      },
    },
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
