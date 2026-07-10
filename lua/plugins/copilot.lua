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
        -- editPreviewRule disabled — the model no longer has to print a fenced
        -- diff preview before invoking the `edit` tool. Remove the block-comment
        -- wrapper below to re-enable it.
        --[==[
        "",
        "<editPreviewRule>",
        "Before calling the `edit` tool, you MUST first show the intended change",
        "as a fenced ```diff code block that reads like `git diff` / `diff -U`:",
        "",
        "- Begin with `--- a/<absolute_path>` then `+++ b/<absolute_path>`.",
        "- Include a few unchanged context lines around the edit for orientation.",
        "- Prefix each removed line (current content) with `-`.",
        "- Prefix each added line (proposed content) with `+`.",
        "- Prefix unchanged context lines with a single space.",
        "",
        "Base the `-` side on the CURRENT text, preferring the live buffer over",
        "disk since it may hold unsaved edits. The diff MUST match exactly what",
        "the subsequent `edit` call will apply.",
        "",
        "Only AFTER presenting that diff preview may you invoke the `edit` tool.",
        "Keep the preview and the actual edit identical (same file, same lines,",
        "same resulting content) so the user can review before approving.",
        "",
        "Example of a valid diff preview:",
        "",
        "```diff",
        "--- a/home/user/project/init.lua",
        "+++ b/home/user/project/init.lua",
        " local opts = {",
        "-  number = false,",
        "+  number = true,",
        "+  relativenumber = true,",
        " }",
        "```",
        "</editPreviewRule>",
        ]==]
      }, "\n"),
      -- Custom chat mappings (deep-merged with the plugin defaults).
      mappings = {
        -- Like `gd` (show_diff) but for the `edit` TOOL CALL near the cursor.
        -- The edit tool keeps its unified diff in tool_call.arguments (JSON),
        -- which never becomes a fenced code block, so the built-in `gd` (which
        -- only sees assistant code blocks) can't target it. This resolves the
        -- edit call, applies its diff to a scratch copy of the target file, and
        -- opens the same vimdiff overlay `gd` uses.
        show_tool_diff = {
          normal = "gD",
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
            if choice and choice ~= "" then chat.load(choice) end
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
        local ctx = "?/?"
        if cc_ok and cc.chat then
          local tc, tm = cc.chat.token_count, cc.chat.token_max_count
          if tc and tm then
            ctx = string.format("%d/%d", tc, tm)
          elseif tm then
            ctx = string.format("0/%d", tm)
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
}
