.PHONY: test test-file lint luacheck format check setup

TESTS_DIR := tests/plenary
MINIMAL_INIT := tests/minimal_init.lua

test:
	@nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory $(TESTS_DIR) {minimal_init='$(MINIMAL_INIT)', sequential=true}"

test-file:
	@nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedFile $(FILE)"

lint:
	@stylua --check lua/ tests/
	@echo "StyLua check passed"

luacheck:
	@luacheck lua/ tests/
	@echo "Luacheck passed"

format:
	@stylua lua/ tests/
	@echo "Formatted lua/ and tests/"

check: format luacheck test
	@echo "All checks passed"

setup:
	@git config core.hooksPath .githooks
	@echo "Git hooks configured to use .githooks/"

lf: format lint luacheck
