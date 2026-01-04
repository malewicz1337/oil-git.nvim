# Contributing to oil-git.nvim

## Prerequisites

- Neovim >= 0.8
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [oil.nvim](https://github.com/stevearc/oil.nvim)
- Git

## Development Setup

```bash
git clone https://github.com/malewicz1337/oil-git.nvim.git
cd oil-git.nvim

make test
```

## Code Style

- **Indentation**: Tabs (not spaces)
- **Line length**: 80 characters
- **Quotes**: Double quotes preferred
- **Naming**: `snake_case` for functions/variables, `SCREAMING_SNAKE_CASE` for constants
- **Module pattern**: All files use `local M = {}` / `return M`
- **Imports**: All `require()` statements at top of file
- **Error handling**: Use `pcall()` for operations that may fail
- **Async**: Wrap Neovim API calls in `vim.schedule()` when in libuv callbacks

## Running Tests

```bash
make test              
make test-coverage    
make test-file FILE=tests/plenary/path_spec.lua  
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Ensure tests pass (`make test`)
5. Add tests for new functionality
6. Commit with clear message
7. Create PR

## PR Checklist

- [ ] Tests pass locally
- [ ] New functionality has tests
- [ ] Code follows style guidelines
- [ ] No breaking changes (or documented if necessary)
