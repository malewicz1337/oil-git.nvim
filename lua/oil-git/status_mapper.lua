local M = {}

local constants = require("oil-git.constants")

local STATUS_MAP = {
	A = { constants.HIGHLIGHT_GROUPS.ADDED, "added", constants.PRIORITY.ADDED },
	M = {
		constants.HIGHLIGHT_GROUPS.MODIFIED,
		"modified",
		constants.PRIORITY.MODIFIED,
	},
	R = {
		constants.HIGHLIGHT_GROUPS.RENAMED,
		"renamed",
		constants.PRIORITY.RENAMED,
	},
	D = {
		constants.HIGHLIGHT_GROUPS.DELETED,
		"deleted",
		constants.PRIORITY.DELETED,
	},
	C = {
		constants.HIGHLIGHT_GROUPS.COPIED,
		"copied",
		constants.PRIORITY.COPIED,
	},
	U = {
		constants.HIGHLIGHT_GROUPS.CONFLICT,
		"conflict",
		constants.PRIORITY.CONFLICT,
	},
}

local WORKTREE_STATUS_MAP = {
	M = {
		constants.HIGHLIGHT_GROUPS.MODIFIED,
		"modified",
		constants.PRIORITY.MODIFIED,
	},
	D = {
		constants.HIGHLIGHT_GROUPS.DELETED,
		"deleted",
		constants.PRIORITY.DELETED,
	},
}

local SPECIAL_STATUS_MAP = {
	["??"] = {
		constants.HIGHLIGHT_GROUPS.UNTRACKED,
		"untracked",
		constants.PRIORITY.UNTRACKED,
	},
	["!!"] = {
		constants.HIGHLIGHT_GROUPS.IGNORED,
		"ignored",
		constants.PRIORITY.IGNORED,
	},
}

local CONFLICT_PATTERNS = {
	["AA"] = true,
	["DD"] = true,
	["UU"] = true,
	["AU"] = true,
	["UA"] = true,
	["DU"] = true,
	["UD"] = true,
}

local function is_conflict(status_code)
	if #status_code < 2 then
		return false
	end

	local first_char = status_code:sub(1, 1)
	local second_char = status_code:sub(2, 2)

	if first_char == "U" or second_char == "U" then
		return true
	end

	return CONFLICT_PATTERNS[status_code] or false
end

function M.map(status_code, symbols)
	if not status_code or #status_code < 2 then
		return nil, nil
	end

	if not symbols then
		return nil, nil
	end

	if is_conflict(status_code) then
		return constants.HIGHLIGHT_GROUPS.CONFLICT, symbols.conflict
	end

	local special = SPECIAL_STATUS_MAP[status_code]
	if special then
		return special[1], symbols[special[2]]
	end

	local first_char = status_code:sub(1, 1)
	local index_status = STATUS_MAP[first_char]
	if index_status then
		return index_status[1], symbols[index_status[2]]
	end

	local second_char = status_code:sub(2, 2)
	local worktree_status = WORKTREE_STATUS_MAP[second_char]
	if worktree_status then
		return worktree_status[1], symbols[worktree_status[2]]
	end

	return nil, nil
end

function M.get_priority(status_code)
	if not status_code or #status_code < 2 then
		return constants.PRIORITY.NONE
	end

	if is_conflict(status_code) then
		return constants.PRIORITY.CONFLICT
	end

	local special = SPECIAL_STATUS_MAP[status_code]
	if special then
		return special[3]
	end

	local first_char = status_code:sub(1, 1)
	local index_status = STATUS_MAP[first_char]
	if index_status then
		return index_status[3]
	end

	local second_char = status_code:sub(2, 2)
	local worktree_status = WORKTREE_STATUS_MAP[second_char]
	if worktree_status then
		return worktree_status[3]
	end

	return constants.PRIORITY.NONE
end

return M
