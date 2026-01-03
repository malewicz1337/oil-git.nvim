# oil-git.nvim

Git status integration for [oil.nvim](https://github.com/stevearc/oil.nvim) that shows git status by coloring file names and adding status symbols.

> [!IMPORTANT]
> This fork adds async git status, directory status highlighting, debouncing, and additional git status types (deleted, copied, conflict). Requires Neovim >= 0.10. The original synchronous version is at [benomahony/oil-git.nvim](https://github.com/benomahony/oil-git.nvim).

## Screenshot

![Screenshot](oil-git-screenshot.png)

## Features

- **File name highlighting** - Colors files based on git status
- **Directory status highlighting** - Shows aggregate status of directory contents
- **Status symbols** - Shows git symbols at end of lines (customizable per file/directory)
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
  highlight OilGitDeleted guifg=#ff0000
  highlight OilGitConflict guifg=#ff8800
  highlight OilGitUntracked guifg=#00ffff
  highlight OilGitIgnored guifg=#808080
]])
```

The plugin only sets default colors if highlight groups don't already exist.

## Configuration

```lua
require("oil-git").setup({
  debounce_ms = 50,  -- debounce time in milliseconds (default: 50)
  show_directory_status = true,  -- show git status for directories (default: true)
  symbols = {
    file = {
      added = "+",
      modified = "~",
      renamed = "->",
      deleted = "D",
      copied = "C",
      conflict = "!",
      untracked = "?",
      ignored = "o",
    },
    directory = {
      -- VS Code-style: directories show a dot instead of letters
      added = "*",
      modified = "*",
      renamed = "*",
      deleted = "*",
      copied = "*",
      conflict = "!",   
      untracked = "*",
      ignored = "o",
    },
  },
  highlights = {
    OilGitAdded = { fg = "#a6e3a1" },     -- green
    OilGitModified = { fg = "#f9e2af" },  -- yellow  
    OilGitRenamed = { fg = "#cba6f7" },   -- purple
    OilGitDeleted = { fg = "#f38ba8" },   -- red
    OilGitConflict = { fg = "#fab387" },  -- orange
    OilGitUntracked = { fg = "#89b4fa" }, -- blue
    OilGitIgnored = { fg = "#6c7086" },   -- gray
  }
})
```

## Git Status Display

### File Status

| Status | Symbol | Color | Description |
|--------|--------|-------|-------------|
| Added | **+** | Green | Staged new file |
| Modified | **~** | Yellow | Modified file (staged or unstaged) |
| Renamed | **->** | Purple | Renamed file |
| Deleted | **D** | Red | Deleted file (staged or unstaged) |
| Copied | **C** | Purple | Copied file |
| Conflict | **!** | Orange | Merge conflict |
| Untracked | **?** | Blue | New untracked file |
| Ignored | **o** | Gray | Ignored file |

### Directory Status

Directories display the "most significant" status among their contents. The symbol is a colored dot by default (VS Code-style), indicating the directory contains files with changes.

| Priority | Status | Description |
|----------|--------|-------------|
| 7 | Conflict | Highest - merge conflicts need immediate attention |
| 6 | Modified | Staged or unstaged changes |
| 5 | Deleted | Deleted files |
| 4 | Added | New staged files |
| 3 | Renamed/Copied | Renamed or copied files |
| 2 | Untracked | New untracked files |
| 1 | Ignored | Lowest - only shown if all contents are ignored |

**Example:** If a directory contains one modified file and one untracked file, the directory shows as "modified" (higher priority) with the corresponding color.

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

- Neovim >= 0.10
- [oil.nvim](https://github.com/stevearc/oil.nvim)
- Git

## License

This project is open source and available under the [MIT Licence](LICENSE).
