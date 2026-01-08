describe("git", function()
	local git
	local helpers = require("tests.helpers")

	before_each(function()
		helpers.reset_oil_git_modules()
		require("oil-git.config").setup({ debug = false })
		git = require("oil-git.git")
		git.invalidate_cache()
	end)

	describe("get_root", function()
		it("should return nil for non-git directory", function()
			local tmp_dir = vim.fn.tempname()
			vim.fn.mkdir(tmp_dir, "p")

			local result = git.get_root(tmp_dir)
			assert.is_nil(result)

			helpers.cleanup(tmp_dir)
		end)

		it("should find git root for git repository", function()
			local repo_dir = helpers.create_temp_git_repo()

			local result = git.get_root(repo_dir)
			assert.is_not_nil(result)
			assert.is_string(result)

			local normalized_repo = repo_dir:gsub("[/\\]$", "")
			local normalized_result = result:gsub("[/\\]$", "")
			assert.equals(normalized_repo, normalized_result)

			helpers.cleanup(repo_dir)
		end)

		it("should find git root from subdirectory", function()
			local repo_dir = helpers.create_temp_git_repo()
			local sub_dir = repo_dir .. "/src/components"
			vim.fn.mkdir(sub_dir, "p")

			local result = git.get_root(sub_dir)
			assert.is_not_nil(result)

			local normalized_repo = repo_dir:gsub("[/\\]$", "")
			local normalized_result = result:gsub("[/\\]$", "")
			assert.equals(normalized_repo, normalized_result)

			helpers.cleanup(repo_dir)
		end)

		it("should return detection method", function()
			local repo_dir = helpers.create_temp_git_repo()

			local result, method = git.get_root(repo_dir)
			assert.is_not_nil(result)
			assert.is_not_nil(method)
			assert.is_true(method == "finddir" or method == "git")

			helpers.cleanup(repo_dir)
		end)

		it("should return nil method for non-git directory", function()
			local tmp_dir = vim.fn.tempname()
			vim.fn.mkdir(tmp_dir, "p")

			local result, method = git.get_root(tmp_dir)
			assert.is_nil(result)
			assert.is_nil(method)

			helpers.cleanup(tmp_dir)
		end)
	end)

	describe("get_root_async", function()
		it("should find git root asynchronously", function()
			local repo_dir = helpers.create_temp_git_repo()

			local done = false
			local result_root

			git.get_root_async(repo_dir, function(root)
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_not_nil(result_root)
			local normalized_repo = repo_dir:gsub("[/\\]$", "")
			local normalized_result = result_root:gsub("[/\\]$", "")
			assert.equals(normalized_repo, normalized_result)

			helpers.cleanup(repo_dir)
		end)

		it("should return nil for non-git directory", function()
			local tmp_dir = vim.fn.tempname()
			vim.fn.mkdir(tmp_dir, "p")

			local done = false
			local result_root

			git.get_root_async(tmp_dir, function(root)
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_nil(result_root)

			helpers.cleanup(tmp_dir)
		end)

		it("should find git root from subdirectory", function()
			local repo_dir = helpers.create_temp_git_repo()
			local sub_dir = repo_dir .. "/src/components"
			vim.fn.mkdir(sub_dir, "p")

			local done = false
			local result_root

			git.get_root_async(sub_dir, function(root)
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_not_nil(result_root)
			local normalized_repo = repo_dir:gsub("[/\\]$", "")
			local normalized_result = result_root:gsub("[/\\]$", "")
			assert.equals(normalized_repo, normalized_result)

			helpers.cleanup(repo_dir)
		end)

		it("should handle rapid consecutive calls", function()
			local repo_dir = helpers.create_temp_git_repo()

			local call_count = 0
			local results = {}

			for _ = 1, 3 do
				git.get_root_async(repo_dir, function(root)
					call_count = call_count + 1
					table.insert(results, root)
				end)
			end

			helpers.wait_for(function()
				return call_count >= 3
			end)

			assert.equals(3, call_count)
			for _, root in ipairs(results) do
				assert.is_not_nil(root)
			end

			helpers.cleanup(repo_dir)
		end)
	end)

	describe("get_status_async", function()
		it(
			"should call callback with empty result for non-git directory",
			function()
				local tmp_dir = vim.fn.tempname()
				vim.fn.mkdir(tmp_dir, "p")

				local done = false
				local result_status, result_trie, result_root

				git.get_status_async(
					tmp_dir,
					function(status, status_trie, root)
						result_status = status
						result_trie = status_trie
						result_root = root
						done = true
					end
				)

				helpers.wait_for(function()
					return done
				end)

				assert.same({}, result_status)
				assert.is_nil(result_trie)
				assert.is_nil(result_root)

				helpers.cleanup(tmp_dir)
			end
		)

		it("should return empty status for clean repository", function()
			local repo_dir = helpers.create_temp_git_repo()

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.same({}, result_status)

			helpers.cleanup(repo_dir)
		end)

		it("should detect untracked files", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_file(repo_dir, "untracked.lua", "-- untracked file")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/untracked.lua"
			assert.is_not_nil(result_status[file_path])
			assert.equals("??", result_status[file_path])

			helpers.cleanup(repo_dir)
		end)

		it("should detect staged files", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_file(repo_dir, "staged.lua", "-- staged file")
			helpers.stage_file(repo_dir, "staged.lua")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/staged.lua"
			assert.is_not_nil(result_status[file_path])
			assert.equals("A ", result_status[file_path])

			helpers.cleanup(repo_dir)
		end)

		it("should detect modified files", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_and_commit_file(
				repo_dir,
				"file.lua",
				"-- original content"
			)

			helpers.create_file(repo_dir, "file.lua", "-- modified content")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/file.lua"
			assert.is_not_nil(result_status[file_path])
			assert.equals(" M", result_status[file_path])

			helpers.cleanup(repo_dir)
		end)

		it("should detect deleted files", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_and_commit_file(repo_dir, "file.lua", "-- content")

			helpers.delete_file(repo_dir, "file.lua")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/file.lua"
			assert.is_not_nil(result_status[file_path])
			assert.equals(" D", result_status[file_path])

			helpers.cleanup(repo_dir)
		end)

		it("should detect renamed files", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_and_commit_file(
				repo_dir,
				"old_name.lua",
				"-- content"
			)

			helpers.rename_file(repo_dir, "old_name.lua", "new_name.lua")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local new_path = repo_dir .. "/new_name.lua"
			assert.is_not_nil(result_status[new_path])
			assert.matches("^R", result_status[new_path])

			helpers.cleanup(repo_dir)
		end)

		it("should detect files in subdirectories", function()
			local repo_dir = helpers.create_temp_git_repo()

			helpers.create_and_commit_file(
				repo_dir,
				"src/existing.lua",
				"-- existing"
			)

			helpers.create_file(repo_dir, "src/new_file.lua", "-- new file")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status, _status_trie, _root)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local found = false
			local found_status = nil
			for path, status in pairs(result_status) do
				if path:match("new_file%.lua$") then
					found = true
					found_status = status
					break
				end
			end

			assert.is_true(found, "new_file.lua should be in git status")
			assert.equals("??", found_status)

			helpers.cleanup(repo_dir)
		end)

		it("should build status trie for directory lookup", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_directory(repo_dir, "src")
			helpers.create_file(repo_dir, "src/file.lua", "content")

			local done = false
			local result_trie, result_root

			git.get_status_async(repo_dir, function(_status, status_trie, root)
				result_trie = status_trie
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_not_nil(result_trie)
			assert.is_not_nil(result_root)

			local trie = require("oil-git.trie")
			local dir_status =
				trie.lookup(result_trie, repo_dir .. "/src", result_root)
			assert.equals("??", dir_status)

			helpers.cleanup(repo_dir)
		end)

		it("should return git root in callback", function()
			local repo_dir = helpers.create_temp_git_repo()

			local done = false
			local result_root

			git.get_status_async(repo_dir, function(_status, _status_trie, root)
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_not_nil(result_root)
			local normalized_repo = repo_dir:gsub("[/\\]$", "")
			local normalized_root = result_root:gsub("[/\\]$", "")
			assert.equals(normalized_repo, normalized_root)

			helpers.cleanup(repo_dir)
		end)

		describe("caching", function()
			it("should cache results on subsequent calls", function()
				local repo_dir = helpers.create_temp_git_repo()
				helpers.create_file(repo_dir, "file.lua", "content")

				local call_count = 0
				local done = false

				git.get_status_async(repo_dir, function()
					call_count = call_count + 1
				end)

				helpers.wait_for(function()
					return call_count >= 1
				end)

				local before = helpers.now()
				git.get_status_async(repo_dir, function()
					call_count = call_count + 1
					done = true
				end)
				local after = helpers.now()

				helpers.wait_for(function()
					return done
				end)

				assert.is_true(after - before < 100)
				assert.equals(2, call_count)

				helpers.cleanup(repo_dir)
			end)

			it("should invalidate cache when requested", function()
				local repo_dir = helpers.create_temp_git_repo()
				helpers.create_file(repo_dir, "file.lua", "original")

				local done = false

				git.get_status_async(repo_dir, function(_status)
					done = true
				end)

				helpers.wait_for(function()
					return done
				end)

				helpers.create_file(repo_dir, "file.lua", "modified")

				git.invalidate_cache()
				done = false

				local second_status
				git.get_status_async(repo_dir, function(status)
					second_status = status
					done = true
				end)

				helpers.wait_for(function()
					return done
				end)

				assert.is_table(second_status)

				helpers.cleanup(repo_dir)
			end)
		end)

		describe("multiple files", function()
			it(
				"should detect multiple files with different statuses",
				function()
					local repo_dir = helpers.create_temp_git_repo()

					helpers.create_and_commit_file(
						repo_dir,
						"committed.lua",
						"-- committed"
					)

					helpers.create_file(
						repo_dir,
						"untracked.lua",
						"-- untracked"
					)

					helpers.create_file(
						repo_dir,
						"committed.lua",
						"-- modified"
					)

					helpers.create_file(repo_dir, "staged.lua", "-- staged")
					helpers.stage_file(repo_dir, "staged.lua")

					local done = false
					local result_status

					git.get_status_async(repo_dir, function(status)
						result_status = status
						done = true
					end)

					helpers.wait_for(function()
						return done
					end)

					assert.equals(
						" M",
						result_status[repo_dir .. "/committed.lua"]
					)
					assert.equals(
						"??",
						result_status[repo_dir .. "/untracked.lua"]
					)
					assert.equals(
						"A ",
						result_status[repo_dir .. "/staged.lua"]
					)

					helpers.cleanup(repo_dir)
				end
			)
		end)
	end)

	describe("untracked directory handling", function()
		local repo_dir
		local trie

		before_each(function()
			trie = require("oil-git.trie")
			repo_dir = helpers.create_temp_git_repo()
			helpers.create_directory(repo_dir, "untracked_dir")
			helpers.create_file(repo_dir, "untracked_dir/file1.lua", "content")
			helpers.create_file(repo_dir, "untracked_dir/file2.lua", "content")
			helpers.create_directory(repo_dir, "untracked_dir/subdir")
			helpers.create_file(
				repo_dir,
				"untracked_dir/subdir/nested.lua",
				"content"
			)
		end)

		after_each(function()
			helpers.cleanup(repo_dir)
		end)

		it(
			"should detect untracked directory without trailing slash",
			function()
				local done = false
				local result_status

				git.get_status_async(repo_dir, function(status)
					result_status = status
					done = true
				end)

				helpers.wait_for(function()
					return done
				end)

				local found_key = nil
				for key, value in pairs(result_status) do
					if key:match("untracked_dir$") and value == "??" then
						found_key = key
						break
					end
				end

				assert.is_not_nil(found_key)
				assert.is_nil(found_key:match("/$"))
			end
		)

		it("should build trie supporting nested lookups", function()
			local done = false
			local result_trie, result_root

			git.get_status_async(repo_dir, function(_status, status_trie, root)
				result_trie = status_trie
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/untracked_dir",
					result_root
				)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/untracked_dir/subdir",
					result_root
				)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/untracked_dir/file1.lua",
					result_root
				)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/untracked_dir/subdir/nested.lua",
					result_root
				)
			)
		end)

		it("should handle deeply nested untracked structure", function()
			helpers.create_directory(repo_dir, "deep/nested/path/here")
			helpers.create_file(
				repo_dir,
				"deep/nested/path/here/file.lua",
				"content"
			)

			local done = false
			local result_trie, result_root

			git.get_status_async(repo_dir, function(_status, status_trie, root)
				result_trie = status_trie
				result_root = root
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.equals(
				"??",
				trie.lookup(result_trie, repo_dir .. "/deep", result_root)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/deep/nested",
					result_root
				)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/deep/nested/path/here",
					result_root
				)
			)
			assert.equals(
				"??",
				trie.lookup(
					result_trie,
					repo_dir .. "/deep/nested/path/here/file.lua",
					result_root
				)
			)
		end)
	end)

	describe("ignored directory handling", function()
		local repo_dir
		local trie

		before_each(function()
			trie = require("oil-git.trie")
			repo_dir = helpers.create_temp_git_repo()
			helpers.create_gitignore(repo_dir, { "ignored_dir/" })
			helpers.stage_file(repo_dir, ".gitignore")
			helpers.commit(repo_dir, "add gitignore")
			helpers.create_directory(repo_dir, "ignored_dir")
			helpers.create_file(repo_dir, "ignored_dir/file1.lua", "content")
			helpers.create_directory(repo_dir, "ignored_dir/subdir")
			helpers.create_file(
				repo_dir,
				"ignored_dir/subdir/nested.lua",
				"content"
			)
		end)

		after_each(function()
			helpers.cleanup(repo_dir)
		end)

		it("should detect ignored directory via gitignore", function()
			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local found_ignored = false
			for key, value in pairs(result_status) do
				if key:match("ignored_dir") and value == "!!" then
					found_ignored = true
					break
				end
			end

			assert.is_true(found_ignored)
		end)

		it(
			"should build trie supporting nested lookups in ignored dirs",
			function()
				local done = false
				local result_trie, result_root

				git.get_status_async(
					repo_dir,
					function(_status, status_trie, root)
						result_trie = status_trie
						result_root = root
						done = true
					end
				)

				helpers.wait_for(function()
					return done
				end)

				assert.equals(
					"!!",
					trie.lookup(
						result_trie,
						repo_dir .. "/ignored_dir",
						result_root
					)
				)
				assert.equals(
					"!!",
					trie.lookup(
						result_trie,
						repo_dir .. "/ignored_dir/subdir",
						result_root
					)
				)
				assert.equals(
					"!!",
					trie.lookup(
						result_trie,
						repo_dir .. "/ignored_dir/file1.lua",
						result_root
					)
				)
			end
		)
	end)

	describe("copied file handling", function()
		it("should detect copied files", function()
			local repo_dir = helpers.create_temp_git_repo()

			helpers.create_and_commit_file(
				repo_dir,
				"original.lua",
				"-- original content"
			)

			vim.fn.system({
				"git",
				"-C",
				repo_dir,
				"cp",
				"original.lua",
				"copy.lua",
			})

			if vim.fn.filereadable(repo_dir .. "/copy.lua") == 0 then
				helpers.create_file(repo_dir, "copy.lua", "-- original content")
				helpers.stage_file(repo_dir, "copy.lua")
			end

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local copy_path = repo_dir .. "/copy.lua"
			if result_status[copy_path] then
				assert.is_true(
					result_status[copy_path]:match("^[CA]") ~= nil,
					"Expected copy or added status"
				)
			end

			helpers.cleanup(repo_dir)
		end)
	end)

	describe("edge cases", function()
		it("should handle files with special characters", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_file(
				repo_dir,
				"file-with_special.chars.lua",
				"-- content"
			)

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/file-with_special.chars.lua"
			assert.is_not_nil(result_status[file_path])
			assert.equals("??", result_status[file_path])

			helpers.cleanup(repo_dir)
		end)

		it("should handle very long file paths", function()
			local repo_dir = helpers.create_temp_git_repo()
			local deep_path = "a/b/c/d/e/f/g/h/i/j"
			helpers.create_directory(repo_dir, deep_path)
			helpers.create_file(
				repo_dir,
				deep_path .. "/deep_file.lua",
				"-- content"
			)

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local found = false
			for path, _ in pairs(result_status) do
				if path:match("deep_file%.lua$") or path:match("/a$") then
					found = true
					break
				end
			end
			assert.is_true(found)

			helpers.cleanup(repo_dir)
		end)

		it("should handle multiple rapid async calls", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_file(repo_dir, "file.lua", "-- content")

			local call_count = 0
			local results = {}

			for _ = 1, 5 do
				git.get_status_async(
					repo_dir,
					function(status, status_trie, root)
						call_count = call_count + 1
						table.insert(results, {
							status = status,
							trie = status_trie,
							root = root,
						})
					end
				)
			end

			helpers.wait_for(function()
				return call_count >= 5
			end, 5000)

			assert.equals(5, call_count)

			for _, result in ipairs(results) do
				assert.is_table(result.status)
			end

			helpers.cleanup(repo_dir)
		end)

		it("should handle switching between different repos", function()
			local repo_dir1 = helpers.create_temp_git_repo()
			local repo_dir2 = helpers.create_temp_git_repo()

			helpers.create_file(repo_dir1, "file1.lua", "-- repo1")
			helpers.create_file(repo_dir2, "file2.lua", "-- repo2")

			local results = {}
			local done_count = 0

			git.get_status_async(repo_dir1, function(status, _trie, root)
				results.repo1 = { status = status, root = root }
				done_count = done_count + 1
			end)

			git.get_status_async(repo_dir2, function(status, _trie, root)
				results.repo2 = { status = status, root = root }
				done_count = done_count + 1
			end)

			helpers.wait_for(function()
				return done_count >= 2
			end, 5000)

			assert.is_not_nil(results.repo1.status[repo_dir1 .. "/file1.lua"])
			assert.is_not_nil(results.repo2.status[repo_dir2 .. "/file2.lua"])

			assert.is_nil(results.repo1.status[repo_dir2 .. "/file2.lua"])
			assert.is_nil(results.repo2.status[repo_dir1 .. "/file1.lua"])

			helpers.cleanup(repo_dir1)
			helpers.cleanup(repo_dir2)
		end)

		it("should handle cache invalidation between repos", function()
			local repo_dir1 = helpers.create_temp_git_repo()
			local repo_dir2 = helpers.create_temp_git_repo()

			helpers.create_file(repo_dir1, "file1.lua", "-- repo1")

			local done = false
			local result1

			git.get_status_async(repo_dir1, function(status)
				result1 = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			git.invalidate_cache()
			done = false

			helpers.create_file(repo_dir2, "file2.lua", "-- repo2")

			local result2
			git.get_status_async(repo_dir2, function(status)
				result2 = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.is_not_nil(result1[repo_dir1 .. "/file1.lua"])
			assert.is_not_nil(result2[repo_dir2 .. "/file2.lua"])

			helpers.cleanup(repo_dir1)
			helpers.cleanup(repo_dir2)
		end)
	end)

	describe("conflict detection", function()
		it("should detect merge conflicts", function()
			local repo_dir = helpers.create_temp_git_repo()

			helpers.create_and_commit_file(repo_dir, "file.lua", "-- original")

			vim.fn.system({ "git", "-C", repo_dir, "checkout", "-b", "feature" })
			helpers.create_file(repo_dir, "file.lua", "-- feature change")
			helpers.stage_file(repo_dir, "file.lua")
			helpers.commit(repo_dir, "feature change")

			vim.fn.system({ "git", "-C", repo_dir, "checkout", "master" })
			helpers.create_file(repo_dir, "file.lua", "-- master change")
			helpers.stage_file(repo_dir, "file.lua")
			helpers.commit(repo_dir, "master change")

			vim.fn.system({ "git", "-C", repo_dir, "merge", "feature" })

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			local file_path = repo_dir .. "/file.lua"
			if result_status[file_path] then
				local status = result_status[file_path]
				local is_conflict = status:match("U") ~= nil
					or status == "AA"
					or status == "DD"
				local is_modified = status:match("[AMD]") ~= nil
				assert.is_true(
					is_conflict or is_modified,
					"Expected conflict or modified status, got: " .. status
				)
			end

			helpers.cleanup(repo_dir)
		end)
	end)

	describe("gitignore patterns", function()
		it("should handle wildcard patterns", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_gitignore(repo_dir, { "*.log", "*.tmp" })
			helpers.stage_file(repo_dir, ".gitignore")
			helpers.commit(repo_dir, "add gitignore")

			helpers.create_file(repo_dir, "debug.log", "log content")
			helpers.create_file(repo_dir, "cache.tmp", "tmp content")
			helpers.create_file(repo_dir, "script.lua", "lua content")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.equals("!!", result_status[repo_dir .. "/debug.log"])
			assert.equals("!!", result_status[repo_dir .. "/cache.tmp"])
			assert.equals("??", result_status[repo_dir .. "/script.lua"])

			helpers.cleanup(repo_dir)
		end)

		it("should handle negation patterns", function()
			local repo_dir = helpers.create_temp_git_repo()
			helpers.create_gitignore(repo_dir, { "*.log", "!important.log" })
			helpers.stage_file(repo_dir, ".gitignore")
			helpers.commit(repo_dir, "add gitignore")

			helpers.create_file(repo_dir, "debug.log", "log content")
			helpers.create_file(repo_dir, "important.log", "important content")

			local done = false
			local result_status

			git.get_status_async(repo_dir, function(status)
				result_status = status
				done = true
			end)

			helpers.wait_for(function()
				return done
			end)

			assert.equals("!!", result_status[repo_dir .. "/debug.log"])
			assert.equals("??", result_status[repo_dir .. "/important.log"])

			helpers.cleanup(repo_dir)
		end)
	end)

	describe("spawn failure handling", function()
		it("should handle non-existent directory gracefully", function()
			local done = false
			local result_status

			git.get_status_async(
				"/nonexistent/path/that/cannot/exist",
				function(status)
					result_status = status
					done = true
				end
			)

			helpers.wait_for(function()
				return done
			end, 2000)

			assert.same({}, result_status)
		end)
	end)

	describe("Windows compatibility", function()
		it("should normalize Windows-style paths from git output", function()
			local path_module = require("oil-git.path")
			local orig_is_windows = path_module.is_windows

			path_module.is_windows = true

			local git_output = "C:/Users/newholder/projects/my-repo"
			local normalized = path_module.git_to_os(git_output)

			assert.equals("C:\\Users\\newholder\\projects\\my-repo", normalized)

			path_module.is_windows = orig_is_windows
		end)

		it("should strip trailing newlines from git output", function()
			local test_cases = {
				{ input = "C:/Users/test\n", expected = "C:/Users/test" },
				{ input = "C:/Users/test\r\n", expected = "C:/Users/test" },
				{ input = "C:/Users/test\n\n", expected = "C:/Users/test" },
				{ input = "/home/user/repo\n", expected = "/home/user/repo" },
			}

			for _, tc in ipairs(test_cases) do
				local result = tc.input:gsub("[\r\n]+$", "")
				assert.equals(tc.expected, result)
			end
		end)

		it("should handle drive letter paths on mocked Windows", function()
			local path_module = require("oil-git.path")
			local orig_is_windows = path_module.is_windows

			path_module.is_windows = true

			local test_cases = {
				{
					input = "C:/Users/test/project",
					expected = "C:\\Users\\test\\project",
				},
				{
					input = "D:/Work/repos/my-app",
					expected = "D:\\Work\\repos\\my-app",
				},
				{
					input = "E:/",
					expected = "E:\\",
				},
			}

			for _, tc in ipairs(test_cases) do
				local result = path_module.git_to_os(tc.input)
				assert.equals(tc.expected, result)
			end

			path_module.is_windows = orig_is_windows
		end)

		it("should handle network paths on mocked Windows", function()
			local path_module = require("oil-git.path")
			local orig_is_windows = path_module.is_windows

			path_module.is_windows = true

			local result = path_module.git_to_os("//server/share/project")
			assert.equals("\\\\server\\share\\project", result)

			path_module.is_windows = orig_is_windows
		end)
	end)
end)
