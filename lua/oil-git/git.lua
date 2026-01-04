local M = {}

local uv = vim.uv or vim.loop
local path = require("oil-git.path")
local trie = require("oil-git.trie")
local util = require("oil-git.util")

local CACHE_TTL_MS = 500

local cache = {
	git_root = nil,
	timestamp = 0,
	status = {},
	status_trie = nil,
}

function M.invalidate_cache()
	cache.git_root = nil
	cache.timestamp = 0
	cache.status = {}
	cache.status_trie = nil
	util.debug_log("verbose", "Git status cache invalidated")
end

function M.get_root(dir)
	local git_dir = vim.fn.finddir(".git", dir .. ";")
	if git_dir == "" then
		return nil
	end
	return vim.fn.fnamemodify(git_dir, ":p:h:h")
end

local function parse_output(output, git_root)
	if type(output) ~= "string" then
		util.debug_log("minimal", "Invalid git output type: %s", type(output))
		return {}, trie.create_node()
	end

	if type(git_root) ~= "string" or git_root == "" then
		util.debug_log("minimal", "Invalid git root: %s", tostring(git_root))
		return {}, trie.create_node()
	end

	local status = {}
	local status_trie = trie.create_node()

	for line in output:gmatch("[^\r\n]+") do
		-- Validate minimum line length (2 status chars + space + 1 char path)
		if #line < 4 then
			goto continue
		end

		local status_code = line:sub(1, 2)
		local filepath = line:sub(4)

		-- Skip empty filepaths
		if not filepath or filepath == "" then
			goto continue
		end

		if status_code:sub(1, 1) == "R" or status_code:sub(1, 1) == "C" then
			local arrow_pos = filepath:find(" %-> ")
			if arrow_pos then
				filepath = filepath:sub(arrow_pos + 4)
			end
		end

		if filepath:sub(1, 2) == "./" then
			filepath = filepath:sub(3)
		end

		filepath = path.git_to_os(filepath)
		local abs_path = path.join(git_root, filepath)
		abs_path = path.remove_trailing_slash(abs_path)

		status[abs_path] = status_code
		trie.insert(status_trie, abs_path, status_code, git_root)

		::continue::
	end

	return status, status_trie
end

function M.get_status_async(dir, callback)
	local git_root = M.get_root(dir)
	if not git_root then
		util.debug_log("verbose", "No git root found for: %s", dir)
		callback({}, nil, nil)
		return
	end

	local now = uv.now()
	if
		cache.git_root == git_root
		and (now - cache.timestamp) < CACHE_TTL_MS
	then
		util.debug_log(
			"verbose",
			"Cache hit for: %s (age: %dms)",
			git_root,
			now - cache.timestamp
		)
		callback(cache.status, cache.status_trie, cache.git_root)
		return
	end

	util.debug_log(
		"verbose",
		"Cache miss, fetching git status for: %s",
		git_root
	)

	local stdout = uv.new_pipe(false)
	local output_parts = {}

	local handle
	handle = uv.spawn("git", {
		args = { "status", "--porcelain", "--ignored" },
		cwd = git_root,
		stdio = { nil, stdout, nil },
	}, function(code)
		stdout:read_stop()
		stdout:close()
		handle:close()

		if code ~= 0 then
			util.debug_log("minimal", "Git command failed with code: %d", code)
			vim.schedule(function()
				callback({}, nil, nil)
			end)
			return
		end

		local output = table.concat(output_parts)
		local status, status_trie = parse_output(output, git_root)

		cache.git_root = git_root
		cache.timestamp = uv.now()
		cache.status = status
		cache.status_trie = status_trie

		util.debug_log(
			"verbose",
			"Git status returned %d files, cached",
			vim.tbl_count(status)
		)
		vim.schedule(function()
			callback(status, status_trie, git_root)
		end)
	end)

	if not handle then
		util.debug_log("minimal", "Failed to spawn git process")
		stdout:close()
		vim.schedule(function()
			callback({}, nil, nil)
		end)
		return
	end

	stdout:read_start(function(_, data)
		if data then
			table.insert(output_parts, data)
		end
	end)
end

return M
