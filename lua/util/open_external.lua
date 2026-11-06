-- Open a path with the host OS default application. On WSL the Linux path is
-- translated with wslpath and handed to explorer.exe, so Windows apps (Excel,
-- browsers, image viewers) are used instead of the ones inside the distro.
return function(path)
  path = path and vim.trim(path) or ""
  if path == "" then
    vim.notify("No file to open", vim.log.levels.WARN)
    return
  end

  path = vim.fn.fnamemodify(path, ":p")

  if vim.fn.has("wsl") == 1 then
    local res = vim.system({ "wslpath", "-w", path }):wait()
    if res.code ~= 0 then
      vim.notify("wslpath failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
      return
    end
    vim.system({ "explorer.exe", vim.trim(res.stdout) }, { detach = true })
  else
    local ok, err = pcall(vim.ui.open, path)
    if not ok then
      vim.notify("Failed to open: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end
