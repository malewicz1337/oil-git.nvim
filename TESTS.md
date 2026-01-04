# Tests

## Quick Start

```bash
make test                
make test-coverage      
make test-file FILE=tests/plenary/path_spec.lua  
make clean               
```

## Test Structure

```
tests/
├── minimal_init.lua     
├── helpers/init.lua     
├── fixtures/.gitkeep    
└── plenary/             
    ├── path_spec.lua
    ├── status_mapper_spec.lua
    ├── trie_spec.lua
    ├── git_spec.lua
    ├── init_spec.lua
    └── highlights_spec.lua
```

## Adding Tests

1. Create `tests/plenary/<module>_spec.lua`
2. Use plenary busted-style syntax:

```lua
describe("module_name", function()
    local module
    local helpers = require("tests.helpers")

    before_each(function()
        helpers.reset_oil_git_modules()
        module = require("oil-git.module_name")
    end)

    describe("function_name", function()
        it("should do something", function()
            assert.equals(expected, module.function_name())
        end)
    end)
end)
```

## Test Helpers

```lua
local helpers = require("tests.helpers")

-- Git repository helpers
helpers.create_temp_git_repo()          
helpers.create_file(repo, "file.lua", "content")
helpers.stage_file(repo, "file.lua")
helpers.commit(repo, "message")
helpers.create_and_commit_file(repo, "file.lua", "content")
helpers.delete_file(repo, "file.lua")
helpers.rename_file(repo, "old.lua", "new.lua")
helpers.cleanup(repo)                  

-- Async helpers
helpers.wait_for(condition_fn, timeout_ms)
helpers.now()                         

-- Module helpers
helpers.reset_oil_git_modules()      
```

## Coverage

Coverage reports are generated with `make test-coverage`:

- `luacov.stats.out` - Raw stats
- `luacov.report.out` - Text report
- `coverage/lcov.info` - LCOV format (for CI)

