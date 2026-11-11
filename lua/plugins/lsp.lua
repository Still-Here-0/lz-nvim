local INLAY_HINT_DEBOUNCE_MS = 300

local cancel_dirs = {}

local function start_basedpyright(dispatchers, config)
  local folder = ("nvim-%d-%d"):format(vim.uv.os_getpid(), vim.uv.hrtime())
  local rpc = vim.lsp.rpc.start(
    { "basedpyright-langserver", "--stdio", "--cancellationReceive=file:" .. folder },
    dispatchers,
    { cwd = config.cmd_cwd, env = config.cmd_env, detached = config.detached }
  )
  local dir = vim.fs.joinpath(vim.uv.os_tmpdir(), "python-languageserver-cancellation", folder)
  vim.fn.mkdir(dir, "p")
  cancel_dirs[rpc] = dir
  return rpc
end

local function debounce_inlay_hint_requests(client)
  local send = client.request
  local timers = {}
  client.request = function(self, method, params, handler, bufnr)
    if method ~= "textDocument/inlayHint" then
      return send(self, method, params, handler, bufnr)
    end
    local uri = params.textDocument.uri
    local waiting = timers[uri]
    if waiting and not waiting:is_closing() then
      waiting:stop()
      waiting:close()
    end
    timers[uri] = vim.defer_fn(function()
      if not self:is_stopped() then
        send(self, method, params, handler, bufnr)
      end
    end, INLAY_HINT_DEBOUNCE_MS)
    return true
  end
end

local function cancel_older_inlay_hint_requests(client, newest_id, bufnr)
  for id, request in pairs(client.requests) do
    local is_inlay_hint = request.method == "textDocument/inlayHint"
    if id < newest_id and is_inlay_hint and request.type == "pending" and request.bufnr == bufnr then
      client:cancel_request(id)
    end
  end
end

vim.api.nvim_create_autocmd("LspRequest", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local dir = client and cancel_dirs[client.rpc]
    if not dir then
      return
    end
    local request = ev.data.request
    local marker = ("%s/cancellation-%d.tmp"):format(dir, ev.data.request_id)
    if request.type == "cancel" then
      vim.fn.writefile({}, marker)
    elseif request.type == "complete" then
      vim.fn.delete(marker)
    elseif request.method == "textDocument/inlayHint" then
      cancel_older_inlay_hint_requests(client, ev.data.request_id, request.bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    for _, dir in pairs(cancel_dirs) do
      vim.fn.delete(dir, "rf")
    end
  end,
})

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      basedpyright = {
        cmd = start_basedpyright,
        on_init = debounce_inlay_hint_requests,
      },
    },
  },
}
