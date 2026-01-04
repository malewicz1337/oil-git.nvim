local M = {}

M.NAMESPACES = {
	PREFIX = "oil_git_status_",
}

M.DEFAULTS = {
	DEBOUNCE_MS = 50,
}

M.HIGHLIGHT_GROUPS = {
	ADDED = "OilGitAdded",
	MODIFIED = "OilGitModified",
	RENAMED = "OilGitRenamed",
	DELETED = "OilGitDeleted",
	COPIED = "OilGitCopied",
	CONFLICT = "OilGitConflict",
	UNTRACKED = "OilGitUntracked",
	IGNORED = "OilGitIgnored",
}

M.GIT_STATUS = {
	UNTRACKED = "??",
	IGNORED = "!!",
}

M.ENTRY_TYPES = {
	FILE = "file",
	DIRECTORY = "directory",
}

M.SYMBOL_POSITIONS = {
	EOL = "eol",
	SIGNCOLUMN = "signcolumn",
	NONE = "none",
}

M.PRIORITY = {
	NONE = 0,
	IGNORED = 1,
	UNTRACKED = 2,
	RENAMED = 3,
	COPIED = 3,
	ADDED = 4,
	DELETED = 5,
	MODIFIED = 6,
	CONFLICT = 7,
}

return M
