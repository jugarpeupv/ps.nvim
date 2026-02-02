# processmonitor.nvim - Feature Implementation

## Completed Features ✅

### Core Functionality
- ✅ Display `ps aux` output in a Neovim buffer
- ✅ Refresh process list with `r` key
- ✅ Kill single process from current line with `K`
- ✅ Inspect process (detailed view) with `I`
- ✅ Visual mode selection + `K` to kill multiple processes
- ✅ Filter processes by name with `f` or `/` key
- ✅ Sort processes by CPU usage with `gC` key
- ✅ Sort processes by memory usage with `gm` key
- ✅ Open `/proc` filesystem with `p` key
- ✅ Close buffer with `q` key

### Implementation Details
- Written in pure Lua for Neovim
- Based on ps.vim plugin architecture
- Uses vim.ui.input for filter prompts
- Case-insensitive filtering
- Sortable by CPU and memory usage
- Maintains cursor position after refresh
- Proper buffer management (nofile, noswap)
- Syntax highlighting for ps output with VSZ (TB) and RSS (MB) display

### Commands Available
- `:PS` - Open new process viewer buffer
- `:PsRefresh` - Refresh the process list
- `:PsKillLine` - Kill process on current line
- `:PsKillAllLines` - Kill selected processes (visual mode)
- `:PsKillWord` - Kill process by PID under cursor
- `:PsFilter` - Set process name filter
- `:PsOpenProcLine` - Open /proc directory
- `:PsThisBuffer` - Convert current buffer to ps buffer

### Configuration Options
```lua
require("ps").setup({
  ps_cmd = "ps aux",              -- Customize ps command
  kill_cmd = "kill -9",           -- Customize kill command
  regex_rule = [[\w\+\s\+\zs\d\+\ze]], -- PID extraction pattern
})
```

## File Structure
```
processmonitor.nvim/
├── lua/
│   └── ps/
│       ├── init.lua      # Main plugin logic
│       └── syntax.lua    # Syntax highlighting
├── plugin/
│   └── ps.lua           # Command definitions
├── README.md            # Documentation
├── LICENSE              # MIT License
└── example-config.lua   # Example configuration
```

## Key Improvements Over ps.vim
1. **Lua-based**: Native Neovim implementation
2. **Filtering**: Built-in process filtering by name
3. **Sorting**: Sort by CPU or memory usage
4. **Better UX**: Uses vim.ui.input for interactive prompts
5. **Modern API**: Uses Neovim's latest Lua APIs
6. **Syntax highlighting**: Enhanced visual feedback with VSZ/RSS formatting
7. **Documentation**: Comprehensive README with examples
