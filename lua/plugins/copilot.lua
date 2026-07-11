return {
  -- Copilot Chat -> <leader>ag*
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      model = "claude-opus-4.8", -- Default model; override per-prompt with $model
      auto_insert_mode = false, -- Stay in normal mode; don't auto-enter insert after answers
      -- Tools the LLM may call by default (all read-only tools + bash).
      tools = { "bash", "buffer", "file", "glob", "grep", "gitdiff", "selection", "clipboard", "url", "edit" },
      -- Auto-run without asking: read-only tools are safe. bash/edit stay manual.
      trusted_tools = { "buffer", "file", "glob", "grep", "gitdiff", "selection", "clipboard" },
      resources = { },
      -- Auto-attach the active buffer to every new chat (same as typing
      -- `> #buffer:active` manually). Accepts a string or list of strings.
      sticky = { "#buffer:active" },
      -- Custom named prompts (in addition to the shipped Explain/Review/Fix/
      -- Optimize/Docs/Tests/Commit). Each `mapping` registers a global n/v keymap.
      prompts = {
        -- Fix the buffer's LSP diagnostics. The `buffer` scope carries diagnostics.
        FixDiagnostics = {
          prompt = "Fix the LSP diagnostics in this buffer. Explain each fix briefly.",
          tools = { "buffer" },
          mapping = "<leader>agD",
          description = "Fix Diagnostics (Copilot Chat)",
        },
        -- Draft a PR title + description from the staged changes (read-only).
        PR = {
          prompt = "Write a PR title and description for the staged changes.",
          tools = { "gitdiff" },
          mapping = "<leader>agP",
          description = "PR Title & Description (Copilot Chat)",
        },
      },
      -- Extend the default system prompt with tool-selection rules so the model
      -- prefers dedicated, trusted (read-only) tools over the general-purpose
      -- bash tool. The plugin auto-appends its own COPILOT_BASE + tool_use
      -- instructions after this string, so this only adds guidance.
      system_prompt = table.concat({
        "You are a code-focused AI programming assistant that specializes in practical software engineering solutions.",
        "",
        "<toolSelectionRules>",
        "Prefer the most specific tool for the job. Use bash ONLY when no dedicated tool can accomplish the task.",
        "",
        "- Read the contents/diagnostics of a file open in a buffer -> use `buffer`",
        "  (NOT `file`/`bash cat`). Prefer `buffer` over `file`: a loaded buffer may",
        "  contain unsaved edits not yet written to disk, so it reflects the true",
        "  current state the user sees.",
        "- Read a file that is NOT open in any buffer -> use `file` (NOT `bash cat`).",
        "- List files by name/pattern -> use `glob` (NOT `bash ls`/`find`).",
        "- Search file contents -> use `grep` (NOT `bash grep`/`rg`).",
        "- Inspect git changes -> use `gitdiff` (NOT `bash git diff`).",
        "- Read the visual selection or clipboard -> use `selection` / `clipboard`.",
        "- Modify a file -> use `edit`.",
        "",
        "Only fall back to bash for tasks the dedicated tools cannot do (running",
        "programs, package managers, builds, multi-step shell pipelines, system",
        "info). If a trusted read-only tool can answer the question, use it first.",
        "</toolSelectionRules>",
        "",
        "<editReliabilityRules>",
        "The `edit` tool requires the diff to match the file's CURRENT bytes",
        "exactly. To avoid failed/partial edits, follow these rules:",
        "",
        "- Before every `edit`, re-read the exact target lines from the LIVE",
        "  file (prefer `buffer`; else `file`/`grep`). Never reconstruct context",
        "  from memory or from an earlier read — prior edits shift line numbers",
        "  and content.",
        "- Always include a proper `@@ ... @@` hunk header. Do not start a hunk",
        "  with bare context lines.",
        "- Copy context lines VERBATIM: exact indentation (spaces vs tabs),",
        "  trailing whitespace, quotes, and punctuation must match byte-for-byte.",
        "- Beware non-ASCII/multibyte content (icons, nerd-font glyphs, emoji,",
        "  boxdrawing, non-breaking spaces). Do NOT retype such lines from a",
        "  rendered view — they corrupt easily. Anchor the hunk on a nearby",
        "  PURE-ASCII line instead, or if none exists, avoid `edit` and use a",
        "  line-addressed shell command via bash (e.g. `sed -i 'Na\\...'`) that",
        "  needs no context match.",
        "- Anchor each hunk on a unique, unchanged nearby line; keep context",
        "  minimal (1-3 lines) so the match stays unambiguous.",
        "- Make one focused change per hunk. For multiple edits in a file,",
        "  re-verify positions between edits since earlier hunks move later ones.",
        "- After an edit fails, do NOT blindly retry: re-read the file, confirm",
        "  the exact current text, then rebuild the diff from that.",
        "- Preserve the file's existing style (indent width, quote style, commas,",
        "  semicolons) so edits don't introduce diagnostics.",
        "</editReliabilityRules>",
        "",
        "<editAlternativesRules>",
        "The `edit` tool shows the user a preview they can accept or deny. Any",
        "OTHER way of modifying a file (bash: `sed -i`, `tee`, `>`/`>>` redirects,",
        "`awk`, `patch`, `python`, etc.) BYPASSES that preview — the user cannot",
        "review the change before it lands. This is only acceptable as a fallback",
        "when `edit` genuinely cannot do the job (e.g. multibyte-glyph context).",
        "",
        "Whenever you decide to modify a file WITHOUT the `edit` tool, you MUST",
        "FIRST print a fenced ```diff block showing exactly what you intend to",
        "change, so the user can review it:",
        "",
        "- Begin with `--- a/<absolute_path>` then `+++ b/<absolute_path>`.",
        "- Include a proper `@@ ... @@` header and a few unchanged context lines.",
        "- Prefix removed lines with `-`, added lines with `+`, context with a space.",
        "- The diff MUST match what the subsequent command will actually do.",
        "",
        "Only AFTER presenting that diff preview may you run the bash command that",
        "performs the edit. Prefer `edit` whenever possible; reach for these",
        "alternatives only when necessary.",
        "",
        "Example of a valid diff preview before a bash edit:",
        "",
        "```diff",
        "--- a/home/user/project/init.lua",
        "+++ b/home/user/project/init.lua",
        "@@ -1,3 +1,3 @@",
        " local opts = {",
        "-  number = false,",
        "+  number = true,",
        " }",
        "```",
        "</editAlternativesRules>",
      }, "\n"),
      -- Custom chat mappings (deep-merged with the plugin defaults).
      mappings = {
        -- Move every built-in chat mapping into the <leader>ag* group.
        -- Disable the built-in <C-l> reset (both modes). Reset lives on <leader>agx.
        reset = { normal = "", insert = "" },
        -- Preserve the original way to send messages: <CR> (normal) and <C-s> (insert).
        submit_prompt = { normal = "<CR>", insert = "<C-s>" },
        accept_diff = { normal = "<leader>aga", insert = "" },
        complete = { insert = "<Tab>" },
        show_info = { normal = "<leader>agi" },
        show_diff = { normal = "<leader>agf" },
        show_help = { normal = "<leader>agh" },
        jump_to_diff = { normal = "<leader>agj" },
        quickfix_answers = { normal = "<leader>agQa" },
        quickfix_diffs = { normal = "<leader>agQd" },
        yank_diff = { normal = "<leader>agy" },
        -- Like `gd` (show_diff) but for the `edit` TOOL CALL near the cursor.
        -- The edit tool keeps its unified diff in tool_call.arguments (JSON),
        -- which never becomes a fenced code block, so the built-in `gd` (which
        -- only sees assistant code blocks) can't target it. This resolves the
        -- edit call, applies its diff to a scratch copy of the target file, and
        -- opens the same vimdiff overlay `gd` uses.
        show_tool_diff = {
          normal = "<leader>agc",
          callback = function(source)
            local chat = require("CopilotChat").chat
            local diff = require("CopilotChat.utils.diff")
            local files = require("CopilotChat.utils.files")
            local utils = require("CopilotChat.utils")

            if not source or not source.winnr or not vim.api.nvim_win_is_valid(source.winnr) then
              vim.notify("No source window for diff", vim.log.levels.WARN)
              return
            end

            -- Assistant message near the cursor + its edit tool calls.
            local message = chat:get_message("assistant", true)
            if not message or not message.tool_calls then
              vim.notify("No tool call under cursor", vim.log.levels.INFO)
              return
            end

            -- Collect edit diffs targeting the first edited file.
            local target, diffs = nil, {}
            for _, tc in ipairs(message.tool_calls) do
              if tc.name == "edit" and tc.arguments then
                local args = utils.json_decode(tc.arguments)
                if args and args.filename and args.diff then
                  target = target or args.filename
                  if files.filename_same(args.filename, target) then
                    table.insert(diffs, args.diff)
                  end
                end
              end
            end
            if not target or #diffs == 0 then
              vim.notify("No edit tool call under cursor", vim.log.levels.INFO)
              return
            end

            -- Find or load the target file buffer, show it in the source window.
            local bufnr
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if files.filename_same(vim.api.nvim_buf_get_name(buf), target) then
                bufnr = buf
                break
              end
            end
            if not bufnr then
              bufnr = vim.fn.bufadd(target)
              vim.fn.bufload(bufnr)
            end
            source.bufnr = bufnr
            vim.api.nvim_win_set_buf(source.winnr, bufnr)

            -- Apply the edit diff(s) to a copy of the current file content.
            local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
            for _, d in ipairs(diffs) do
              content = table.concat(diff.apply_unified_diff(d, content), "\n")
            end

            chat:overlay({
              filetype = vim.bo[bufnr].filetype,
              text = content,
              on_show = function()
                vim.api.nvim_win_call(source.winnr, function() vim.cmd("diffthis") end)
                vim.api.nvim_win_call(chat.winnr, function() vim.cmd("diffthis") end)
              end,
              on_hide = function()
              vim.api.nvim_win_call(chat.winnr, function() vim.cmd("diffoff") end)
              end,
            })
          end,
        },
        -- Tool-call previews (the accept/deny prompt) are rendered as virtual
        -- lines (extmark `virt_lines`), which Neovim NEVER wraps — long bash
        -- commands / edit JSON are truncated at the window's right edge with no
        -- way to scroll. This resolves the tool call(s) under the cursor and
        -- shows their full name + arguments in a scrollable floating window.
        show_tool_call = {
          normal = "<leader>agt",
          callback = function()
            local chat = require("CopilotChat").chat
            local utils = require("CopilotChat.utils")

            local message = chat:get_message("assistant", true)
            if not message or not message.tool_calls or #message.tool_calls == 0 then
              vim.notify("No tool call under cursor", vim.log.levels.INFO)
              return
            end

            local lines = {}
            for _, tc in ipairs(message.tool_calls) do
              table.insert(lines, string.format("# %s (%s)", tc.name, tostring(tc.id)))
              local args = utils.json_decode(tc.arguments)
              if type(args) == "table" then
                for k, v in pairs(args) do
                  local val = type(v) == "string" and v or vim.inspect(v)
                  for _, vl in ipairs(vim.split(val, "\n", { plain = true })) do
                    table.insert(lines, string.format("%s: %s", k, vl))
                  end
                end
              else
                for _, vl in ipairs(vim.split(tostring(tc.arguments or ""), "\n", { plain = true })) do
                  table.insert(lines, vl)
                end
              end
              table.insert(lines, "")
            end

            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modifiable = false
            vim.bo[buf].filetype = "markdown"

            local width = math.floor(vim.o.columns * 0.7)
            local height = math.min(#lines + 1, math.floor(vim.o.lines * 0.7))
            local win = vim.api.nvim_open_win(buf, true, {
              relative = "editor",
              width = width,
              height = height,
              row = math.floor((vim.o.lines - height) / 2),
              col = math.floor((vim.o.columns - width) / 2),
              style = "minimal",
              border = "rounded",
              title = " Tool Call ",
            })
            vim.wo[win].wrap = true
            vim.wo[win].linebreak = false
            vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
            vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
          end,
        },
      },
    },
    keys = {
      -- Disable CopilotChat's default <leader>a* keymaps (remapped to <leader>ag* below).
      -- These are all mode { "n", "x" }, so the disable must match the mode or the
      -- visual-mode variant survives.
      { "<leader>a", false, mode = { "n", "x" } },
      { "<leader>aa", false, mode = { "n", "x" } },
      { "<leader>ax", false, mode = { "n", "x" } },
      { "<leader>aq", false, mode = { "n", "x" } },
      { "<leader>ap", false, mode = { "n", "x" } },
      {
        "<leader>agg",
        function() require("CopilotChat").toggle() end,
        desc = "Toggle (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agx",
        function() require("CopilotChat").reset() end,
        desc = "Clear (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agq",
        function()
          vim.ui.input({ prompt = "Quick Chat: " }, function(input)
            if input ~= "" then require("CopilotChat").ask(input) end
          end)
        end,
        desc = "Quick Chat (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agp",
        function() require("CopilotChat").select_prompt() end,
        desc = "Prompt Actions (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agm",
        function() require("CopilotChat").select_model() end,
        desc = "Select Model (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>ags",
        function()
          vim.ui.input({ prompt = "Save chat as: " }, function(input)
            if input and input ~= "" then require("CopilotChat").save(input) end
          end)
        end,
        desc = "Save Chat (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agl",
        function()
          local chat = require("CopilotChat")
          local names = vim.tbl_map(function(f)
            return vim.fn.fnamemodify(f, ":t:r")
          end, vim.fn.glob(chat.config.history_path .. "/*", true, true))
          if not vim.tbl_contains(names, "default") then
            table.insert(names, 1, "default")
          end
          vim.ui.select(names, { prompt = "Load chat: " }, function(choice)
            if choice and choice ~= "" then
              -- The plugin's load() calls finish(true) after clearing the
              -- buffer, which re-injects config.sticky (`#buffer:active`) as a
              -- fresh user block. The saved history already carries its own
              -- sticky line, so this produced a duplicate `> #buffer:active`
              -- on top of the loaded chat. Temporarily blank out sticky while
              -- loading, then restore it so new prompts still get it.
              local saved_sticky = chat.config.sticky
              chat.config.sticky = nil
              local ok = pcall(chat.load, choice)
              chat.config.sticky = saved_sticky
              if not ok then
                vim.notify("Failed to load chat: " .. choice, vim.log.levels.ERROR)
              end
            end
          end)
        end,
        desc = "Load Chat (Copilot Chat)",
        mode = { "n", "x" },
      },
      {
        "<leader>agd",
        function()
          local chat = require("CopilotChat")
          local files = vim.fn.glob(chat.config.history_path .. "/*", true, true)
          local names = vim.tbl_map(function(f)
            return vim.fn.fnamemodify(f, ":t:r")
          end, files)
          vim.ui.select(names, { prompt = "Delete chat: " }, function(choice)
            if not choice or choice == "" then return end
            local path = chat.config.history_path .. "/" .. choice .. ".json"
            local ok = os.remove(path)
            vim.notify(
              ok and ("Deleted chat: " .. choice) or ("Failed to delete: " .. choice),
              ok and vim.log.levels.INFO or vim.log.levels.ERROR
            )
          end)
        end,
        desc = "Delete Chat (Copilot Chat)",
        mode = { "n", "x" },
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimLeavePre", {
        desc = "Autosave Copilot Chat on exit (global + per-project)",
        callback = function()
          if package.loaded["CopilotChat"] then
            local chat = require("CopilotChat")
            -- Skip autosave unless the conversation has real content.
            -- reset() leaves a single blank user message, so a count/empty
            -- check isn't enough — inspect message contents instead.
            local ok, messages = pcall(function() return chat.chat:get_messages() end)
            local has_content = false
            if ok and messages then
              for _, message in ipairs(messages) do
                if message.content and vim.trim(message.content) ~= "" then
                  has_content = true
                  break
                end
              end
            end
            if not has_content then
              return
            end
            -- Global autosave (any project)
            pcall(chat.save, "last_conversation")
            -- Per-project autosave -> <history_path>/last_conversation:<project>.json
            local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            if project ~= "" then
              pcall(chat.save, "last_conversation:" .. project)
            end
          end
        end,
      })

      -- Auto-fold only tool output sections (role == "tool") so they don't
      -- clutter the actual conversation. Debounced after the buffer changes.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "copilot-chat",
        desc = "Auto-fold Copilot Chat tool output sections",
        callback = function(args)
          local timer
          vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
            buffer = args.buf,
            callback = function()
              if timer then timer:stop() end
              timer = vim.defer_fn(function()
                local ok, cc = pcall(require, "CopilotChat")
                if not ok or not cc.chat then return end
                local win = vim.fn.bufwinid(args.buf)
                if win == -1 then return end
                local mok, messages = pcall(function() return cc.chat:get_messages() end)
                if not mok or not messages then return end
                vim.api.nvim_win_call(win, function()
                  -- Remember whether the view is tailing the end of the buffer
                  -- (cursor on/near the last line) BEFORE we close any folds.
                  local total = vim.api.nvim_buf_line_count(args.buf)
                  local tailing = vim.api.nvim_win_get_cursor(win)[1] >= total - 1
                  for i, m in ipairs(messages) do
                    -- Only fold tool sections that are NOT the last message.
                    -- Folding the last section makes its fold extend to EOF, so
                    -- newly streamed sections (permission prompt, final answer)
                    -- inherit the closed state and cascade. Skipping the last
                    -- message avoids that entirely.
                    if m.role == "tool" and m.section and m.section.start_line and i < #messages then
                      local l = m.section.start_line
                      if vim.fn.foldlevel(l) > 0 and vim.fn.foldclosed(l) == -1 then
                        pcall(vim.api.nvim_cmd, { cmd = "foldclose", range = { l } }, {})
                      end
                    end
                  end
                  -- Closing a large fold above shrinks the rendered height, which
                  -- would leave the newest answer floating upward with blank space
                  -- below. If we were tailing, re-pin EOF to the window bottom.
                  if tailing then
                    vim.cmd("normal! Gzb")
                  end
                end)
              end, 100)
            end,
          })
        end,
      })

      -- Winbar for the chat window showing 4 live stats:
      --   1) current model   2) context tokens (count/max)
      --   3) monthly premium usage %   4) quota reset date
      -- Model + token counts are read live from the CopilotChat module; the
      -- monthly quota comes from client:info() (async + cached), refreshed on
      -- a timer into globals the winbar expression reads.
      _G.CopilotChatQuotaPct = _G.CopilotChatQuotaPct or nil
      _G.CopilotChatQuotaReset = _G.CopilotChatQuotaReset or nil

      local function refresh_quota()
        local ok, client = pcall(require, "CopilotChat.client")
        if not ok then return end
        local aok, async = pcall(require, "plenary.async")
        if not aok then return end
        ---@diagnostic disable-next-line: missing-parameter
        async.run(function()
          local iok, infos = pcall(function() return client:info() end)
          if not iok or not infos then return end
          for _, lines in pairs(infos) do
            for _, l in ipairs(lines) do
              local p = l:match("Usage:.-%((%d+%.?%d*)%%%)")
              if p then _G.CopilotChatQuotaPct = p end
              local d = l:match("resets on:%s*([%d%-]+)")
              if d then _G.CopilotChatQuotaReset = d end
            end
          end
          vim.schedule(function()
            pcall(function() vim.cmd("redrawstatus!") end)
          end)
        end)
      end

      -- Winbar expression function (single %{...} form preserves the literal %).
      function _G.CopilotChatWinbar()
        local cc_ok, cc = pcall(require, "CopilotChat")
        local model = (cc_ok and cc.config and cc.config.model) or "?"
        local ctx = "?"
        if cc_ok and cc.chat then
          local tc, tm = cc.chat.token_count, cc.chat.token_max_count
          if tc and tm then
            local pct = tm > 0 and math.floor((tc / tm) * 100 + 0.5) or 0
            ctx = string.format("%d%%", pct)
          elseif tm then
            ctx = "0%"
          end
        end
        local month = _G.CopilotChatQuotaPct and (_G.CopilotChatQuotaPct .. "%") or "…"
        local reset = _G.CopilotChatQuotaReset or "…"
        -- Append "(N days)" until the quota resets, computed from today.
        local reset_date = _G.CopilotChatQuotaReset
        if type(reset_date) == "string" then
          local y, mo, d = reset_date:match("^(%d+)-(%d+)-(%d+)")
          if y then
            local reset_time = os.time({
              year = tonumber(y) --[[@as integer]],
              month = tonumber(mo) --[[@as integer]],
              day = tonumber(d) --[[@as integer]],
              hour = 0, min = 0, sec = 0,
            })
            local n = os.date("*t")
            local today = os.time({
              year = n.year, month = n.month, day = n.day,
              hour = 0, min = 0, sec = 0,
            })
            local days = math.floor((reset_time - today) / 86400)
            reset = string.format("%s (%d days)", reset_date, days)
          end
        end
        return string.format(
          "  Model: %s │ Context: %s │ Monthly: %s │ Reset: %s",
          model, ctx, month, reset
        )
      end

      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufEnter" }, {
        desc = "Copilot Chat winbar: model, context tokens, monthly usage, reset",
        callback = function(args)
          if vim.bo[args.buf].filetype ~= "copilot-chat" then
            return
          end
          local win = vim.fn.bufwinid(args.buf)
          if win == -1 then
            return
          end
          vim.wo[win].winbar = "%{v:lua.CopilotChatWinbar()}"
          -- Force wrapping so long tool commands (bash) and edit-tool JSON
          -- arguments don't run off-screen. `linebreak = false` lets very long
          -- unbroken tokens (paths, flags, `--...`) wrap at the window edge
          -- instead of overflowing horizontally.
          vim.wo[win].wrap = true
          vim.wo[win].linebreak = false
          refresh_quota()
        end,
      })

      -- Keep context tokens fresh as the chat streams/changes.
      vim.api.nvim_create_autocmd("User", {
        pattern = "CopilotChatUpdate",
        callback = function()
          pcall(function() vim.cmd("redrawstatus!") end)
        end,
      })

      -- Refresh monthly quota now and every 5 minutes.
      local qtimer = vim.uv.new_timer()
      if qtimer then
        qtimer:start(1000, 5 * 60 * 1000, vim.schedule_wrap(refresh_quota))
      end
    end,
  },

  -- Copilot completion engine (moved here from config/autocmds.lua so it
  -- actually takes effect — config files don't accept plugin specs).
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },

  -- Make render-markdown.nvim (LazyVim markdown extra) also render the
  -- Copilot Chat buffer, so Markdown tables/headings/code blocks display as
  -- rendered UI instead of raw `|`/`---` text. lazy.nvim merges `ft` lists
  -- across specs, so this just appends the filetype to the existing config.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ft = { "copilot-chat" },
  },
}
