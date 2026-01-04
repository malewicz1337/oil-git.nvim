local M = {}

local uv = vim.uv or vim.loop

M.is_windows = uv.os_uname().version:match("Windows") ~= nil
M.sep = M.is_windows and "\\" or "/"

function M.split(p)
	if not p or p == "" then
		return {}
	end
	return vim.split(p, "[/\\]", { plain = false, trimempty = true })
end

function M.join(...)
	return table.concat({ ... }, M.sep)
end

function M.git_to_os(git_path)
	if M.is_windows then
		return git_path:gsub("/", "\\")
	end
	return git_path
end

function M.remove_trailing_slash(p)
	if p == "" then
		return p
	end
	return (p:gsub("[/\\]+$", ""))
end

return M
