-- render-markdown.nvim is installed by the LazyVim markdown extra
-- (`:LazyExtras` -> lang.markdown). The spec below is an OVERRIDE layered on
-- top of it -- lazy.nvim deep-merges opts/ft across specs, so we only set the
-- pieces we want to change, not the whole plugin config.
--
-- Inline LaTeX rendering (`$...$` / `$$...$$` shown as approximate Unicode
-- text instead of the raw source) is a BUILT-IN feature of render-markdown's
-- `latex` module. It is enabled by default, but only actually renders when it
-- finds the `latex2text` converter on PATH. Without it, nothing appears.
--
-- To make inline math appear on Linux, install the converter (it ships with
-- pylatexenc) so `latex2text` is discoverable:
--
--   pipx install pylatexenc                 -- or: pip install --user pylatexenc
--   -- or, if you keep a dedicated Neovim venv:
--   ~/.venvs/neovim/bin/pip install pylatexenc
--
-- Then make sure that dir is on PATH, or point the module at an absolute path
-- via `converter = vim.fn.expand("~/.venvs/neovim/bin/latex2text")`.
--
-- Note: this is TEXT-based (latex2text), not image-based. For richer 2D math
-- art, nabla.nvim provides an on-demand popup (<leader>mp).
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    -- Also render the Copilot Chat buffer so Markdown tables/headings/code
    -- blocks display as rendered UI instead of raw `|`/`---` text. lazy.nvim
    -- merges `ft` lists across specs, so this just appends the filetype.
    ft = { "copilot-chat" },
    opts = {
      latex = {
        -- Set to true to enable inline LaTeX -> Unicode text (requires
        -- latex2text on PATH -- see the install notes above).
        enabled = false,
        -- Uncomment to force a specific converter binary regardless of PATH:
        -- converter = vim.fn.expand("~/.venvs/neovim/bin/latex2text"),
      },
      -- render-markdown manages conceallevel/concealcursor on markdown windows.
      -- By default it sets `concealcursor.rendered = ''`, which UN-conceals the
      -- cursor line — that fought nabla's inline math (raw `$...$` reappeared
      -- whenever the cursor sat on a formula). Force 'nc' so the cursor line
      -- (normal + command mode) stays concealed too, letting nabla's 2D art
      -- show cleanly.
      win_options = {
        concealcursor = { rendered = "nc" },
      },
    },
  },
}
