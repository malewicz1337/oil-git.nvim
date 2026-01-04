local M = {}

local constants = require("oil-git.constants")
local path = require("oil-git.path")
local status_mapper = require("oil-git.status_mapper")

local function get_relative_path(filepath, git_root)
	if not filepath or not git_root then
		return nil
	end
	filepath = path.remove_trailing_slash(filepath)
	git_root = path.remove_trailing_slash(git_root)

	if #filepath <= #git_root then
		return nil
	end

	-- Verify filepath starts with git_root
	if filepath:sub(1, #git_root) ~= git_root then
		return nil
	end

	return filepath:sub(#git_root + 2)
end

function M.create_node()
	return {
		children = {},
		status = nil,
		priority = 0,
	}
end

function M.insert(root, filepath, status_code, git_root)
	local priority = status_mapper.get_priority(status_code)
	if priority == 0 then
		return
	end

	local rel_path = get_relative_path(filepath, git_root)
	if not rel_path then
		return
	end

	local segments = path.split(rel_path)

	local node = root
	for _, segment in ipairs(segments) do
		if not node.children[segment] then
			node.children[segment] = M.create_node()
		end
		node = node.children[segment]

		if priority > node.priority then
			node.status = status_code
			node.priority = priority
		end
	end
end

function M.lookup(root, dir_path, git_root)
	if not root or not git_root then
		return nil
	end

	local rel_path = get_relative_path(dir_path, git_root)
	if not rel_path then
		return nil
	end

	local segments = path.split(rel_path)
	local node = root
	local inherited_status = nil

	for _, segment in ipairs(segments) do
		if
			node.status == constants.GIT_STATUS.UNTRACKED
			or node.status == constants.GIT_STATUS.IGNORED
		then
			inherited_status = node.status
		end

		if not node.children[segment] then
			return inherited_status
		end
		node = node.children[segment]
	end

	return node.status
end

return M
