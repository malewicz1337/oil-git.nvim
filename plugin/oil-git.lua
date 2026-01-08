if vim.g.loaded_oil_git then
	return
end
vim.g.loaded_oil_git = true

local group = vim.api.nvim_create_augroup("OilGitAutoInit", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "oil",
	callback = function()
		local ok, oil_git = pcall(require, "oil-git")
		if not ok then
			return
		end

		local success = oil_git.init()
		if success then
			vim.schedule(function()
				require("oil-git.highlights").apply_debounced()
			end)
		end
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	once = true,
	callback = function()
		vim.schedule(function()
			if vim.bo.filetype == "oil" then
				local ok, oil_git = pcall(require, "oil-git")
				if ok then
					oil_git.init()
				end
			end
		end)
	end,
})
