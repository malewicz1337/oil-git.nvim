describe("status_mapper", function()
	local status_mapper
	local constants

	local test_symbols = {
		added = "+",
		modified = "~",
		renamed = "->",
		deleted = "D",
		copied = "C",
		conflict = "!",
		untracked = "?",
		ignored = "o",
	}

	before_each(function()
		package.loaded["oil-git.status_mapper"] = nil
		package.loaded["oil-git.constants"] = nil
		status_mapper = require("oil-git.status_mapper")
		constants = require("oil-git.constants")
	end)

	describe("map", function()
		describe("edge cases", function()
			it("should return nil for nil status_code", function()
				local hl, sym = status_mapper.map(nil, test_symbols)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for empty string", function()
				local hl, sym = status_mapper.map("", test_symbols)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for single character", function()
				local hl, sym = status_mapper.map("A", test_symbols)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for unknown status codes", function()
				local hl, sym = status_mapper.map("XX", test_symbols)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for status with only spaces", function()
				local hl, sym = status_mapper.map("  ", test_symbols)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for nil symbols", function()
				local hl, sym = status_mapper.map("M ", nil)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)

			it("should return nil for valid status but nil symbols", function()
				local hl, sym = status_mapper.map("??", nil)
				assert.is_nil(hl)
				assert.is_nil(sym)
			end)
		end)

		describe("special status codes", function()
			it("should map '??' to untracked", function()
				local hl, sym = status_mapper.map("??", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.UNTRACKED, hl)
				assert.equals("?", sym)
			end)

			it("should map '!!' to ignored", function()
				local hl, sym = status_mapper.map("!!", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.IGNORED, hl)
				assert.equals("o", sym)
			end)
		end)

		describe("conflict patterns", function()
			it("should map 'UU' to conflict", function()
				local hl, sym = status_mapper.map("UU", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'AA' to conflict", function()
				local hl, sym = status_mapper.map("AA", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'DD' to conflict", function()
				local hl, sym = status_mapper.map("DD", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'AU' to conflict", function()
				local hl, sym = status_mapper.map("AU", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'UA' to conflict", function()
				local hl, sym = status_mapper.map("UA", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'DU' to conflict", function()
				local hl, sym = status_mapper.map("DU", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should map 'UD' to conflict", function()
				local hl, sym = status_mapper.map("UD", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should detect 'U' in first position as conflict", function()
				local hl, sym = status_mapper.map("UM", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)

			it("should detect 'U' in second position as conflict", function()
				local hl, sym = status_mapper.map("MU", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)
		end)

		describe("index (staged) status - first character", function()
			it("should map 'A ' to added", function()
				local hl, sym = status_mapper.map("A ", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.ADDED, hl)
				assert.equals("+", sym)
			end)

			it("should map 'M ' to modified", function()
				local hl, sym = status_mapper.map("M ", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.MODIFIED, hl)
				assert.equals("~", sym)
			end)

			it("should map 'R ' to renamed", function()
				local hl, sym = status_mapper.map("R ", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.RENAMED, hl)
				assert.equals("->", sym)
			end)

			it("should map 'D ' to deleted", function()
				local hl, sym = status_mapper.map("D ", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.DELETED, hl)
				assert.equals("D", sym)
			end)

			it("should map 'C ' to copied", function()
				local hl, sym = status_mapper.map("C ", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.COPIED, hl)
				assert.equals("C", sym)
			end)
		end)

		describe("worktree status - second character", function()
			it("should map ' M' to modified", function()
				local hl, sym = status_mapper.map(" M", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.MODIFIED, hl)
				assert.equals("~", sym)
			end)

			it("should map ' D' to deleted", function()
				local hl, sym = status_mapper.map(" D", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.DELETED, hl)
				assert.equals("D", sym)
			end)
		end)

		describe("combined status codes", function()
			it("should prioritize index status for 'AM'", function()
				local hl, sym = status_mapper.map("AM", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.ADDED, hl)
				assert.equals("+", sym)
			end)

			it("should prioritize index status for 'MD'", function()
				local hl, sym = status_mapper.map("MD", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.MODIFIED, hl)
				assert.equals("~", sym)
			end)

			it("should prioritize index status for 'RM'", function()
				local hl, sym = status_mapper.map("RM", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.RENAMED, hl)
				assert.equals("->", sym)
			end)

			it("should prioritize conflict over index for 'AU'", function()
				local hl, sym = status_mapper.map("AU", test_symbols)
				assert.equals(constants.HIGHLIGHT_GROUPS.CONFLICT, hl)
				assert.equals("!", sym)
			end)
		end)
	end)

	describe("get_priority", function()
		describe("edge cases", function()
			it("should return NONE for nil", function()
				local priority = status_mapper.get_priority(nil)
				assert.equals(constants.PRIORITY.NONE, priority)
			end)

			it("should return NONE for empty string", function()
				local priority = status_mapper.get_priority("")
				assert.equals(constants.PRIORITY.NONE, priority)
			end)

			it("should return NONE for single character", function()
				local priority = status_mapper.get_priority("A")
				assert.equals(constants.PRIORITY.NONE, priority)
			end)

			it("should return NONE for unknown status", function()
				local priority = status_mapper.get_priority("XX")
				assert.equals(constants.PRIORITY.NONE, priority)
			end)

			it("should return NONE for spaces only", function()
				local priority = status_mapper.get_priority("  ")
				assert.equals(constants.PRIORITY.NONE, priority)
			end)
		end)

		describe("special statuses", function()
			it("should return UNTRACKED priority for '??'", function()
				local priority = status_mapper.get_priority("??")
				assert.equals(constants.PRIORITY.UNTRACKED, priority)
			end)

			it("should return IGNORED priority for '!!'", function()
				local priority = status_mapper.get_priority("!!")
				assert.equals(constants.PRIORITY.IGNORED, priority)
			end)
		end)

		describe("conflict statuses", function()
			it("should return CONFLICT priority for 'UU'", function()
				local priority = status_mapper.get_priority("UU")
				assert.equals(constants.PRIORITY.CONFLICT, priority)
			end)

			it("should return CONFLICT priority for 'AA'", function()
				local priority = status_mapper.get_priority("AA")
				assert.equals(constants.PRIORITY.CONFLICT, priority)
			end)

			it("should return CONFLICT priority for 'DD'", function()
				local priority = status_mapper.get_priority("DD")
				assert.equals(constants.PRIORITY.CONFLICT, priority)
			end)
		end)

		describe("index statuses", function()
			it("should return ADDED priority for 'A '", function()
				local priority = status_mapper.get_priority("A ")
				assert.equals(constants.PRIORITY.ADDED, priority)
			end)

			it("should return MODIFIED priority for 'M '", function()
				local priority = status_mapper.get_priority("M ")
				assert.equals(constants.PRIORITY.MODIFIED, priority)
			end)

			it("should return DELETED priority for 'D '", function()
				local priority = status_mapper.get_priority("D ")
				assert.equals(constants.PRIORITY.DELETED, priority)
			end)

			it("should return RENAMED priority for 'R '", function()
				local priority = status_mapper.get_priority("R ")
				assert.equals(constants.PRIORITY.RENAMED, priority)
			end)

			it("should return COPIED priority for 'C '", function()
				local priority = status_mapper.get_priority("C ")
				assert.equals(constants.PRIORITY.COPIED, priority)
			end)
		end)

		describe("worktree statuses", function()
			it("should return MODIFIED priority for ' M'", function()
				local priority = status_mapper.get_priority(" M")
				assert.equals(constants.PRIORITY.MODIFIED, priority)
			end)

			it("should return DELETED priority for ' D'", function()
				local priority = status_mapper.get_priority(" D")
				assert.equals(constants.PRIORITY.DELETED, priority)
			end)
		end)

		describe("combined statuses", function()
			it("should return index priority for 'AM'", function()
				local priority = status_mapper.get_priority("AM")
				assert.equals(constants.PRIORITY.ADDED, priority)
			end)

			it("should return CONFLICT priority for 'AU'", function()
				local priority = status_mapper.get_priority("AU")
				assert.equals(constants.PRIORITY.CONFLICT, priority)
			end)
		end)
	end)
end)
