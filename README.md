# processmonitor.nvim

A Neovim plugin to view and manage processes from within Neovim.

## Features

- View process list output (`ps aux`) in a Neovim buffer
- View list of open files (`lsof`) in a Neovim buffer with syntax highlighting
- Kill processes directly from the buffer
- Kill multiple processes using visual selection
- Filter processes by name
- Sort processes by CPU or memory usage
- Refresh process list
- Open `/proc` filesystem for processes (Linux)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/processmonitor.nvim",
  config = function()
    require("ps").setup({
      -- Optional configuration
      ps_cmd = "ps aux",        -- Command to list processes
      kill_cmd = "kill -9",     -- Command to kill processes
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/processmonitor.nvim",
  config = function()
    require("ps").setup()
  end,
}
```

## Usage

### Commands

#### Process Management (ps)

| Command | Description |
| ------- | ----------- |
| `:PS` | Open a new buffer with process list |
| `:PsRefresh` | Refresh the process list |
| `:PsKillLine` | Kill the process on the current line |
| `:PsKillAllLines` | Kill all processes in the selected range |
| `:PsKillWord` | Kill the process with PID under cursor |
| `:PsInspect` | Open detailed inspector for current process |
| `:PsOpenProcLine` | Open `/proc` directory for the process |
| `:PsFilter` | Set a filter to show only matching processes |
| `:PsThisBuffer` | Convert current buffer to ps buffer |

#### Open Files Management (lsof)

| Command | Description |
| ------- | ----------- |
| `:Lsof` | Open a new buffer with list of open files |
| `:LsofRefresh` | Refresh the lsof output |
| `:LsofFilter` | Set a filter to show only matching entries |

### Default Keymaps

#### PS Buffer

When in a ps buffer:

##### Normal Mode

| Key | Action |
| --- | ------ |
| `r` | Refresh process list |
| `K` | Kill process on current line |
| `I` | Inspect process (detailed view) |
| `p` | Open `/proc` directory for process |
| `q` | Close buffer |
| `f` or `/` | Filter processes by name |
| `gC` | Sort by CPU usage (highest first) |
| `gm` | Sort by memory usage (highest first) |

##### Visual Mode

| Key | Action |
| --- | ------ |
| `K` | Kill all processes in selection |

#### LSOF Buffer

When in an lsof buffer:

##### Normal Mode

| Key | Action |
| --- | ------ |
| `r` | Refresh lsof output |
| `q` | Close buffer |
| `f` | Filter lsof output |

### Filtering

You can filter the process list by name:

1. Press `f` or `/` in the ps buffer
2. Enter a search term (e.g., "node" to see all Node.js processes)
3. Press Enter

To clear the filter:
1. Press `f` or `/`
2. Clear the input and press Enter

The filter is case-insensitive and searches across the entire process line.

### Sorting

You can sort the process list by different criteria:

- **Sort by CPU**: Press `gC` to sort processes by CPU usage (highest first)
- **Sort by Memory**: Press `gm` to sort processes by memory/RSS usage (highest first)

The sort order persists when you refresh the list with `r`. To return to the default order, close and reopen the buffer.

## Configuration

You can configure processmonitor.nvim by passing options to the setup function:

```lua
require("ps").setup({
  ps_cmd = "ps aux",           -- Command to list processes
  kill_cmd = "kill -9",        -- Command to kill processes (SIGKILL)
  regex_rule = [[\w\+\s\+\zs\d\+\ze]], -- Regex to extract PID from line
})
```

### Examples

To use a different kill signal:

```lua
require("ps").setup({
  kill_cmd = "kill -15",  -- Use SIGTERM instead of SIGKILL
})
```

To use a different ps command format:

```lua
require("ps").setup({
  ps_cmd = "ps axfu",  -- Show process tree
})
```

## Requirements

- Neovim 0.7+
- `ps` command (available on most Unix-like systems)
- `kill` command
- `lsof` command (for `:Lsof` functionality)

## License

MIT

## Credits

Based on [ps.vim](https://github.com/katonori/ps.vim) by katonori, reimplemented in Lua for Neovim with additional features.
