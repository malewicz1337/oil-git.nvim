local M = {}

local config = require("oil-git.config")
local git = require("oil-git.git")
local highlights = require("oil-git.highlights")
local util = require("oil-git.util")

local initialized = false
local user_configured = false

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("OilGitStatus", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "oil://*",
		callback = highlights.apply_immediate,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		pattern = "oil://*",
		callback = function(args)
			highlights.on_buf_delete(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		pattern = "oil://*",
		callback = highlights.apply_debounced,
	})

	vim.api.nvim_create_autocmd({ "FocusGained", "WinEnter", "BufWinEnter" }, {
		group = group,
		pattern = "oil://*",
		callback = highlights.apply_immediate,
	})

	vim.api.nvim_create_autocmd("TermClose", {
		group = group,
		callback = function()
			git.invalidate_cache()
			if vim.bo.filetype == "oil" then
				highlights.apply_immediate()
			end
		end,
	})

	local cfg = config.get()
	local user_patterns = { "FugitiveChanged", "LazyGitClosed" }
	if not cfg.ignore_gitsigns_update then
		table.insert(user_patterns, "GitSignsUpdate")
	else
		util.debug_log("minimal", "GitSignsUpdate events ignored (config)")
	end

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = user_patterns,
		callback = function()
			git.invalidate_cache()
			if vim.bo.filetype == "oil" then
				highlights.apply_immediate()
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function()
			git.invalidate_cache()
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "OilEnter",
		callback = function()
			util.debug_log("verbose", "OilEnter event triggered")
			highlights.apply_immediate()
		end,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		callback = function()
			vim.schedule(function()
				if vim.bo.filetype == "oil" then
					util.debug_log(
						"verbose",
						"VimEnter fallback triggered for oil buffer"
					)
					highlights.apply_immediate()
				end
			end)
		end,
		once = true,
	})
end

function M.init()
	if initialized then
		return
	end

	if not util.is_oil_available() then
		util.debug_log(
			"minimal",
			"oil.nvim not available, deferring initialization"
		)
		return
	end

	config.ensure()
	highlights.setup()
	setup_autocmds()
	initialized = true
	util.debug_log("minimal", "Initialized successfully")
end

function M.setup(opts)
	config.setup(opts)
	user_configured = true
	M.init()
end

function M._is_configured()
	return user_configured
end

function M.refresh()
	if not initialized then
		util.debug_log("minimal", "Cannot refresh: not initialized")
		return
	end
	highlights.apply()
end

return M
