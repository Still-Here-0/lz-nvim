-- jupytext.nvim shells out to a bare `jupytext` command, so the CLI must be on
-- PATH. Config is synced across machines but the CLI is not, so the build hook
-- installs it on demand (uv tool → ~/.local/bin, pipx as a fallback).
-- Idempotent: a no-op once `jupytext` is executable. To re-run it on a machine
-- where the plugin is already installed: :Lazy build jupytext.nvim
local function ensure_jupytext()
  if vim.fn.executable("jupytext") == 1 then
    return
  end
  local cmd
  if vim.fn.executable("uv") == 1 then
    cmd = { "uv", "tool", "install", "jupytext" }
  elseif vim.fn.executable("pipx") == 1 then
    cmd = { "pipx", "install", "jupytext" }
  else
    error("jupytext.nvim: `jupytext` not on PATH and neither uv nor pipx is available to install it")
  end
  local r = vim.system(cmd, { text = true }):wait()
  if r.code ~= 0 then
    error("jupytext.nvim: jupytext install failed\n" .. (r.stderr or ""))
  end
end

return {
  "GCBallesteros/jupytext.nvim",
  build = ensure_jupytext,
  opts = {
    style = "markdown",
    output_extension = "md",
    force_ft = "markdown",
  },
}
