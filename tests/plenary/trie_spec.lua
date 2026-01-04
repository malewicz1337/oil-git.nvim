describe("trie", function()
	local trie

	before_each(function()
		package.loaded["oil-git.trie"] = nil
		package.loaded["oil-git.path"] = nil
		package.loaded["oil-git.status_mapper"] = nil
		package.loaded["oil-git.constants"] = nil
		trie = require("oil-git.trie")
	end)

	describe("create_node", function()
		it("should create node with correct structure", function()
			local node = trie.create_node()
			assert.is_table(node)
			assert.is_table(node.children)
			assert.same({}, node.children)
			assert.is_nil(node.status)
			assert.equals(0, node.priority)
		end)

		it("should create independent nodes", function()
			local node1 = trie.create_node()
			local node2 = trie.create_node()
			node1.priority = 5
			node1.status = "M "
			node1.children["foo"] = trie.create_node()

			assert.equals(0, node2.priority)
			assert.is_nil(node2.status)
			assert.same({}, node2.children)
		end)
	end)

	describe("insert", function()
		it("should create path nodes for single file", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			assert.is_not_nil(root.children["src"])
			assert.is_not_nil(root.children["src"].children["file.lua"])
		end)

		it("should set status on intermediate directories", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			assert.equals("M ", root.children["src"].status)
			assert.equals(6, root.children["src"].priority) -- MODIFIED = 6
		end)

		it("should update status with higher priority", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/a.lua", "??", git_root) -- UNTRACKED = 2
			trie.insert(root, "/repo/src/b.lua", "M ", git_root) -- MODIFIED = 6

			assert.equals("M ", root.children["src"].status)
			assert.equals(6, root.children["src"].priority)
		end)

		it("should not downgrade status with lower priority", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/a.lua", "M ", git_root) -- MODIFIED = 6
			trie.insert(root, "/repo/src/b.lua", "??", git_root) -- UNTRACKED = 2

			assert.equals("M ", root.children["src"].status)
			assert.equals(6, root.children["src"].priority)
		end)

		it("should handle deeply nested paths", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/a/b/c/d/file.lua", "A ", git_root)

			assert.is_not_nil(root.children["a"])
			assert.is_not_nil(root.children["a"].children["b"])
			assert.is_not_nil(root.children["a"].children["b"].children["c"])
			assert.is_not_nil(
				root.children["a"].children["b"].children["c"].children["d"]
			)
			assert.is_not_nil(
				root.children["a"].children["b"].children["c"].children["d"].children["file.lua"]
			)
		end)

		it("should propagate status up the tree", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/a/b/c/file.lua", "UU", git_root) -- CONFLICT = 7

			assert.equals(7, root.children["a"].priority)
			assert.equals(7, root.children["a"].children["b"].priority)
			assert.equals(
				7,
				root.children["a"].children["b"].children["c"].priority
			)
			assert.equals("UU", root.children["a"].status)
			assert.equals("UU", root.children["a"].children["b"].status)
		end)

		it("should ignore zero priority status codes", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "XX", git_root) -- unknown, priority 0

			-- Should not create any children for invalid status
			assert.same({}, root.children)
		end)

		it("should handle multiple files in same directory", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/a.lua", "A ", git_root) -- ADDED = 4
			trie.insert(root, "/repo/src/b.lua", "M ", git_root) -- MODIFIED = 6
			trie.insert(root, "/repo/src/c.lua", "??", git_root) -- UNTRACKED = 2

			-- Directory should have highest priority (modified)
			assert.equals("M ", root.children["src"].status)
			assert.equals(6, root.children["src"].priority)
		end)

		it("should handle files in different directories", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/file.lua", "A ", git_root)
			trie.insert(root, "/repo/tests/test.lua", "M ", git_root)

			assert.is_not_nil(root.children["src"])
			assert.is_not_nil(root.children["tests"])
			assert.equals("A ", root.children["src"].status)
			assert.equals("M ", root.children["tests"].status)
		end)

		it("should keep same status when priority is equal", function()
			local root = trie.create_node()
			local git_root = "/repo"

			-- Both RENAMED and COPIED have priority 3
			trie.insert(root, "/repo/src/a.lua", "R ", git_root)
			trie.insert(root, "/repo/src/b.lua", "C ", git_root)

			-- First one should remain since priorities are equal
			assert.equals("R ", root.children["src"].status)
			assert.equals(3, root.children["src"].priority)
		end)

		it("should handle root-level files", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "M ", git_root)

			assert.is_not_nil(root.children["file.lua"])
			assert.equals("M ", root.children["file.lua"].status)
		end)
	end)

	describe("lookup", function()
		it("should return nil for nil root", function()
			local result = trie.lookup(nil, "/repo/src", "/repo")
			assert.is_nil(result)
		end)

		it("should return nil for nil git_root", function()
			local root = trie.create_node()
			local result = trie.lookup(root, "/repo/src", nil)
			assert.is_nil(result)
		end)

		it("should return nil for non-existent path", function()
			local root = trie.create_node()
			local result = trie.lookup(root, "/repo/nonexistent", "/repo")
			assert.is_nil(result)
		end)

		it("should find existing directory status", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			local result = trie.lookup(root, "/repo/src", git_root)
			assert.equals("M ", result)
		end)

		it("should handle trailing forward slash in lookup path", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			local result = trie.lookup(root, "/repo/src/", git_root)
			assert.equals("M ", result)
		end)

		it("should handle trailing backslash in lookup path", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			local result = trie.lookup(root, "/repo/src\\", git_root)
			assert.equals("M ", result)
		end)

		it("should return nil for partial path match", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/deep/file.lua", "M ", git_root)

			-- "sr" is not a valid directory
			local result = trie.lookup(root, "/repo/sr", git_root)
			assert.is_nil(result)
		end)

		it("should return status for intermediate directories", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/a/b/c/file.lua", "UU", git_root)

			assert.equals("UU", trie.lookup(root, "/repo/a", git_root))
			assert.equals("UU", trie.lookup(root, "/repo/a/b", git_root))
			assert.equals("UU", trie.lookup(root, "/repo/a/b/c", git_root))
		end)

		it("should return status for file path", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "A ", git_root)

			-- Looking up the file itself
			local result = trie.lookup(root, "/repo/src/file.lua", git_root)
			assert.equals("A ", result)
		end)

		it("should return nil for empty path relative to git_root", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "M ", git_root)

			-- Looking up the git root itself
			local result = trie.lookup(root, "/repo", git_root)
			assert.is_nil(result)
		end)

		it("should handle complex directory hierarchies", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/components/Button.tsx", "M ", git_root)
			trie.insert(root, "/repo/src/components/Input.tsx", "A ", git_root)
			trie.insert(root, "/repo/src/utils/helpers.ts", "??", git_root)
			trie.insert(root, "/repo/tests/unit/test.ts", "UU", git_root)

			-- components should have MODIFIED priority (6 > 4)
			assert.equals(
				"M ",
				trie.lookup(root, "/repo/src/components", git_root)
			)

			-- utils should have UNTRACKED
			assert.equals("??", trie.lookup(root, "/repo/src/utils", git_root))

			-- tests should have CONFLICT
			assert.equals("UU", trie.lookup(root, "/repo/tests", git_root))

			-- src should have MODIFIED (highest among children)
			assert.equals("M ", trie.lookup(root, "/repo/src", git_root))
		end)
	end)

	describe("untracked status inheritance", function()
		it("should inherit untracked status for nested directories", function()
			local root = trie.create_node()
			local git_root = "/repo"
			-- Git reports only top-level untracked dir
			trie.insert(root, "/repo/untracked_dir/", "??", git_root)

			-- Nested paths should inherit untracked status
			assert.equals(
				"??",
				trie.lookup(root, "/repo/untracked_dir", git_root)
			)
			assert.equals(
				"??",
				trie.lookup(root, "/repo/untracked_dir/subdir", git_root)
			)
			assert.equals(
				"??",
				trie.lookup(root, "/repo/untracked_dir/subdir/deep", git_root)
			)
		end)

		it(
			"should inherit untracked status for files in untracked directories",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/untracked_dir/", "??", git_root)

				assert.equals(
					"??",
					trie.lookup(root, "/repo/untracked_dir/file.txt", git_root)
				)
				assert.equals(
					"??",
					trie.lookup(
						root,
						"/repo/untracked_dir/sub/file.txt",
						git_root
					)
				)
			end
		)

		it("should inherit ignored status for nested paths", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/ignored_dir/", "!!", git_root)

			assert.equals(
				"!!",
				trie.lookup(root, "/repo/ignored_dir/subdir", git_root)
			)
			assert.equals(
				"!!",
				trie.lookup(root, "/repo/ignored_dir/file.txt", git_root)
			)
		end)

		it("should not inherit non-untracked status", function()
			local root = trie.create_node()
			local git_root = "/repo"
			-- Modified directory (has tracked files with changes)
			trie.insert(root, "/repo/src/file.lua", "M ", git_root)

			-- src/ has modified status, but non-existent paths should return nil
			assert.equals("M ", trie.lookup(root, "/repo/src", git_root))
			assert.is_nil(trie.lookup(root, "/repo/src/nonexistent", git_root))
		end)

		it("should return exact status when path exists in trie", function()
			local root = trie.create_node()
			local git_root = "/repo"
			-- Only untracked directory (realistic: git doesn't report contents of untracked dirs)
			trie.insert(root, "/repo/untracked_dir/", "??", git_root)

			-- The directory has untracked status
			assert.equals(
				"??",
				trie.lookup(root, "/repo/untracked_dir", git_root)
			)
			-- Files inside should inherit untracked status
			assert.equals(
				"??",
				trie.lookup(root, "/repo/untracked_dir/file.lua", git_root)
			)
			-- Nested dirs should also inherit
			assert.equals(
				"??",
				trie.lookup(
					root,
					"/repo/untracked_dir/nested/deep.lua",
					git_root
				)
			)
		end)
	end)

	describe("path validation edge cases", function()
		it("should handle filepath shorter than git_root", function()
			local root = trie.create_node()
			-- Should not error, just silently return
			assert.has_no.errors(function()
				trie.insert(root, "/repo", "M ", "/repo/longer/path")
			end)
			assert.same({}, root.children)
		end)

		it("should handle filepath not starting with git_root", function()
			local root = trie.create_node()
			assert.has_no.errors(function()
				trie.insert(root, "/other/path/file.lua", "M ", "/repo")
			end)
			assert.same({}, root.children)
		end)

		it("should handle nil filepath in insert", function()
			local root = trie.create_node()
			assert.has_no.errors(function()
				trie.insert(root, nil, "M ", "/repo")
			end)
			assert.same({}, root.children)
		end)

		it("should handle nil git_root in insert", function()
			local root = trie.create_node()
			assert.has_no.errors(function()
				trie.insert(root, "/repo/file.lua", "M ", nil)
			end)
			assert.same({}, root.children)
		end)

		it(
			"should return nil for filepath not in git_root on lookup",
			function()
				local root = trie.create_node()
				trie.insert(root, "/repo/file.lua", "M ", "/repo")
				local result = trie.lookup(root, "/other/path", "/repo")
				assert.is_nil(result)
			end
		)

		it("should handle filepath equal to git_root", function()
			local root = trie.create_node()
			assert.has_no.errors(function()
				trie.insert(root, "/repo", "M ", "/repo")
			end)
			assert.same({}, root.children)
		end)

		it(
			"should handle lookup with filepath shorter than git_root",
			function()
				local root = trie.create_node()
				trie.insert(root, "/repo/file.lua", "M ", "/repo")
				local result = trie.lookup(root, "/re", "/repo")
				assert.is_nil(result)
			end
		)
	end)

	describe("trailing slash normalization", function()
		it("should handle filepath with trailing slash", function()
			local root = trie.create_node()
			trie.insert(root, "/repo/untracked_dir/", "??", "/repo")

			assert.is_not_nil(root.children["untracked_dir"])
			assert.equals("??", root.children["untracked_dir"].status)
		end)

		it("should handle git_root with trailing slash in insert", function()
			local root = trie.create_node()
			trie.insert(root, "/repo/src/file.lua", "M ", "/repo/")

			assert.is_not_nil(root.children["src"])
			assert.equals("M ", root.children["src"].status)
		end)

		it(
			"should handle mismatched trailing slashes between insert and lookup",
			function()
				local root = trie.create_node()
				trie.insert(root, "/repo/dir/", "??", "/repo/")

				local result = trie.lookup(root, "/repo/dir", "/repo")
				assert.equals("??", result)
			end
		)
	end)
end)
