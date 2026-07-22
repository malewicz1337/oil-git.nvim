local M = {}

local constants = require("oil-git.constants")

local default_config = {
	debounce_ms = constants.DEFAULTS.DEBOUNCE_MS,
	show_file_highlights = true,
	show_directory_highlights = true,
	show_file_symbols = true,
	show_directory_symbols = true,
	show_ignored_files = false,
	show_ignored_directories = false,
	show_branch = false,
	branch_format = " %s",
	symbol_position = "eol",
	can_use_signcolumn = nil,
	ignore_gitsigns_update = false,
	debug = false,
	symbols = {
		file = {
			added = "+",
			modified = "~",
			renamed = "->",
			deleted = "D",
			copied = "C",
			conflict = "!",
			untracked = "?",
			ignored = "o",
		},
		directory = {
			added = "*",
			modified = "*",
			renamed = "*",
			deleted = "*",
			copied = "*",
			conflict = "!",
			untracked = "*",
			ignored = "o",
		},
	},
	highlights = {
		OilGitAdded = { fg = "#a6e3a1" },
		OilGitModified = { fg = "#f9e2af" },
		OilGitModifiedStaged = { fg = "#f9e2af" },
		OilGitModifiedUnstaged = { fg = "#e5c890" },
		OilGitBranch = { fg = "#89b4fa" },
		OilGitRenamed = { fg = "#cba6f7" },
		OilGitUntracked = { fg = "#89b4fa" },
		OilGitIgnored = { fg = "#6c7086" },
		OilGitDeleted = { fg = "#f38ba8" },
		OilGitConflict = { fg = "#fab387" },
		OilGitCopied = { fg = "#cba6f7" },
	},
}

local config = {}

local function apply_legacy_modified_highlights(opts, merged_config)
	local user_highlights = opts.highlights or {}
	local legacy_modified = user_highlights.OilGitModified

	if not legacy_modified then
		return
	end

	if not user_highlights.OilGitModifiedStaged then
		merged_config.highlights.OilGitModifiedStaged =
			vim.deepcopy(legacy_modified)
	end

	if not user_highlights.OilGitModifiedUnstaged then
		merged_config.highlights.OilGitModifiedUnstaged =
			vim.deepcopy(legacy_modified)
	end

	merged_config.highlights.OilGitModified = vim.deepcopy(legacy_modified)
end

local function make_readonly(t)
	if type(t) ~= "table" then
		return t
	end

	local proxy = {}
	local mt = {
		__index = function(_, k)
			return make_readonly(t[k])
		end,
		__newindex = function()
			error("Attempt to modify read-only config", 2)
		end,
		__pairs = function()
			return function(_, k)
				local nk, nv = next(t, k)
				if nv ~= nil then
					return nk, make_readonly(nv)
				end
			end,
				nil,
				nil
		end,
		__len = function()
			return #t
		end,
	}
	return setmetatable(proxy, mt)
end

function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", default_config, opts)
	apply_legacy_modified_highlights(opts, config)
end

function M.get()
	return make_readonly(config)
end

function M.get_raw()
	return config
end

function M.ensure()
	if vim.tbl_isempty(config) then
		config = vim.tbl_deep_extend("force", {}, default_config)
	end
end

return M
