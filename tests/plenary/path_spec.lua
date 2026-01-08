describe("path", function()
	local path

	before_each(function()
		package.loaded["oil-git.path"] = nil
		path = require("oil-git.path")
	end)

	describe("platform detection", function()
		it("should have correct is_windows and sep values", function()
			assert.is_boolean(path.is_windows)
			assert.is_string(path.sep)
			assert.equals(1, #path.sep)

			if path.is_windows then
				assert.equals("\\", path.sep)
			else
				assert.equals("/", path.sep)
			end
		end)
	end)

	describe("split", function()
		it("should split paths by forward and back slashes", function()
			assert.same({ "foo", "bar", "baz" }, path.split("foo/bar/baz"))
			assert.same({ "foo", "bar", "baz" }, path.split("foo\\bar\\baz"))
			assert.same({ "foo", "bar", "baz" }, path.split("foo/bar\\baz"))
		end)

		it("should handle leading and trailing separators", function()
			assert.same({ "foo", "bar" }, path.split("/foo/bar"))
			assert.same({ "foo", "bar" }, path.split("foo/bar/"))
			assert.same({ "foo", "bar" }, path.split("/foo/bar/"))
		end)

		it("should handle edge cases", function()
			assert.same({}, path.split(""))
			assert.same({}, path.split("///"))
			assert.same({ "foo" }, path.split("foo"))
			assert.same(
				{ "a", "b", "c", "d", "e", "f", "g" },
				path.split("a/b/c/d/e/f/g")
			)
		end)

		it("should handle nil input", function()
			assert.same({}, path.split(nil))
		end)

		it("should handle special path components", function()
			assert.same({ "src", "file.lua" }, path.split("src/file.lua"))
			assert.same(
				{ "my folder", "my file.txt" },
				path.split("my folder/my file.txt")
			)
			assert.same(
				{ "C:", "Users", "test" },
				path.split("C:\\Users\\test")
			)
			assert.same(
				{ "home", ".config", "nvim" },
				path.split("/home/.config/nvim")
			)
			assert.same(
				{ "home", "..", "etc", "passwd" },
				path.split("/home/../etc/passwd")
			)
		end)
	end)

	describe("join", function()
		it("should join path segments with separator", function()
			local expected = "foo" .. path.sep .. "bar" .. path.sep .. "baz"
			assert.equals(expected, path.join("foo", "bar", "baz"))
		end)

		it("should handle edge cases", function()
			assert.equals("", path.join())
			assert.equals("foo", path.join("foo"))
			local expected = "foo" .. path.sep .. "bar"
			assert.equals(expected, path.join("foo", "bar"))
		end)
	end)

	describe("git_to_os", function()
		it("should convert git paths to OS-specific paths", function()
			if path.is_windows then
				assert.equals("foo\\bar\\baz", path.git_to_os("foo/bar/baz"))
				assert.equals(
					"\\home\\user\\project",
					path.git_to_os("/home/user/project")
				)
				assert.equals(
					".\\src\\file.lua",
					path.git_to_os("./src/file.lua")
				)
			else
				assert.equals("foo/bar/baz", path.git_to_os("foo/bar/baz"))
				assert.equals(
					"/home/user/project",
					path.git_to_os("/home/user/project")
				)
				assert.equals(
					"./src/file.lua",
					path.git_to_os("./src/file.lua")
				)
			end
		end)

		it("should handle edge cases", function()
			assert.equals("", path.git_to_os(""))
			assert.equals("file.txt", path.git_to_os("file.txt"))
		end)
	end)

	describe("git_to_os with mocked Windows", function()
		it("should convert forward slashes on mocked Windows", function()
			local orig_is_windows = path.is_windows

			path.is_windows = true
			local result = path.git_to_os("C:/Users/test/project")
			assert.equals("C:\\Users\\test\\project", result)

			path.is_windows = orig_is_windows
		end)

		it("should not convert on mocked Unix", function()
			local orig_is_windows = path.is_windows

			path.is_windows = false
			local result = path.git_to_os("C:/Users/test/project")
			assert.equals("C:/Users/test/project", result)

			path.is_windows = orig_is_windows
		end)

		it("should handle UNC paths on mocked Windows", function()
			local orig_is_windows = path.is_windows

			path.is_windows = true
			local result = path.git_to_os("//server/share/folder")
			assert.equals("\\\\server\\share\\folder", result)

			path.is_windows = orig_is_windows
		end)

		it("should handle mixed slashes on mocked Windows", function()
			local orig_is_windows = path.is_windows

			path.is_windows = true
			local result = path.git_to_os("C:/Users\\test/project")
			assert.equals("C:\\Users\\test\\project", result)

			path.is_windows = orig_is_windows
		end)

		it("should handle git rev-parse output on mocked Windows", function()
			local orig_is_windows = path.is_windows

			path.is_windows = true
			local git_output = "C:/Users/newholder/projects/my-repo"
			local normalized = path.git_to_os(git_output)
			assert.equals("C:\\Users\\newholder\\projects\\my-repo", normalized)

			path.is_windows = orig_is_windows
		end)
	end)

	describe("remove_trailing_slash", function()
		it("should remove trailing slashes", function()
			assert.equals("/repo/dir", path.remove_trailing_slash("/repo/dir/"))
			assert.equals(
				"/repo/dir",
				path.remove_trailing_slash("/repo/dir\\")
			)
			assert.equals(
				"/repo/dir",
				path.remove_trailing_slash("/repo/dir///")
			)
			assert.equals(
				"/repo/dir",
				path.remove_trailing_slash("/repo/dir/\\")
			)
		end)

		it("should handle edge cases", function()
			assert.equals("/repo/dir", path.remove_trailing_slash("/repo/dir"))
			assert.equals("", path.remove_trailing_slash(""))
			assert.equals("", path.remove_trailing_slash("/"))
			assert.equals("C:", path.remove_trailing_slash("C:\\"))
		end)

		it("should not modify internal slashes", function()
			assert.equals(
				"/repo/dir/subdir",
				path.remove_trailing_slash("/repo/dir/subdir")
			)
		end)
	end)
end)
