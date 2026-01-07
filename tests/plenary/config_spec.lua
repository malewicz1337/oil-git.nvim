describe("config", function()
	local config

	before_each(function()
		package.loaded["oil-git.config"] = nil
		config = require("oil-git.config")
	end)

	describe("setup", function()
		it("should accept nil and empty opts", function()
			assert.has_no.errors(function()
				config.setup(nil)
			end)
			package.loaded["oil-git.config"] = nil
			config = require("oil-git.config")
			assert.has_no.errors(function()
				config.setup({})
			end)
		end)

		it("should merge user options with defaults", function()
			config.setup({ debounce_ms = 100 })
			local cfg = config.get()
			assert.equals(100, cfg.debounce_ms)
			assert.is_true(cfg.show_file_highlights)
		end)

		it("should override boolean and string defaults", function()
			config.setup({
				show_file_highlights = false,
				show_directory_highlights = false,
				show_file_symbols = false,
				show_directory_symbols = false,
				show_ignored_files = true,
				show_ignored_directories = true,
				symbol_position = "signcolumn",
			})
			local cfg = config.get()
			assert.is_false(cfg.show_file_highlights)
			assert.is_false(cfg.show_directory_highlights)
			assert.is_false(cfg.show_file_symbols)
			assert.is_false(cfg.show_directory_symbols)
			assert.is_true(cfg.show_ignored_files)
			assert.is_true(cfg.show_ignored_directories)
			assert.equals("signcolumn", cfg.symbol_position)
		end)

		it("should deep merge nested options", function()
			config.setup({
				symbols = {
					file = { added = "A" },
				},
				highlights = {
					OilGitAdded = { fg = "#ffffff" },
				},
			})
			local cfg = config.get()
			assert.equals("A", cfg.symbols.file.added)
			assert.equals("~", cfg.symbols.file.modified)
			assert.equals("*", cfg.symbols.directory.added)
			assert.equals("#ffffff", cfg.highlights.OilGitAdded.fg)
			assert.is_not_nil(cfg.highlights.OilGitModified)
		end)

		it("should handle debug option", function()
			config.setup({ debug = "verbose" })
			local cfg = config.get()
			assert.equals("verbose", cfg.debug)
		end)

		it("should handle ignore_gitsigns_update option", function()
			config.setup({ ignore_gitsigns_update = true })
			local cfg = config.get()
			assert.is_true(cfg.ignore_gitsigns_update)
		end)
	end)

	describe("get", function()
		it("should return readonly config", function()
			config.setup({})
			local cfg = config.get()
			assert.has_error(function()
				cfg.debounce_ms = 999
			end, "Attempt to modify read-only config")
		end)

		it("should make nested tables readonly", function()
			config.setup({})
			local cfg = config.get()
			assert.has_error(function()
				cfg.symbols.file.added = "X"
			end, "Attempt to modify read-only config")
			assert.has_error(function()
				cfg.highlights.OilGitAdded.fg = "#000000"
			end, "Attempt to modify read-only config")
		end)

		it("should return consistent values and handle nil keys", function()
			config.setup({ debounce_ms = 123 })
			local cfg1 = config.get()
			local cfg2 = config.get()
			assert.equals(cfg1.debounce_ms, cfg2.debounce_ms)
			assert.is_nil(cfg1.nonexistent_key)
		end)
	end)

	describe("ensure", function()
		it("should populate empty config with defaults", function()
			config.ensure()
			local cfg = config.get()
			assert.equals(50, cfg.debounce_ms)
			assert.is_true(cfg.show_file_symbols)
		end)

		it("should not overwrite existing config", function()
			config.setup({ debounce_ms = 200 })
			config.ensure()
			local cfg = config.get()
			assert.equals(200, cfg.debounce_ms)
		end)
	end)

	describe("default values", function()
		it("should have all required default values", function()
			config.setup({})
			local cfg = config.get()

			assert.equals(50, cfg.debounce_ms)
			assert.is_true(cfg.show_file_highlights)
			assert.is_true(cfg.show_directory_highlights)
			assert.is_true(cfg.show_file_symbols)
			assert.is_true(cfg.show_directory_symbols)
			assert.is_false(cfg.show_ignored_files)
			assert.is_false(cfg.show_ignored_directories)
			assert.equals("eol", cfg.symbol_position)
			assert.is_false(cfg.ignore_gitsigns_update)
			assert.is_false(cfg.debug)

			assert.is_table(cfg.symbols.file)
			assert.is_table(cfg.symbols.directory)
			assert.is_table(cfg.highlights)
		end)

		it("should have all file and directory symbols", function()
			config.setup({})
			local cfg = config.get()

			local expected_file = {
				added = "+",
				modified = "~",
				renamed = "->",
				deleted = "D",
				copied = "C",
				conflict = "!",
				untracked = "?",
				ignored = "o",
			}
			for k, v in pairs(expected_file) do
				assert.equals(v, cfg.symbols.file[k], "file." .. k)
			end

			assert.equals("*", cfg.symbols.directory.added)
			assert.equals("!", cfg.symbols.directory.conflict)
			assert.equals("o", cfg.symbols.directory.ignored)
		end)

		it("should have all highlight groups with valid fg colors", function()
			config.setup({})
			local cfg = config.get()

			local expected_groups = {
				"OilGitAdded",
				"OilGitModified",
				"OilGitRenamed",
				"OilGitDeleted",
				"OilGitCopied",
				"OilGitConflict",
				"OilGitUntracked",
				"OilGitIgnored",
			}
			for _, name in ipairs(expected_groups) do
				assert.is_table(cfg.highlights[name], name .. " missing")
				assert.matches(
					"^#%x%x%x%x%x%x$",
					cfg.highlights[name].fg,
					name .. " fg"
				)
			end
		end)
	end)
end)
