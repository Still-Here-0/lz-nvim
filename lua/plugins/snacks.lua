return {
  -- Show hidden (dotfiles) and gitignored files in the Snacks explorer by
  -- default. Toggle them off/on live inside the explorer with H (hidden) and
  -- I (ignored).
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
        },
      },
    },
  },
}
