local M = {}

local config = require("oil-git.config")
local constants = require("oil-git.constants")
local status_mapper = require("oil-git.status_mapper")
local trie = require("oil-git.trie")
local util = require("oil-git.util")

local git = require("oil-git.git")

local pending_timers = {} -- { [bufnr] = timer_id }
local MAX_PENDING_TIMERS = 10
local buffer_ns_ids = {}
local buffer_highlight_hashes = {} -- { [bufnr] = sha256_hash }
local signcolumn_cache = nil

local function get_namespace(suffix)
	return vim.api.nvim_create_namespace(constants.NAMESPACES.PREFIX .. suffix)
end

local function can_use_signcolumn()
	if signcolumn_cache ~= nil then
		return signcolumn_cache
	end

	local ok, oil_config = pcall(function()
		return require("oil.config")
	end)

	if ok and oil_config then
		local win_opts = oil_config.win_options or {}
		if win_opts.signcolumn then
			local sc = win_opts.signcolumn
			if
				sc == "yes:2"
				or sc == "auto:2"
				or sc:match(":2")
				or sc:match(":3")
				or sc:match(":4")
			then
				signcolumn_cache = true
				return true
			end
			if sc == "no" then
				signcolumn_cache = false
				return false
			end
			util.debug_log(
				"verbose",
				"Signcolumn '%s' may conflict with oil.nvim, falling back to %s",
				sc,
				constants.SYMBOL_POSITIONS.EOL
			)
			signcolumn_cache = false
			return false
		end
	end

	signcolumn_cache = true
	return true
end

function M.setup()
	signcolumn_cache = nil -- Reset cache on setup
	local cfg = config.get_raw()
	for name, opts in pairs(cfg.highlights) do
		if vim.fn.hlexists(name) == 0 then
			vim.api.nvim_set_hl(0, name, opts)
		end
	end
end

function M.invalidate_signcolumn_cache()
	signcolumn_cache = nil
end

function M.clear(bufnr)
	if type(bufnr) == "table" then
		bufnr = bufnr.buf
	end
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local ns_id = buffer_ns_ids[bufnr]
	if ns_id then
		pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
		buffer_ns_ids[bufnr] = nil
	end
	buffer_highlight_hashes[bufnr] = nil
end

function M.on_buf_delete(bufnr)
	if type(bufnr) == "table" then
		bufnr = bufnr.buf
	end

	if pending_timers[bufnr] then
		vim.fn.timer_stop(pending_timers[bufnr])
		pending_timers[bufnr] = nil
	end

	buffer_ns_ids[bufnr] = nil
	buffer_highlight_hashes[bufnr] = nil
end

local function apply_to_buffer(
	bufnr,
	current_dir,
	git_status,
	status_trie,
	git_root
)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local oil = require("oil")
	local cfg = config.get()

	if vim.tbl_isempty(git_status) then
		M.clear(bufnr)
		util.debug_log("verbose", "No git status found, cleared highlights")
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local line_count = #lines
	local show_file_highlights = cfg.show_file_highlights
	local show_directory_highlights = cfg.show_directory_highlights
	local show_file_symbols = cfg.show_file_symbols
	local show_directory_symbols = cfg.show_directory_symbols
	local show_ignored_files = cfg.show_ignored_files
	local show_ignored_directories = cfg.show_ignored_directories
	local symbol_position = cfg.symbol_position
	local use_signcolumn = symbol_position
			== constants.SYMBOL_POSITIONS.SIGNCOLUMN
		and can_use_signcolumn()
	local symbols_not_disabled = symbol_position
		~= constants.SYMBOL_POSITIONS.NONE
	local file_symbols = cfg.symbols.file
	local dir_symbols = cfg.symbols.directory

	-- Phase 1: Single loop to collect highlights and build hash
	local highlights = {}
	local highlights_idx = 0
	-- Include changedtick to detect buffer redraws (e.g., oil refresh)
	local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
	local hash_parts = { current_dir, tostring(changedtick) }
	local hash_idx = 2

	-- Pre-allocate highlights table
	for i = 1, line_count do
		highlights[i] = nil
	end

	for i = 1, line_count do
		local line = lines[i]
		local ok, entry = pcall(oil.get_entry_on_line, bufnr, i)
		if not ok or not entry then
			goto continue
		end

		local status_code = nil
		local symbols = nil
		local entry_name = entry.name
		local entry_path = current_dir .. entry_name
		local is_directory = false
		local show_highlight = false
		local show_symbol = false

		if entry.type == constants.ENTRY_TYPES.FILE then
			symbols = file_symbols
			status_code = git_status[entry_path]
			if not status_code then
				status_code = trie.lookup(
					status_trie,
					entry_path,
					git_root,
					not show_ignored_files
				)
			end
			if
				status_code == constants.GIT_STATUS.IGNORED
				and not show_ignored_files
			then
				status_code = nil
			end
			show_highlight = show_file_highlights
			show_symbol = show_file_symbols and symbols_not_disabled
		elseif entry.type == constants.ENTRY_TYPES.DIRECTORY then
			symbols = dir_symbols
			is_directory = true
			show_highlight = show_directory_highlights
			show_symbol = show_directory_symbols and symbols_not_disabled
			if show_highlight or show_symbol then
				status_code = trie.lookup(
					status_trie,
					entry_path,
					git_root,
					not show_ignored_directories
				)
			end
		end

		-- Build hash part (no line index - reordering won't trigger rehighlight)
		hash_idx = hash_idx + 1
		hash_parts[hash_idx] =
			string.format("%s:%s", entry_name, status_code or "")

		-- Collect highlight data if applicable
		if status_code and symbols then
			local hl_group, symbol = status_mapper.map(status_code, symbols)

			if hl_group then
				local name_start = line:find(entry_name, 1, true)
				if name_start then
					local highlight_len = #entry_name

					if is_directory then
						local slash_pos = name_start + highlight_len
						if line:sub(slash_pos, slash_pos) == "/" then
							highlight_len = highlight_len + 1
						end
					end

					highlights_idx = highlights_idx + 1
					highlights[highlights_idx] = {
						line_idx = i - 1,
						start_col = name_start - 1,
						end_col = name_start - 1 + highlight_len,
						hl_group = hl_group,
						symbol = symbol,
						show_highlight = show_highlight,
						show_symbol = show_symbol,
					}
				end
			end
		end

		::continue::
	end

	-- Phase 2: Compute hash and check if highlights need updating
	local new_hash = vim.fn.sha256(table.concat(hash_parts, "|"))
	if buffer_highlight_hashes[bufnr] == new_hash then
		util.debug_log("verbose", "Highlight hash unchanged, skipping reapply")
		return
	end
	buffer_highlight_hashes[bufnr] = new_hash

	-- Phase 3: Apply highlights from collected data
	local ns_id = get_namespace(bufnr)
	pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)

	local highlight_count = 0
	local symbol_count = 0

	for i = 1, highlights_idx do
		local hl = highlights[i]

		if hl.show_highlight then
			local extmark_ok = pcall(
				vim.api.nvim_buf_set_extmark,
				bufnr,
				ns_id,
				hl.line_idx,
				hl.start_col,
				{
					end_col = hl.end_col,
					hl_group = hl.hl_group,
				}
			)
			if extmark_ok then
				highlight_count = highlight_count + 1
			end
		end

		if hl.show_symbol and hl.symbol then
			if use_signcolumn then
				pcall(
					vim.api.nvim_buf_set_extmark,
					bufnr,
					ns_id,
					hl.line_idx,
					0,
					{
						sign_text = hl.symbol:sub(1, 2),
						sign_hl_group = hl.hl_group,
					}
				)
			else
				pcall(
					vim.api.nvim_buf_set_extmark,
					bufnr,
					ns_id,
					hl.line_idx,
					0,
					{
						virt_text = {
							{ " " .. hl.symbol, hl.hl_group },
						},
						virt_text_pos = "eol",
						hl_mode = "combine",
					}
				)
			end
			symbol_count = symbol_count + 1
		end
	end

	buffer_ns_ids[bufnr] = ns_id

	util.debug_log(
		"verbose",
		"Applied %d highlights, %d symbols",
		highlight_count,
		symbol_count
	)
end

function M.apply(bufnr, captured_dir)
	local oil = require("oil")
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local current_dir = captured_dir
	if not current_dir then
		local ok, dir = pcall(oil.get_current_dir, bufnr)
		if ok then
			current_dir = dir
		end
	end

	if not current_dir then
		M.clear(bufnr)
		return
	end

	git.get_status_async(
		current_dir,
		function(git_status, status_trie, git_root)
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end
			local ok, new_dir = pcall(oil.get_current_dir, bufnr)
			if not ok or new_dir ~= current_dir then
				return
			end

			apply_to_buffer(
				bufnr,
				current_dir,
				git_status,
				status_trie,
				git_root
			)
		end
	)
end

function M.apply_debounced()
	local oil = require("oil")
	local cfg = config.get()
	local bufnr = vim.api.nvim_get_current_buf()

	local ok, current_dir = pcall(oil.get_current_dir, bufnr)
	if not ok or not current_dir then
		return
	end

	if pending_timers[bufnr] then
		vim.fn.timer_stop(pending_timers[bufnr])
		pending_timers[bufnr] = nil
	end

	local timer_count = vim.tbl_count(pending_timers)
	if timer_count >= MAX_PENDING_TIMERS then
		for buf, timer in pairs(pending_timers) do
			vim.fn.timer_stop(timer)
			pending_timers[buf] = nil
		end
	end

	pending_timers[bufnr] = vim.fn.timer_start(cfg.debounce_ms, function()
		pending_timers[bufnr] = nil
		if vim.api.nvim_buf_is_valid(bufnr) then
			M.apply(bufnr, current_dir)
		end
	end)
end

function M.apply_immediate()
	local oil = require("oil")
	local bufnr = vim.api.nvim_get_current_buf()

	local ok, current_dir = pcall(oil.get_current_dir, bufnr)
	if not ok or not current_dir then
		return
	end

	if pending_timers[bufnr] then
		vim.fn.timer_stop(pending_timers[bufnr])
		pending_timers[bufnr] = nil
	end

	M.apply(bufnr, current_dir)
end

return M
