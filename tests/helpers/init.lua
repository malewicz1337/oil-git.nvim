local M = {}

local uv = vim.uv or vim.loop

function M.create_temp_git_repo()
	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, "p")

	vim.fn.system({ "git", "init", tmp_dir })
	vim.fn.system({
		"git",
		"-C",
		tmp_dir,
		"config",
		"user.email",
		"test@test.com",
	})
	vim.fn.system({ "git", "-C", tmp_dir, "config", "user.name", "Test" })

	return tmp_dir
end

function M.create_file(repo_dir, filename, content)
	content = content or ""
	local filepath = repo_dir .. "/" .. filename

	local parent = vim.fn.fnamemodify(filepath, ":h")
	if vim.fn.isdirectory(parent) == 0 then
		vim.fn.mkdir(parent, "p")
	end

	vim.fn.writefile(vim.split(content, "\n"), filepath)
end

function M.stage_file(repo_dir, filename)
	vim.fn.system({ "git", "-C", repo_dir, "add", filename })
end

function M.commit(repo_dir, message)
	message = message or "test commit"
	vim.fn.system({ "git", "-C", repo_dir, "commit", "-m", message })
end

function M.create_and_commit_file(repo_dir, filename, content)
	M.create_file(repo_dir, filename, content)
	M.stage_file(repo_dir, filename)
	M.commit(repo_dir, "add " .. filename)
end

function M.delete_file(repo_dir, filename)
	local filepath = repo_dir .. "/" .. filename
	vim.fn.delete(filepath)
end

function M.rename_file(repo_dir, old_name, new_name)
	vim.fn.system({ "git", "-C", repo_dir, "mv", old_name, new_name })
end

function M.create_directory(repo_dir, dirname)
	local dirpath = repo_dir .. "/" .. dirname
	vim.fn.mkdir(dirpath, "p")
end

function M.get_git_status(repo_dir)
	local result = vim.fn.system({
		"git",
		"-C",
		repo_dir,
		"status",
		"--porcelain",
		"--ignored",
	})
	return result
end

function M.cleanup(dir)
	if dir and vim.fn.isdirectory(dir) == 1 then
		vim.fn.delete(dir, "rf")
	end
end

function M.wait_for(condition, timeout_ms)
	timeout_ms = timeout_ms or 5000
	return vim.wait(timeout_ms, condition, 10)
end

function M.reset_oil_git_modules()
	local modules = {
		"oil-git",
		"oil-git.init",
		"oil-git.config",
		"oil-git.constants",
		"oil-git.git",
		"oil-git.highlights",
		"oil-git.path",
		"oil-git.status_mapper",
		"oil-git.trie",
		"oil-git.util",
		"oil-git.health",
	}
	for _, mod in ipairs(modules) do
		package.loaded[mod] = nil
	end
end

function M.close_oil_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local ft = vim.bo[bufnr].filetype
			if ft == "oil" then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
	end
end

function M.now()
	return uv.now()
end

function M.create_gitignore(repo_dir, patterns)
	local content = table.concat(patterns, "\n")
	M.create_file(repo_dir, ".gitignore", content)
end

function M.count_extmarks(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return 0
	end
	local ns_id = vim.api.nvim_create_namespace("oil_git_status_" .. bufnr)
	local ok, extmarks =
		pcall(vim.api.nvim_buf_get_extmarks, bufnr, ns_id, 0, -1, {})
	if ok then
		return #extmarks
	end
	return 0
end

function M.wait_for_oil_entries(bufnr, timeout_ms)
	timeout_ms = timeout_ms or 2000
	return vim.wait(timeout_ms, function()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		return #lines > 1 or (lines[1] and lines[1] ~= "")
	end, 50)
end

return M
