.PHONY: test test-coverage test-file lint format clean

TESTS_DIR := tests/plenary
MINIMAL_INIT := tests/minimal_init.lua

test:
	@nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory $(TESTS_DIR) {minimal_init='$(MINIMAL_INIT)', sequential=true}"

test-coverage:
	@nvim --headless -u $(MINIMAL_INIT) \
		-c "lua require('luacov').init('.luacov')" \
		-c "PlenaryBustedDirectory $(TESTS_DIR) {minimal_init='$(MINIMAL_INIT)', sequential=true}"
	@luacov
	@mkdir -p coverage
	@luacov-reporter-lcov -o coverage/lcov.info
	@echo "Coverage report generated at coverage/lcov.info"

test-file:
	@nvim --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedFile $(FILE)"

lint:
	@stylua --check lua/ tests/
	@echo "Linted lua/ and tests/"

format:
	@stylua lua/ tests/
	@echo "Formatted lua/ and tests/"

clean:
	@rm -rf luacov.stats.out luacov.report.out coverage/
	@echo "Cleaned coverage files"
