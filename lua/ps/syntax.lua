-- ps.nvim syntax highlighting
-- Provides basic syntax highlighting for ps buffer

local M = {}

function M.apply()
  -- Match the header line (first line starting with USER)
  vim.cmd([[syntax match psHeader "^USER.*$"]])

  -- Match username at start of line
  vim.cmd([[syntax match psUser "^\S\+"]])

  -- Match PID (second column - numbers after username)
  vim.cmd([[syntax match psPID "\s\+\zs\d\+\ze\s"]])

  -- Match %CPU and %MEM (decimal numbers with %)
  vim.cmd([[syntax match psPercent "\s\+\zs\d\+\.\d\+\ze\s"]])

  -- Match VSZ (TB) - numbers with TB suffix
  vim.cmd([[syntax match psVSZ "\s\+\zs\d\+\.\d\+\s\+TB\ze\s"]])

  -- Match RSS (MB) - numbers with MB suffix
  vim.cmd([[syntax match psRSS "\s\+\zs\d\+\.\d\+\s\+MB\ze\s"]])

  -- Match process state (like Ss, R, S, etc.)
  vim.cmd([[syntax match psState "\s\+\zs[A-Z][a-z<+sN]*\ze\s"]])

  -- Match the TIME column (HH:MM.SS format)
  vim.cmd([[syntax match psTime "\s\+\zs\d\+:\d\+\.\d\+\ze\s"]])

  -- Match command (everything after TIME)
  vim.cmd([[syntax match psCommandPath "/[^ ]*"]])

  -- Link to standard highlight groups
  vim.cmd([[highlight default link psHeader Title]])
  vim.cmd([[highlight default link psUser String]])
  vim.cmd([[highlight default link psPID Number]])
  vim.cmd([[highlight default link psPercent Float]])
  vim.cmd([[highlight default link psVSZ Number]])
  vim.cmd([[highlight default link psRSS Number]])
  vim.cmd([[highlight default link psState Type]])
  vim.cmd([[highlight default link psTime Special]])
  vim.cmd([[highlight default link psCommandPath Identifier]])
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ps",
    callback = function()
      M.apply()
      vim.b.current_syntax = "ps"
    end,
  })
end

return M
