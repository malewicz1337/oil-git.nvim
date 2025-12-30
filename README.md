# oil-git.nvim

Git status integration for [oil.nvim](https://github.com/stevearc/oil.nvim) that shows git status by coloring file names and adding status symbols.

## Screenshot

![Screenshot](oil-git-screenshot.png)

## Features

- **File name highlighting** - Colors files based on git status
- **Status symbols** - Shows git symbols at end of lines
- **Real-time updates** - Automatically refreshes when git changes occur
- **Async & debounced** - Non-blocking git status with configurable debounce
- **LazyGit integration** - Updates instantly when closing LazyGit or other git tools

## Installation

### With LazyVim/lazy.nvim (No setup required!)

```lua
{
  "benomahony/oil-git.nvim",
  dependencies = { "stevearc/oil.nvim" },
}
```

### Optional configuration

```lua
{
  "benomahony/oil-git.nvim",
  dependencies = { "stevearc/oil.nvim" },
  opts = {
    highlights = {
      OilGitModified = { fg = "#ff0000" }, 
    }
  }
}
```

### With other plugin managers

```lua
use {
  "benomahony/oil-git.nvim",
  requires = { "stevearc/oil.nvim" },
}

Plug 'stevearc/oil.nvim'
Plug 'benomahony/oil-git.nvim'
```

## Colorscheme Integration

The plugin respects highlight groups defined in your colorscheme. Add these to your colorscheme or init.lua:

```lua
vim.cmd([[
  highlight OilGitAdded guifg=#00ff00
  highlight OilGitModified guifg=#ffff00  
  highlight OilGitRenamed guifg=#ff00ff
  highlight OilGitUntracked guifg=#00ffff
  highlight OilGitIgnored guifg=#808080
]])
```

The plugin only sets default colors if highlight groups don't already exist.

## Configuration

```lua
require("oil-git").setup({
  debounce_ms = 50,  -- debounce time in milliseconds (default: 50)
  highlights = {
    OilGitAdded = { fg = "#a6e3a1" },     -- green
    OilGitModified = { fg = "#f9e2af" },  -- yellow  
    OilGitRenamed = { fg = "#cba6f7" },   -- purple
    OilGitUntracked = { fg = "#89b4fa" }, -- blue
    OilGitIgnored = { fg = "#6c7086" },   -- gray
  }
})
```

## Git Status Display

| Status | Symbol | Color | Description |
|--------|---------|-------|-------------|
| Added | **+** | Green | Staged new file |
| Modified | **~** | Yellow | Modified file (staged or unstaged) |
| Renamed | **→** | Purple | Renamed file |
| Untracked | **?** | Blue | New untracked file |
| Ignored | **!** | Gray | Ignored file |

## Auto-refresh Triggers

The plugin automatically refreshes git status when:

- Entering an oil buffer
- Buffer content changes (file operations in oil)
- Focus returns to Neovim (after using external git tools)
- Window focus changes
- Terminal closes (LazyGit, fugitive, etc.)
- Git plugin events (GitSigns, Fugitive)

## Commands

- `:lua require("oil-git").refresh()` - Manually refresh git status

## Requirements

- Neovim >= 0.8
- [oil.nvim](https://github.com/stevearc/oil.nvim)
- Git

## Roadmap

- Directory status highlighting
- Additional git statuses (Deleted, Copied, Conflicts)

## License

This project is open source and available under the [MIT Licence](LICENSE).
