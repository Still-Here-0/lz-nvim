return {
  -- Show hidden (dotfiles) and gitignored files by default. Toggle live with
  -- <a-h>/<a-i> (snacks' default in every picker, explorer included).
  "folke/snacks.nvim",
  opts = {
    -- On WSL, ConPTY breaks terminal image placement; images open in Windows
    -- apps instead (see config/autocmds.lua).
    image = { enabled = vim.fn.has("wsl") == 0 },
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
      actions = {
        open_external = function(picker, item)
          if not item then
            return
          end
          require("util.open_external")(Snacks.picker.util.path(item))
        end,
      },
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          -- Drop the explorer's extra H/I toggles so <a-h>/<a-i> are the only ones.
          win = {
            list = {
              keys = {
                ["H"] = false,
                ["I"] = false,
                ["<leader>fo"] = "open_external",
              },
            },
          },
        },
        files = {
          hidden = true,
          ignored = true,
          -- Descend into symlinked folders (e.g. My_Mind_Mirror -> the vault).
          follow = true,
        },
        grep = {
          ignored = true,
        },
      },
    },
  },
  -- Lowercase keys open on the cwd Neovim was started in, uppercase on the root
  -- dir (the reverse of LazyVim). LazyVim's "root dir" follows the current
  -- buffer's LSP/git root, so it jumps to another project when editing a file
  -- that lives elsewhere (e.g. the Obsidian vault behind a symlink).
  keys = {
    { "<leader>fe", function() Snacks.explorer() end, desc = "Explorer Snacks (cwd)" },
    { "<leader>fE", function() Snacks.explorer({ cwd = LazyVim.root() }) end, desc = "Explorer Snacks (root dir)" },
    { "<leader>e", "<leader>fe", desc = "Explorer Snacks (cwd)", remap = true },
    { "<leader>E", "<leader>fE", desc = "Explorer Snacks (root dir)", remap = true },
    { "<leader><space>", LazyVim.pick("files", { root = false }), desc = "Find Files (cwd)" },
    { "<leader>ff", LazyVim.pick("files", { root = false }), desc = "Find Files (cwd)" },
    { "<leader>fF", LazyVim.pick("files"), desc = "Find Files (root dir)" },
  },
}
