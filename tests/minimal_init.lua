local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(root)

package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function add_plugin(name)
	local paths = {
		vim.fn.stdpath("data") .. "/lazy/" .. name,
		vim.fn.stdpath("data") .. "/site/pack/packer/start/" .. name,
		vim.fn.stdpath("data") .. "/plugged/" .. name,
		vim.fn.expand("~/.local/share/nvim/lazy/" .. name),
		vim.env.HOME .. "/.local/share/nvim/site/pack/vendor/start/" .. name,
	}

	for _, path in ipairs(paths) do
		if vim.fn.isdirectory(path) == 1 then
			vim.opt.rtp:prepend(path)
			return true
		end
	end

	return false
end

local plenary_found = add_plugin("plenary.nvim")
local oil_found = add_plugin("oil.nvim")

if not plenary_found then
	print("ERROR: plenary.nvim not found. Please install it.")
	vim.cmd("qa!")
end

if not oil_found then
	print("WARNING: oil.nvim not found. Some tests may fail.")
end

vim.cmd("runtime plugin/plenary.vim")

vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

local ok, oil = pcall(require, "oil")
if ok then
	oil.setup({
		default_file_explorer = false,
		skip_confirm_for_simple_edits = true,
	})
end
