-- Jupyter-kernel workflow inside Neovim — the closest thing to VS Code's
-- Data Wrangler for *live* DataFrame exploration. Run Python cells against a
-- kernel and see df/plots rendered inline (as images via image.nvim).
--
-- Two separate Pythons are involved (don't confuse them):
--   * HOST  — runs Molten's own plugin code; needs pynvim + jupyter_client.
--             Neovim has ONE host globally (g:python3_host_prog below). It never
--             runs your code, so pinning it does NOT affect your projects. This
--             config auto-provisions it (see build) so a fresh machine works.
--   * KERNEL — runs your cells; should match the project venv. Bootstrap it per
--             project with <leader>jk (installs ipykernel + registers a kernel),
--             then :MoltenInit <name>.

-- The dedicated HOST venv. Config is synced across machines but this venv is
-- not, so it's created on demand by the build hook below.
local host_dir = vim.fn.expand("~/.venvs/neovim")
local host_py = host_dir .. "/bin/python"

-- Create the host venv + install Molten's Python deps if it doesn't exist yet.
-- Synchronous (runs inside lazy's build step, which shows progress). Idempotent:
-- a no-op once the venv is present, so it's cheap to re-run on plugin updates.
local function ensure_host_venv()
  if vim.fn.filereadable(host_py) == 1 then
    return
  end
  local base = vim.fn.exepath("python3")
  if base == "" then
    error("Molten: no python3 on PATH to create the host venv")
  end
  local r = vim.system({ base, "-m", "venv", host_dir }):wait()
  if r.code ~= 0 then
    error("Molten: venv create failed\n" .. (r.stderr or ""))
  end
  r = vim.system({
    host_py, "-m", "pip", "install", "-q", "--upgrade",
    "pip", "pynvim", "jupyter_client", "ipykernel", "nbformat",
    "pandas", "pyarrow", "matplotlib",
  }):wait()
  if r.code ~= 0 then
    error("Molten: host pip install failed\n" .. (r.stderr or ""))
  end
  -- Register the host venv as a general-purpose "molten" scratch kernel
  -- (kernelspecs aren't synced either, so do it here for machine parity).
  vim.system({
    host_py, "-m", "ipykernel", "install", "--user",
    "--name", "molten", "--display-name", "Molten (host venv)",
  }):wait()
end

-- Bootstrap the CURRENT project's interpreter as a Molten kernel.
-- Resolves the project Python (activated venv → ./.venv → PATH `python`, which
-- respects pyenv shims / `pyenv local`), installs ipykernel into it, and
-- registers a Jupyter kernel named after the project directory.
local function setup_project_kernel()
  local cwd = vim.fn.getcwd()
  local py
  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    py = vim.env.VIRTUAL_ENV .. "/bin/python"
  elseif vim.fn.filereadable(cwd .. "/.venv/bin/python") == 1 then
    py = cwd .. "/.venv/bin/python"
  else
    py = vim.fn.exepath("python")
    if py == "" then py = vim.fn.exepath("python3") end
  end
  if not py or py == "" then
    vim.notify("Molten: could not find a project Python", vim.log.levels.ERROR)
    return
  end

  local name = vim.fn.fnamemodify(cwd, ":t")
  vim.notify(("Molten: installing ipykernel into %s …"):format(py), vim.log.levels.INFO)
  vim.system({ py, "-m", "pip", "install", "-q", "ipykernel" }, { text = true }, function(r1)
    if r1.code ~= 0 then
      vim.schedule(function()
        vim.notify("Molten: pip install failed\n" .. (r1.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end
    vim.system({
      py, "-m", "ipykernel", "install", "--user",
      "--name", name, "--display-name", "Molten: " .. name,
    }, { text = true }, function(r2)
      vim.schedule(function()
        if r2.code ~= 0 then
          vim.notify("Molten: kernel register failed\n" .. (r2.stderr or ""), vim.log.levels.ERROR)
        else
          vim.notify(("Molten: kernel '%s' ready → :MoltenInit %s"):format(name, name), vim.log.levels.INFO)
        end
      end)
    end)
  end)
end

return {
  -- Inline image rendering. Ghostty speaks the kitty graphics protocol.
  {
    "3rd/image.nvim",
    -- magick_cli avoids the fiddly luarocks `magick` rock; it shells out to
    -- the ImageMagick CLI instead. Requires ImageMagick installed.
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {}, -- don't auto-render images in markdown; molten drives it
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
    },
  },

  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    -- Runs on install/update: provision the host venv (if missing) BEFORE
    -- registering the remote plugin, so a freshly-cloned config on a second
    -- machine self-heals instead of failing on a missing jupyter_client.
    build = function()
      ensure_host_venv()
      -- Regenerate the manifest in a CLEAN subprocess. Doing it in this session
      -- is unreliable: if the python3 host already started with a bad
      -- interpreter (e.g. init pointed at a not-yet-created venv) it stays
      -- poisoned and UpdateRemotePlugins yields an EMPTY manifest that then
      -- persists (build won't re-run on restart). `-u NORC` loads no user
      -- config (so no lazy recursion) but keeps runtime plugins, and inherits
      -- NVIM_APPNAME so the manifest lands in the right data dir.
      local molten_dir = vim.fn.stdpath("data") .. "/lazy/molten-nvim"
      local r = vim.system({
        vim.v.progpath, "--headless", "-u", "NORC",
        "-c", "set rtp+=" .. molten_dir,
        "-c", "let g:python3_host_prog='" .. host_py .. "'",
        "-c", "UpdateRemotePlugins",
        "-c", "qa",
      }):wait()
      if r.code ~= 0 then
        vim.notify("Molten: manifest regeneration failed\n" .. (r.stderr or ""), vim.log.levels.WARN)
      end
    end,
    ft = { "python", "markdown", "quarto" },
    init = function()
      -- HOST interpreter (see header). Must have pynvim + jupyter_client.
      -- System Python is PEP668-locked and can't get jupyter_client, so this
      -- points at a dedicated venv. This is Molten's plumbing only — your
      -- project code still runs in the KERNEL you pick with <leader>jk.
      vim.g.python3_host_prog = host_py
      -- jupyter_client (8.x) writes kernel-<uuid>.json into the runtime dir but
      -- does NOT create it; a missing dir makes MoltenInit fail with ENOENT.
      -- Ensure it exists (respects XDG_DATA_HOME, falls back to ~/.local/share).
      local data_home = vim.env.XDG_DATA_HOME
      if not data_home or data_home == "" then
        data_home = vim.fn.expand("~/.local/share")
      end
      vim.fn.mkdir(data_home .. "/jupyter/runtime", "p")
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      -- Show short outputs as virtual text next to the cell; open the float for big ones.
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = false
    end,
    keys = {
      { "<leader>ji", "<cmd>MoltenInit<cr>", desc = "Init kernel" },
      { "<leader>jk", setup_project_kernel, desc = "Setup project kernel (pip install ipykernel)" },
      { "<leader>je", "<cmd>MoltenEvaluateOperator<cr>", desc = "Evaluate operator" },
      { "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", desc = "Evaluate line" },
      { "<leader>jr", "<cmd>MoltenReevaluateCell<cr>", desc = "Re-evaluate cell" },
      { "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "Evaluate selection" },
      { "<leader>jo", "<cmd>MoltenShowOutput<cr>", desc = "Show output" },
      { "<leader>jh", "<cmd>MoltenHideOutput<cr>", desc = "Hide output" },
      { "<leader>jd", "<cmd>MoltenDelete<cr>", desc = "Delete cell" },
    },
  },
}
