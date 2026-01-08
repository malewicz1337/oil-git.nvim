local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

function M.check()
	start("oil-git.nvim")

	if vim.fn.has("nvim-0.8") == 1 then
		ok("Neovim >= 0.8")
	else
		error("Neovim >= 0.8 required")
	end

	local oil_ok = pcall(require, "oil")
	if oil_ok then
		ok("oil.nvim is installed")
	else
		error("oil.nvim is not installed (required dependency)")
	end

	if vim.fn.executable("git") == 1 then
		local popen_ok, handle = pcall(io.popen, "git --version 2>&1")
		if popen_ok and handle then
			local result = handle:read("*a")
			handle:close()
			if result and result ~= "" then
				ok("git: " .. vim.trim(result))
			else
				ok("git is available")
			end
		else
			ok("git is available (version check failed)")
		end
	else
		error("git is not installed or not in PATH")
	end

	local config = require("oil-git.config")
	local cfg = config.get()
	if not vim.tbl_isempty(cfg) then
		ok("Configuration loaded")
		if cfg.debug then
			ok("Debug mode: " .. tostring(cfg.debug))
		end
		ok("Symbol position: " .. cfg.symbol_position)
	else
		warn("Using default configuration (setup() not called yet)")
	end

	local oil_git = require("oil-git")
	if oil_git._is_initialized() then
		ok("Plugin initialized successfully")
	else
		if oil_git._is_configured() then
			warn("Plugin configured but not initialized (waiting for oil.nvim)")
		else
			warn(
				"Plugin not yet initialized (will initialize when oil buffer opens)"
			)
		end
	end
end

return M
