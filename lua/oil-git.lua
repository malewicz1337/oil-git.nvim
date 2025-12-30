local M = {}

local pending_timer = nil
local debounce_ms = 50

local default_highlights = {
	OilGitAdded = { fg = "#a6e3a1" },
	OilGitModified = { fg = "#f9e2af" },
	OilGitRenamed = { fg = "#cba6f7" },
	OilGitUntracked = { fg = "#89b4fa" },
	OilGitIgnored = { fg = "#6c7086" },
	OilGitDeleted = { fg = "#f38ba8" },
	OilGitConflict = { fg = "#fab387" },
}

local function setup_highlights()
	for name, opts in pairs(default_highlights) do
		if vim.fn.hlexists(name) == 0 then
			vim.api.nvim_set_hl(0, name, opts)
		end
	end
end

local function get_git_root(path)
	local git_dir = vim.fn.finddir(".git", path .. ";")
	if git_dir == "" then
		return nil
	end
	return vim.fn.fnamemodify(git_dir, ":p:h:h")
end

local function parse_git_output(output, git_root)
	local status = {}
	for line in output:gmatch("[^\r\n]+") do
		if #line >= 3 then
			local status_code = line:sub(1, 2)
			local filepath = line:sub(4)

			if status_code:sub(1, 1) == "R" or status_code:sub(1, 1) == "C" then
				local arrow_pos = filepath:find(" %-> ")
				if arrow_pos then
					filepath = filepath:sub(arrow_pos + 4)
				end
			end

			if filepath:sub(1, 2) == "./" then
				filepath = filepath:sub(3)
			end

			local abs_path = git_root .. "/" .. filepath

			status[abs_path] = status_code
		end
	end
	return status
end

local function get_git_status_async(dir, callback)
	local git_root = get_git_root(dir)
	if not git_root then
		callback({})
		return
	end

	local stdout = vim.loop.new_pipe(false)
	local output = ""

	local handle
	handle = vim.loop.spawn("git", {
		args = { "status", "--porcelain", "--ignored" },
		cwd = git_root,
		stdio = { nil, stdout, nil },
	}, function(code)
		stdout:read_stop()
		stdout:close()
		handle:close()

		if code ~= 0 then
			vim.schedule(function()
				callback({})
			end)
			return
		end

		local status = parse_git_output(output, git_root)
		vim.schedule(function()
			callback(status)
		end)
	end)

	if not handle then
		stdout:close()
		callback({})
		return
	end

	stdout:read_start(function(_, data)
		if data then
			output = output .. data
		end
	end)
end

local function get_highlight_group(status_code)
	if not status_code then
		return nil, nil
	end

	local first_char = status_code:sub(1, 1)
	local second_char = status_code:sub(2, 2)

	if
		first_char == "U"
		or second_char == "U"
		or (first_char == "A" and second_char == "A")
		or (first_char == "D" and second_char == "D")
	then
		return "OilGitConflict", "!"
	end

	if first_char == "A" then
		return "OilGitAdded", "+"
	elseif first_char == "M" then
		return "OilGitModified", "~"
	elseif first_char == "R" then
		return "OilGitRenamed", "→"
	elseif first_char == "D" then
		return "OilGitDeleted", "D"
	elseif first_char == "C" then
		return "OilGitRenamed", "C"
	end

	if second_char == "M" then
		return "OilGitModified", "~"
	elseif second_char == "D" then
		return "OilGitDeleted", "D"
	end

	if status_code == "??" then
		return "OilGitUntracked", "?"
	end

	if status_code == "!!" then
		return "OilGitIgnored", "◌"
	end

	return nil, nil
end

local function clear_highlights()
	for _, _ in pairs(default_highlights) do
		vim.fn.clearmatches()
	end

	local ns_id = vim.api.nvim_create_namespace("oil_git_status")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

local function apply_highlights_to_buffer(bufnr, current_dir, git_status)
	local oil = require("oil")

	if vim.tbl_isempty(git_status) then
		clear_highlights()
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	clear_highlights()

	for i, line in ipairs(lines) do
		local entry = oil.get_entry_on_line(bufnr, i)
		if entry and entry.type == "file" then
			local filepath = current_dir .. entry.name

			local status_code = git_status[filepath]
			local hl_group, symbol = get_highlight_group(status_code)

			if hl_group and symbol then
				local name_start = line:find(entry.name, 1, true)
				if name_start then
					vim.fn.matchaddpos(hl_group, { { i, name_start, #entry.name } })

					local ns_id = vim.api.nvim_create_namespace("oil_git_status")
					vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
						virt_text = { { " " .. symbol, hl_group } },
						virt_text_pos = "eol",
						hl_mode = "combine",
					})
				end
			end
		end
	end
end

local function apply_git_highlights()
	local oil = require("oil")
	local current_dir = oil.get_current_dir()
	local bufnr = vim.api.nvim_get_current_buf()

	if not current_dir then
		clear_highlights()
		return
	end

	get_git_status_async(current_dir, function(git_status)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local new_dir = oil.get_current_dir()
		if new_dir ~= current_dir then
			return
		end

		apply_highlights_to_buffer(bufnr, current_dir, git_status)
	end)
end

local function apply_git_highlights_debounced()
	if pending_timer then
		vim.fn.timer_stop(pending_timer)
	end
	pending_timer = vim.fn.timer_start(debounce_ms, function()
		pending_timer = nil
		apply_git_highlights()
	end)
end

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("OilGitStatus", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = "oil://*",
		callback = apply_git_highlights_debounced,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		pattern = "oil://*",
		callback = clear_highlights,
	})

	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = group,
		pattern = "oil://*",
		callback = apply_git_highlights_debounced,
	})

	vim.api.nvim_create_autocmd({ "FocusGained", "WinEnter", "BufWinEnter" }, {
		group = group,
		pattern = "oil://*",
		callback = apply_git_highlights_debounced,
	})

	vim.api.nvim_create_autocmd("TermClose", {
		group = group,
		callback = function()
			if vim.bo.filetype == "oil" then
				apply_git_highlights_debounced()
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "FugitiveChanged", "GitSignsUpdate", "LazyGitClosed" },
		callback = function()
			if vim.bo.filetype == "oil" then
				apply_git_highlights_debounced()
			end
		end,
	})
end

local initialized = false

local function initialize()
	if initialized then
		return
	end

	setup_highlights()
	setup_autocmds()
	initialized = true
end

function M.setup(opts)
	opts = opts or {}

	if opts.highlights then
		default_highlights = vim.tbl_extend("force", default_highlights, opts.highlights)
	end

	if opts.debounce_ms then
		debounce_ms = opts.debounce_ms
	end

	initialize()
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "oil",
	callback = function()
		initialize()
	end,
	group = vim.api.nvim_create_augroup("OilGitAutoInit", { clear = true }),
})

function M.refresh()
	apply_git_highlights()
end

return M
