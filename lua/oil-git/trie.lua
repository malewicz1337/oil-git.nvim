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
		is_dir_ignored = false,
		is_dir_untracked = false,
	}
end

function M.insert(root, filepath, status_code, git_root, is_directory)
	local priority = status_mapper.get_priority(status_code)
	if priority == 0 then
		return
	end

	local rel_path = get_relative_path(filepath, git_root)
	if not rel_path then
		return
	end

	local segments = path.split(rel_path)
	local segment_count = #segments

	local node = root
	for i, segment in ipairs(segments) do
		if not node.children[segment] then
			node.children[segment] = M.create_node()
		end
		node = node.children[segment]

		if i == segment_count then
			if priority > node.priority then
				node.status = status_code
				node.priority = priority
			end
			if is_directory then
				if status_code == constants.GIT_STATUS.IGNORED then
					node.is_dir_ignored = true
				elseif status_code == constants.GIT_STATUS.UNTRACKED then
					node.is_dir_untracked = true
				end
			end
		end
	end
end

local function get_subtree_status(node, exclude_ignored)
	local dominated_by_ignored = exclude_ignored
		and node.status == constants.GIT_STATUS.IGNORED

	local best_status = nil
	local best_priority = 0

	if node.status and not dominated_by_ignored then
		best_status = node.status
		best_priority = node.priority
	end

	for _, child in pairs(node.children) do
		local child_status, child_priority =
			get_subtree_status(child, exclude_ignored)
		if child_priority > best_priority then
			best_status = child_status
			best_priority = child_priority
		end
	end

	return best_status, best_priority
end

function M.lookup(root, dir_path, git_root, exclude_ignored)
	if not root or not git_root then
		return nil
	end

	local rel_path = get_relative_path(dir_path, git_root)
	if not rel_path then
		return nil
	end

	local segments = path.split(rel_path)
	local node = root

	for _, segment in ipairs(segments) do
		if node.is_dir_ignored then
			if exclude_ignored then
				return nil
			end
			return constants.GIT_STATUS.IGNORED
		end

		if node.is_dir_untracked then
			return constants.GIT_STATUS.UNTRACKED
		end

		if not node.children[segment] then
			return nil
		end
		node = node.children[segment]
	end

	if node.is_dir_ignored then
		if exclude_ignored then
			return nil
		end
		return constants.GIT_STATUS.IGNORED
	end

	if node.is_dir_untracked then
		return constants.GIT_STATUS.UNTRACKED
	end

	if vim.tbl_isempty(node.children) then
		if exclude_ignored and node.status == constants.GIT_STATUS.IGNORED then
			return nil
		end
		return node.status
	end

	local subtree_status = get_subtree_status(node, exclude_ignored)
	return subtree_status
end

return M
