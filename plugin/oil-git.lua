if vim.g.loaded_oil_git then
	return
end
vim.g.loaded_oil_git = true

vim.api.nvim_create_autocmd("FileType", {
	pattern = "oil",
	callback = function()
		local oil_git = require("oil-git")
		oil_git.init()
		if
			oil_git._is_configured()
			or vim.tbl_isempty(require("oil-git.config").get())
		then
			vim.schedule(function()
				require("oil-git.highlights").apply_debounced()
			end)
		end
	end,
	group = vim.api.nvim_create_augroup("OilGitAutoInit", { clear = true }),
})
