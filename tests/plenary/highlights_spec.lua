describe("highlights", function()
	local highlights
	local config
	local helpers = require("tests.helpers")

	before_each(function()
		helpers.reset_oil_git_modules()
		config = require("oil-git.config")
		config.setup({})
		highlights = require("oil-git.highlights")
	end)

	after_each(function()
		helpers.close_oil_buffers()
	end)

	describe("setup", function()
		it("should create highlight groups that don't exist", function()
			vim.cmd("highlight clear OilGitAdded")
			vim.cmd("highlight clear OilGitModified")
			vim.cmd("highlight clear OilGitDeleted")

			highlights.setup()

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

		it("should not overwrite existing highlight groups", function()
			vim.api.nvim_set_hl(0, "OilGitAdded", { fg = "#123456" })

			highlights.setup()

			local hl = vim.api.nvim_get_hl(0, { name = "OilGitAdded" })
			assert.is_not_nil(hl.fg)
		end)
	end)

	describe("clear", function()
		it("should not error on any buffer type", function()
			local bufnr = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(bufnr)

			assert.has_no.errors(function()
				highlights.clear(bufnr)
			end)

			assert.has_no.errors(function()
				highlights.clear({ buf = bufnr })
			end)

			vim.api.nvim_buf_delete(bufnr, { force = true })
			assert.has_no.errors(function()
				highlights.clear(bufnr)
			end)
		end)
	end)

	describe("namespace management", function()
		it("should not accumulate extmarks when switching buffers", function()
			local bufnr1 = vim.api.nvim_create_buf(false, true)
			local bufnr2 = vim.api.nvim_create_buf(false, true)

			local ns1 = vim.api.nvim_create_namespace("oil_git_test_ns1")
			local ns2 = vim.api.nvim_create_namespace("oil_git_test_ns2")

			vim.api.nvim_buf_set_lines(
				bufnr1,
				0,
				-1,
				false,
				{ "line1", "line2" }
			)
			vim.api.nvim_buf_set_extmark(bufnr1, ns1, 0, 0, {
				virt_text = { { " +", "OilGitAdded" } },
				virt_text_pos = "eol",
			})

			vim.api.nvim_buf_set_lines(
				bufnr2,
				0,
				-1,
				false,
				{ "line1", "line2" }
			)
			vim.api.nvim_buf_set_extmark(bufnr2, ns2, 0, 0, {
				virt_text = { { " ~", "OilGitModified" } },
				virt_text_pos = "eol",
			})

			vim.api.nvim_buf_clear_namespace(bufnr1, ns1, 0, -1)

			local extmarks1 =
				vim.api.nvim_buf_get_extmarks(bufnr1, ns1, 0, -1, {})
			assert.equals(0, #extmarks1)

			local extmarks2 =
				vim.api.nvim_buf_get_extmarks(bufnr2, ns2, 0, -1, {})
			assert.equals(1, #extmarks2)

			vim.api.nvim_buf_delete(bufnr1, { force = true })
			vim.api.nvim_buf_delete(bufnr2, { force = true })
		end)
	end)

	describe("integration with oil.nvim", function()
		local oil_available = pcall(require, "oil")

		if oil_available then
			it(
				"should apply highlights to oil buffer with git status",
				function()
					local repo_dir = helpers.create_temp_git_repo()
					helpers.create_file(
						repo_dir,
						"untracked.lua",
						"-- untracked"
					)
					helpers.create_and_commit_file(
						repo_dir,
						"committed.lua",
						"-- committed"
					)
					helpers.create_file(
						repo_dir,
						"committed.lua",
						"-- modified"
					)

					local oil = require("oil")
					oil.open(repo_dir)

					local ready = helpers.wait_for(function()
						return vim.bo.filetype == "oil"
					end, 2000)

					if ready then
						local bufnr = vim.api.nvim_get_current_buf()
						highlights.apply()

						vim.wait(1000, function()
							return false
						end, 100)

						assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
					end

					helpers.close_oil_buffers()
					helpers.cleanup(repo_dir)
				end
			)

			describe("untracked and ignored inheritance", function()
				local repo_dir

				before_each(function()
					repo_dir = helpers.create_temp_git_repo()
					helpers.create_directory(repo_dir, "untracked_dir")
					helpers.create_file(
						repo_dir,
						"untracked_dir/file1.lua",
						"content"
					)
					helpers.create_directory(repo_dir, "untracked_dir/subdir")
					helpers.create_file(
						repo_dir,
						"untracked_dir/subdir/nested.lua",
						"content"
					)
					helpers.create_gitignore(repo_dir, { "ignored_dir/" })
					helpers.stage_file(repo_dir, ".gitignore")
					helpers.commit(repo_dir, "add gitignore")
					helpers.create_directory(repo_dir, "ignored_dir")
					helpers.create_file(
						repo_dir,
						"ignored_dir/file1.lua",
						"content"
					)
				end)

				after_each(function()
					helpers.close_oil_buffers()
					helpers.cleanup(repo_dir)
				end)

				it(
					"should show status for files in untracked and ignored dirs",
					function()
						local oil = require("oil")
						oil.open(repo_dir .. "/untracked_dir")

						local ready = helpers.wait_for(function()
							return vim.bo.filetype == "oil"
						end, 2000)

						if ready then
							local bufnr = vim.api.nvim_get_current_buf()
							helpers.wait_for_oil_entries(bufnr, 2000)
							highlights.apply(
								bufnr,
								repo_dir .. "/untracked_dir/"
							)

							local has_extmarks = helpers.wait_for(function()
								return helpers.count_extmarks(bufnr) > 0
							end, 2000)

							assert.is_true(
								has_extmarks,
								"Expected extmarks for untracked files"
							)
						end
					end
				)
			end)

			describe("navigation and symbol accumulation", function()
				local repo_dir

				before_each(function()
					repo_dir = helpers.create_temp_git_repo()
					helpers.create_directory(repo_dir, "dir_a")
					helpers.create_file(repo_dir, "dir_a/file.lua", "content")
					helpers.create_directory(repo_dir, "dir_b")
					helpers.create_file(repo_dir, "dir_b/file.lua", "content")
				end)

				after_each(function()
					helpers.close_oil_buffers()
					helpers.cleanup(repo_dir)
				end)

				it("should clear old namespace on new apply", function()
					local oil = require("oil")
					oil.open(repo_dir .. "/dir_a")

					local ready = helpers.wait_for(function()
						return vim.bo.filetype == "oil"
					end, 2000)

					if not ready then
						return
					end

					local bufnr = vim.api.nvim_get_current_buf()

					highlights.apply(bufnr, repo_dir .. "/dir_a/")
					vim.wait(500, function()
						return false
					end, 50)

					local count_after_first = helpers.count_extmarks(bufnr)

					highlights.apply(bufnr, repo_dir .. "/dir_a/")
					vim.wait(500, function()
						return false
					end, 50)

					local count_after_second = helpers.count_extmarks(bufnr)

					assert.equals(count_after_first, count_after_second)
				end)

				it("should track namespaces per buffer", function()
					local oil = require("oil")

					oil.open(repo_dir .. "/dir_a")
					helpers.wait_for(function()
						return vim.bo.filetype == "oil"
					end, 2000)

					local bufnr_a = vim.api.nvim_get_current_buf()
					highlights.apply(bufnr_a, repo_dir .. "/dir_a/")
					vim.wait(500, function()
						return false
					end, 50)

					vim.cmd("tabnew")
					oil.open(repo_dir .. "/dir_b")
					helpers.wait_for(function()
						return vim.bo.filetype == "oil"
					end, 2000)

					local bufnr_b = vim.api.nvim_get_current_buf()
					highlights.apply(bufnr_b, repo_dir .. "/dir_b/")
					vim.wait(500, function()
						return false
					end, 50)

					local count_b_before = helpers.count_extmarks(bufnr_b)

					highlights.clear(bufnr_a)

					local count_a_after = helpers.count_extmarks(bufnr_a)
					local count_b_after = helpers.count_extmarks(bufnr_b)

					assert.equals(0, count_a_after)
					assert.equals(count_b_before, count_b_after)

					vim.cmd("tabclose")
				end)

				it(
					"should not accumulate extmarks on repeated apply",
					function()
						local oil = require("oil")
						oil.open(repo_dir .. "/dir_a")

						local ready = helpers.wait_for(function()
							return vim.bo.filetype == "oil"
						end, 2000)

						if not ready then
							return
						end

						local bufnr = vim.api.nvim_get_current_buf()

						for _ = 1, 10 do
							highlights.apply(bufnr, repo_dir .. "/dir_a/")
							vim.wait(100, function()
								return false
							end, 10)
						end

						vim.wait(500, function()
							return false
						end, 50)

						local final_count = helpers.count_extmarks(bufnr)
						assert.is_true(final_count <= 2)
					end
				)
			end)
		end
	end)

	describe("empty git status handling", function()
		it("should handle clean repository", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_and_commit_file(repo_dir, "file.lua", "content")

			if pcall(require, "oil") then
				local oil = require("oil")
				oil.open(repo_dir)

				local ready = helpers.wait_for(function()
					return vim.bo.filetype == "oil"
				end, 2000)

				if ready then
					local bufnr = vim.api.nvim_get_current_buf()
					highlights.apply(bufnr, repo_dir .. "/")

					vim.wait(500, function()
						return false
					end, 50)

					local count = helpers.count_extmarks(bufnr)
					assert.equals(0, count)
				end

				helpers.close_oil_buffers()
			end

			helpers.cleanup(repo_dir)
		end)
	end)
end)
