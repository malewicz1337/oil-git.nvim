describe("init", function()
	local oil_git
	local helpers = require("tests.helpers")

	before_each(function()
		helpers.reset_oil_git_modules()
		pcall(vim.api.nvim_del_augroup_by_name, "OilGitStatus")
		oil_git = require("oil-git")
	end)

	describe("setup", function()
		it("should accept nil and empty options", function()
			assert.has_no.errors(function()
				oil_git.setup(nil)
			end)
			helpers.reset_oil_git_modules()
			oil_git = require("oil-git")
			assert.has_no.errors(function()
				oil_git.setup({})
			end)
		end)

		it("should mark as configured after setup", function()
			assert.is_false(oil_git._is_configured())
			oil_git.setup({})
			assert.is_true(oil_git._is_configured())
		end)

		it("should apply custom options", function()
			oil_git.setup({
				debounce_ms = 200,
				symbols = { file = { added = "A" } },
				highlights = { OilGitAdded = { fg = "#123456" } },
			})
			local config = require("oil-git.config")
			local cfg = config.get()
			assert.equals(200, cfg.debounce_ms)
			assert.equals("A", cfg.symbols.file.added)
			assert.equals("#123456", cfg.highlights.OilGitAdded.fg)
		end)
	end)

	describe("autocmds", function()
		it(
			"should create OilGitStatus augroup with expected autocmds",
			function()
				oil_git.setup({})

				local autocmds =
					vim.api.nvim_get_autocmds({ group = "OilGitStatus" })
				assert.is_true(#autocmds > 0)

				local events = {}
				for _, ac in ipairs(autocmds) do
					events[ac.event] = true
				end

				assert.is_true(events["BufEnter"], "BufEnter autocmd missing")
				assert.is_true(events["TermClose"], "TermClose autocmd missing")
				assert.is_true(events["User"], "User autocmd missing")
			end
		)

		it("should create autocmds for oil://* pattern", function()
			oil_git.setup({})

			local events_to_check =
				{ "BufEnter", "TextChanged", "FocusGained", "BufDelete" }
			for _, event in ipairs(events_to_check) do
				local autocmds = vim.api.nvim_get_autocmds({
					group = "OilGitStatus",
					event = event,
				})

				local found = false
				for _, ac in ipairs(autocmds) do
					if ac.pattern == "oil://*" then
						found = true
						assert.is_function(ac.callback)
						break
					end
				end
				assert.is_true(found, event .. " autocmd for oil://* not found")
			end
		end)

		it("should clear existing autocmds on re-init", function()
			oil_git.setup({})
			local first_count =
				#vim.api.nvim_get_autocmds({ group = "OilGitStatus" })

			helpers.reset_oil_git_modules()
			oil_git = require("oil-git")
			oil_git.setup({})
			local second_count =
				#vim.api.nvim_get_autocmds({ group = "OilGitStatus" })

			assert.equals(first_count, second_count)
		end)
	end)

	describe("highlight groups", function()
		it("should create all highlight groups on setup", function()
			oil_git.setup({})

			local groups = {
				"OilGitAdded",
				"OilGitModified",
				"OilGitDeleted",
				"OilGitRenamed",
				"OilGitUntracked",
				"OilGitIgnored",
				"OilGitConflict",
				"OilGitCopied",
			}
			for _, group in ipairs(groups) do
				assert.equals(
					1,
					vim.fn.hlexists(group),
					group .. " should exist"
				)
			end
		end)
	end)

	describe("refresh", function()
		it("should work before and after initialization", function()
			assert.has_no.errors(function()
				oil_git.refresh()
			end)

			oil_git.setup({})
			assert.has_no.errors(function()
				oil_git.refresh()
			end)
		end)
	end)

	if pcall(require, "oil") then
		describe("oil.nvim integration", function()
			local repo_dir

			before_each(function()
				repo_dir = helpers.create_temp_git_repo()
				helpers.create_file(repo_dir, "test.lua", "-- content")
			end)

			after_each(function()
				helpers.close_oil_buffers()
				helpers.cleanup(repo_dir)
			end)

			it("should apply highlights when entering oil buffer", function()
				oil_git.setup({})

				local oil = require("oil")
				oil.open(repo_dir)

				local ready = helpers.wait_for(function()
					return vim.bo.filetype == "oil"
				end, 2000)

				if ready then
					vim.wait(500, function()
						return false
					end, 50)

					local bufnr = vim.api.nvim_get_current_buf()
					local count = helpers.count_extmarks(bufnr)
					assert.is_true(count >= 1)
				end
			end)

			it("should refresh highlights in oil buffer", function()
				oil_git.setup({})

				local oil = require("oil")
				oil.open(repo_dir)

				local ready = helpers.wait_for(function()
					return vim.bo.filetype == "oil"
				end, 2000)

				if ready then
					assert.has_no.errors(function()
						oil_git.refresh()
					end)
				end
			end)
		end)
	end
end)
