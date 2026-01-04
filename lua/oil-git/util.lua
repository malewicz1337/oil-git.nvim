local M = {}

local config = require("oil-git.config")

function M.debug_log(level, msg, ...)
	local cfg = config.get()
	if not cfg.debug then
		return
	end
	if cfg.debug == "minimal" and level == "verbose" then
		return
	end

	local formatted
	local format_ok, result = pcall(string.format, msg, ...)
	if format_ok then
		formatted = result
	else
		formatted = msg -- Fallback to raw message
	end

	vim.schedule(function()
		vim.notify("[oil-git] " .. formatted, vim.log.levels.DEBUG)
	end)
end

function M.is_oil_available()
	local ok = pcall(require, "oil")
	return ok
end

return M
