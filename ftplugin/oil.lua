local ok, oil_git = pcall(require, "oil-git")
if ok then
	if not oil_git._is_configured() then
		oil_git.setup()
	else
		oil_git.refresh()
	end
end
