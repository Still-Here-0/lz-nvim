I think this file has too much on it, can you suggest a better way to organize the contencts of this file? Like turning it into a folder and organzing it into opts, mappings, keys, functions of init etc.
#   Copilot  (2e711b36-de40-4013-a9c7-9fde8aaa6105) ───

Here's a proposed reorganization. The file is ~465 lines mixing plugin spec, a large `system_prompt`, a complex `mappings` callback, many `keys`, and a big `init` with autocmds + winbar logic. Splitting by concern makes each piece independently readable and testable.

## Proposed structure

```
lua/plugins/copilot/
├── init.lua                     -- plugin specs; wires the pieces together
├── system_prompt.lua            -- the big table.concat prompt string
├── prompts.lua                  -- custom named prompts (FixDiagnostics, PR)
├── mappings.lua                 -- chat mappings (show_tool_diff / gD)
├── keys.lua                     -- lazy.nvim `keys` table (<leader>ag*)
└── init/                        -- everything currently in `init = function()`
    ├── autosave.lua             -- VimLeavePre autosave autocmd
    ├── autofold.lua             -- copilot-chat tool-output auto-fold
    └── winbar.lua               -- winbar + quota refresh + timers
```

lazy.nvim automatically imports `lua/plugins/copilot/init.lua` when you reference the folder, so no loader changes are needed — you just replace `copilot.lua` with the `copilot/` directory.


## How the pieces connect

`init.lua` becomes a thin assembly file:

```lua path=/home/b9vx86/.config/nvim-lazy/lua/plugins/copilot/init.lua start_line=1 end_line=40
-- Copilot plugin configuration (CopilotChat + copilot.lua).
-- Split into focused modules under this folder; see each require() below.
return {
  -- Copilot Chat -> <leader>ag*
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      model = "claude-opus-4.8",
      auto_insert_mode = false,
      tools = { "bash", "buffer", "file", "glob", "grep", "gitdiff", "selection", "clipboard", "url", "edit" },
      trusted_tools = { "buffer", "file", "glob", "grep", "gitdiff", "selection", "clipboard" },
      resources = {},
      prompts = require("plugins.copilot.prompts"),
      system_prompt = require("plugins.copilot.system_prompt"),
      mappings = require("plugins.copilot.mappings"),
    },
    keys = require("plugins.copilot.keys"),
    init = function()
      require("plugins.copilot.init.autosave")()
      require("plugins.copilot.init.autofold")()
      require("plugins.copilot.init.winbar")()
    end,
  },

  -- Copilot completion engine.
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
}
```

Each `init/*.lua` returns a single setup function so `init` just calls them in order:

```lua path=/home/b9vx86/.config/nvim-lazy/lua/plugins/copilot/init/autosave.lua start_line=1 end_line=8
-- Autosave Copilot Chat on exit (global + per-project).
return function()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    -- ... existing autosave body ...
  })
end
```

```lua path=/home/b9vx86/.config/nvim-lazy/lua/plugins/copilot/system_prompt.lua start_line=1 end_line=6
-- Extends the default system prompt with tool-selection rules.
return table.concat({
  "You are a code-focused AI programming assistant...",
  -- ... rest of the lines, plus the disabled editPreviewRule block ...
}, "\n")
```


## Notes / trade-offs

- **Naming collision:** a subfolder literally named `init/` next to `init.lua` is legal but can read oddly. Consider `setup/` (e.g. `plugins.copilot.setup.winbar`) instead — clearer that these run inside the `init` hook.
- **Globals:** `winbar.lua` defines `_G.CopilotChatWinbar`, `_G.CopilotChatQuotaPct`, etc. Those stay global, so no behavior change — just move the whole block verbatim into the returned function.
- **`keys.lua`** returns the list table directly (`return { {...}, {...} }`); some `require("CopilotChat")` calls inside `function()` bodies are lazy, so moving them is safe.
- **Path style:** your requires use dotted module paths (`plugins.copilot.keys`) relative to `lua/`. Keep that consistent with how the rest of your config requires modules.

Want me to actually perform the split — create the folder, move each section into its module, and delete the old `copilot.lua`? I can do it step by step so each file's content matches the current buffer exactly.
