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
			assert.is_false(node.is_dir_ignored)
			assert.is_false(node.is_dir_untracked)
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

		it(
			"should set status only on leaf node, not intermediate directories",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/file.lua", "M ", git_root)

				assert.is_nil(root.children["src"].status)
				assert.equals(0, root.children["src"].priority)
				assert.equals(
					"M ",
					root.children["src"].children["file.lua"].status
				)
				assert.equals(
					6,
					root.children["src"].children["file.lua"].priority
				)
			end
		)

		it("should handle multiple files in same directory", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/a.lua", "A ", git_root) -- ADDED = 4
			trie.insert(root, "/repo/src/b.lua", "M ", git_root) -- MODIFIED = 6
			trie.insert(root, "/repo/src/c.lua", "??", git_root) -- UNTRACKED = 2

			assert.is_nil(root.children["src"].status)
			assert.equals("A ", root.children["src"].children["a.lua"].status)
			assert.equals("M ", root.children["src"].children["b.lua"].status)
			assert.equals("??", root.children["src"].children["c.lua"].status)
		end)

		it("should handle deeply nested paths", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/a/b/c/d/file.lua", "A ", git_root)

			assert.is_not_nil(root.children["a"])
			assert.is_not_nil(root.children["a"].children["b"])
			assert.is_not_nil(root.children["a"].children["b"].children["c"])
			local d_node =
				root.children["a"].children["b"].children["c"].children["d"]
			assert.is_not_nil(d_node)
			assert.is_not_nil(d_node.children["file.lua"])
			assert.equals("A ", d_node.children["file.lua"].status)
		end)

		it("should ignore zero priority status codes", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "XX", git_root) -- unknown, priority 0

			assert.same({}, root.children)
		end)

		it("should handle files in different directories", function()
			local root = trie.create_node()
			local git_root = "/repo"

			trie.insert(root, "/repo/src/file.lua", "A ", git_root)
			trie.insert(root, "/repo/tests/test.lua", "M ", git_root)

			assert.is_not_nil(root.children["src"])
			assert.is_not_nil(root.children["tests"])
			assert.equals(
				"A ",
				root.children["src"].children["file.lua"].status
			)
			assert.equals(
				"M ",
				root.children["tests"].children["test.lua"].status
			)
		end)

		it("should handle root-level files", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "M ", git_root)

			assert.is_not_nil(root.children["file.lua"])
			assert.equals("M ", root.children["file.lua"].status)
		end)

		it(
			"should mark directory as ignored when is_directory flag is true",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/node_modules", "!!", git_root, true)

				assert.is_true(root.children["node_modules"].is_dir_ignored)
			end
		)

		it("should not mark file as dir_ignored even with !! status", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/.DS_Store", "!!", git_root, false)

			assert.is_false(root.children[".DS_Store"].is_dir_ignored)
		end)

		it(
			"should mark directory as untracked when is_directory flag is true",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/new_dir", "??", git_root, true)

				assert.is_true(root.children["new_dir"].is_dir_untracked)
			end
		)

		it(
			"should not mark file as dir_untracked even with ?? status",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/new_file.lua", "??", git_root, false)

				assert.is_false(root.children["new_file.lua"].is_dir_untracked)
			end
		)
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

		it("should return status for file path", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/src/file.lua", "A ", git_root)

			local result = trie.lookup(root, "/repo/src/file.lua", git_root)
			assert.equals("A ", result)
		end)

		it(
			"should compute directory status from children (highest priority)",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/a.lua", "??", git_root) -- UNTRACKED = 2
				trie.insert(root, "/repo/src/b.lua", "M ", git_root) -- MODIFIED = 6

				local result = trie.lookup(root, "/repo/src", git_root)
				assert.equals("M ", result)
			end
		)

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

			local result = trie.lookup(root, "/repo/sr", git_root)
			assert.is_nil(result)
		end)

		it(
			"should compute status for intermediate directories from descendants",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/a/b/c/file.lua", "UU", git_root)

				assert.equals("UU", trie.lookup(root, "/repo/a", git_root))
				assert.equals("UU", trie.lookup(root, "/repo/a/b", git_root))
				assert.equals("UU", trie.lookup(root, "/repo/a/b/c", git_root))
			end
		)

		it("should return nil for empty path relative to git_root", function()
			local root = trie.create_node()
			local git_root = "/repo"
			trie.insert(root, "/repo/file.lua", "M ", git_root)

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

			assert.equals(
				"M ",
				trie.lookup(root, "/repo/src/components", git_root)
			)

			assert.equals("??", trie.lookup(root, "/repo/src/utils", git_root))

			assert.equals("UU", trie.lookup(root, "/repo/tests", git_root))

			assert.equals("M ", trie.lookup(root, "/repo/src", git_root))
		end)
	end)

	describe("exclude_ignored parameter", function()
		it(
			"should exclude ignored files when exclude_ignored is true",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/.DS_Store", "!!", git_root, false)

				local result =
					trie.lookup(root, "/repo/src/.DS_Store", git_root, true)
				assert.is_nil(result)

				result =
					trie.lookup(root, "/repo/src/.DS_Store", git_root, false)
				assert.equals("!!", result)
			end
		)

		it(
			"should exclude ignored status from directory when exclude_ignored",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/.DS_Store", "!!", git_root, false)
				trie.insert(root, "/repo/src/file.lua", "M ", git_root, false)

				local result = trie.lookup(root, "/repo/src", git_root, true)
				assert.equals("M ", result)
			end
		)

		it(
			"should return nil for directory with only ignored when exclude_ignored",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/.DS_Store", "!!", git_root, false)
				trie.insert(root, "/repo/src/.env", "!!", git_root, false)

				local result = trie.lookup(root, "/repo/src", git_root, true)
				assert.is_nil(result)

				result = trie.lookup(root, "/repo/src", git_root, false)
				assert.equals("!!", result)
			end
		)

		it(
			"should return ignored status when exclude_ignored is false",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/node_modules", "!!", git_root, true)

				local result =
					trie.lookup(root, "/repo/node_modules", git_root, false)
				assert.equals("!!", result)
			end
		)

		it(
			"should return nil for ignored directory when exclude_ignored is true",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/node_modules", "!!", git_root, true)

				local result =
					trie.lookup(root, "/repo/node_modules", git_root, true)
				assert.is_nil(result)
			end
		)
	end)

	describe("ignored directory inheritance", function()
		it(
			"should inherit ignored status for paths inside ignored directory",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/node_modules", "!!", git_root, true)

				assert.equals(
					"!!",
					trie.lookup(
						root,
						"/repo/node_modules/lodash",
						git_root,
						false
					)
				)
				assert.equals(
					"!!",
					trie.lookup(
						root,
						"/repo/node_modules/lodash/index.js",
						git_root,
						false
					)
				)
			end
		)

		it(
			"should return nil for ignored dir children when exclude_ignored",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/node_modules", "!!", git_root, true)

				assert.is_nil(
					trie.lookup(
						root,
						"/repo/node_modules/lodash",
						git_root,
						true
					)
				)
				assert.is_nil(
					trie.lookup(
						root,
						"/repo/node_modules/lodash/index.js",
						git_root,
						true
					)
				)
			end
		)

		it(
			"should NOT inherit ignored status from file to sibling paths",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/.DS_Store", "!!", git_root, false)

				assert.is_nil(
					trie.lookup(root, "/repo/src/file.lua", git_root, false)
				)
				assert.is_nil(
					trie.lookup(root, "/repo/src/subdir", git_root, false)
				)
			end
		)
	end)

	describe("untracked directory inheritance", function()
		it(
			"should inherit untracked status for paths inside untracked directory",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/untracked_dir", "??", git_root, true)

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
					trie.lookup(root, "/repo/untracked_dir/file.txt", git_root)
				)
			end
		)

		it(
			"should NOT inherit untracked status from file to sibling paths",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(
					root,
					"/repo/src/new_file.lua",
					"??",
					git_root,
					false
				)

				assert.equals("??", trie.lookup(root, "/repo/src", git_root))
				assert.is_nil(
					trie.lookup(root, "/repo/src/other_file.lua", git_root)
				)
			end
		)

		it(
			"should not inherit non-untracked status to non-existent paths",
			function()
				local root = trie.create_node()
				local git_root = "/repo"
				trie.insert(root, "/repo/src/file.lua", "M ", git_root)

				assert.equals("M ", trie.lookup(root, "/repo/src", git_root))
				assert.is_nil(
					trie.lookup(root, "/repo/src/nonexistent", git_root)
				)
			end
		)
	end)

	describe("path validation edge cases", function()
		it("should handle filepath shorter than git_root", function()
			local root = trie.create_node()
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
			assert.equals(
				"M ",
				root.children["src"].children["file.lua"].status
			)
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
