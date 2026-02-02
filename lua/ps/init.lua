local M = {}

M.config = {
	ps_cmd = "ps aux",
	kill_cmd = "kill -9",
	regex_rule = [[\w\+\s\+\zs\d\+\ze]],
}

local state = {
	bufnr = nil,
	filter = nil,
	full_output = {},
	sort_by = nil, -- nil, "cpu", or "mem"
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	require("ps.syntax").setup()
	require("ps.lsof_syntax").setup()
end

local function get_pid_from_line(line)
	local match = vim.fn.matchstr(line, M.config.regex_rule)
	return match ~= "" and match or nil
end

local function kill_process(pid, silent)
	if not pid or pid == "" then
		if not silent then
			vim.notify("No valid PID found", vim.log.levels.ERROR)
		end
		return false
	end

	-- Check if process exists before attempting to kill
	local check_before = vim.fn.system("ps -p " .. pid .. " -o pid= 2>/dev/null")
	if vim.v.shell_error ~= 0 or check_before:match("^%s*$") then
		if not silent then
			vim.notify("Process " .. pid .. " does not exist", vim.log.levels.WARN)
		end
		return false
	end

	local cmd = M.config.kill_cmd .. " " .. pid
	vim.fn.system(cmd)
	
	if vim.v.shell_error ~= 0 then
		if not silent then
			vim.notify("ERROR: command execution failed: " .. cmd, vim.log.levels.ERROR)
		end
		return false
	end

	-- Wait a bit and verify the process is actually gone
	vim.defer_fn(function()
		local check_after = vim.fn.system("ps -p " .. pid .. " -o pid= 2>/dev/null")
		
		if vim.v.shell_error == 0 and not check_after:match("^%s*$") then
			-- Process still exists after kill attempt
			if not silent then
				vim.notify("WARNING: Process " .. pid .. " may still be running (kill signal sent but process persists)", vim.log.levels.WARN)
			end
		else
			if not silent then
				vim.notify("Process " .. pid .. " has been killed.", vim.log.levels.INFO)
			end
		end
	end, 100)
	
	return true
end

local function apply_filter(lines)
	if not state.filter or state.filter == "" then
		return lines
	end

	local filtered = {}
	for i, line in ipairs(lines) do
		if i == 1 or line:lower():find(state.filter:lower(), 1, true) then
			table.insert(filtered, line)
		end
	end
	return filtered
end

local function refresh()
	if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
		return
	end

	local current_line = vim.api.nvim_win_get_cursor(0)[1]

	local output = vim.fn.systemlist(M.config.ps_cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("ERROR: ps command failed", vim.log.levels.ERROR)
		return
	end

	-- Format the output with proper alignment and RSS in MB, VSZ in TB
	local formatted_output = {}
	for i, line in ipairs(output) do
		if i == 1 then
			-- Header line - update VSZ to VSZ(TB) and RSS to RSS(MB)
			local header = string.format(
				"%-15s %6s %5s %4s %11s %11s %4s %5s %8s %9s %s",
				"USER", "PID", "%CPU", "%MEM", "VSZ(TB)", "RSS(MB)", "TT", "STAT", "STARTED", "TIME", "COMMAND"
			)
			table.insert(formatted_output, header)
		else
			-- Data line - parse and reformat
			local parts = {}
			-- Parse fixed columns: USER, PID, %CPU, %MEM, VSZ, RSS, TT, STAT, STARTED, TIME
			for part in line:gmatch("%S+") do
				table.insert(parts, part)
				if #parts >= 11 then
					break
				end
			end
			
			-- Get the COMMAND (rest of the line after the first 10 fields)
			local command = line:match(string.rep("%S+%s+", 10) .. "(.*)")
			
			if #parts >= 10 then
				-- Convert VSZ from KB to TB
				local vsz_kb = tonumber(parts[5])
				local vsz_tb = vsz_kb and string.format("%.3f TB", vsz_kb / 1073741824) or parts[5]
				
				-- Convert RSS from KB to MB
				local rss_kb = tonumber(parts[6])
				local rss_mb = rss_kb and string.format("%.1f MB", rss_kb / 1024) or parts[6]
				
				-- Format with proper spacing
				local formatted = string.format(
					"%-15s %6s %5s %4s %11s %11s %4s %5s %8s %9s %s",
					parts[1],  -- USER
					parts[2],  -- PID
					parts[3],  -- %CPU
					parts[4],  -- %MEM
					vsz_tb,    -- VSZ (converted to TB)
					rss_mb,    -- RSS (converted to MB)
					parts[7],  -- TT
					parts[8],  -- STAT
					parts[9],  -- STARTED
					parts[10], -- TIME
					command or ""  -- COMMAND
				)
				table.insert(formatted_output, formatted)
			else
				table.insert(formatted_output, line)
			end
		end
	end
	output = formatted_output

	state.full_output = output
	
	-- Apply sorting if requested
	if state.sort_by then
		local header = table.remove(output, 1)
		
		if state.sort_by == "cpu" then
			table.sort(output, function(a, b)
				-- Extract %CPU value (3rd column)
				local cpu_a = tonumber(a:match("%S+%s+%S+%s+(%S+)")) or 0
				local cpu_b = tonumber(b:match("%S+%s+%S+%s+(%S+)")) or 0
				return cpu_a > cpu_b
			end)
		elseif state.sort_by == "mem" then
			table.sort(output, function(a, b)
				-- Extract RSS value (6th column, parse the number before " MB")
				local rss_a = tonumber(a:match("%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+([%d.]+)%s+MB")) or 0
				local rss_b = tonumber(b:match("%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+([%d.]+)%s+MB")) or 0
				return rss_a > rss_b
			end)
		end
		
		table.insert(output, 1, header)
	end
	
	local display_lines = apply_filter(output)

	vim.bo[state.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, display_lines)
	vim.bo[state.bufnr].modifiable = false

	local line_count = vim.api.nvim_buf_line_count(state.bufnr)
	if current_line <= line_count then
		vim.api.nvim_win_set_cursor(0, { current_line, 0 })
	end
end

local function kill_line()
	local line = vim.api.nvim_get_current_line()
	local pid = get_pid_from_line(line)

	kill_process(pid)
end

local function kill_selected_lines()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")

	local lines = vim.api.nvim_buf_get_lines(state.bufnr, start_line - 1, end_line, false)
	local killed_pids = {}

	for _, line in ipairs(lines) do
		local pid = get_pid_from_line(line)
		if pid and kill_process(pid, true) then
			table.insert(killed_pids, pid)
		end
	end

	if #killed_pids > 0 then
		vim.notify(
			"Killed " .. #killed_pids .. " process(es): " .. table.concat(killed_pids, ", "),
			vim.log.levels.INFO
		)
	else
		vim.notify("No processes were killed", vim.log.levels.WARN)
	end
end

local function kill_word()
	local word = vim.fn.expand("<cword>")
	kill_process(word)
end

local function open_proc_line()
	local line = vim.api.nvim_get_current_line()
	local pid = get_pid_from_line(line)

	if not pid or pid == "" then
		vim.notify("No valid PID found", vim.log.levels.ERROR)
		return
	end

	local proc_dir = "/proc/" .. pid
	if vim.fn.isdirectory(proc_dir) == 1 then
		vim.cmd("belowright vnew " .. proc_dir)
	else
		vim.notify("ERROR: " .. proc_dir .. " is not found", vim.log.levels.ERROR)
	end
end

local function set_filter()
	vim.ui.input({
		prompt = "Filter processes (empty to clear): ",
		default = state.filter or "",
	}, function(input)
		if input == nil then
			return
		end

		state.filter = input ~= "" and input or nil
		refresh()

		if state.filter then
			vim.notify("Filter applied: " .. state.filter, vim.log.levels.INFO)
		else
			vim.notify("Filter cleared", vim.log.levels.INFO)
		end
	end)
end

local function sort_by_cpu()
	state.sort_by = "cpu"
	refresh()
	vim.notify("Sorted by CPU usage (highest first)", vim.log.levels.INFO)
end

local function sort_by_mem()
	state.sort_by = "mem"
	refresh()
	vim.notify("Sorted by memory usage (highest first)", vim.log.levels.INFO)
end

local function inspect_process()
	local line = vim.api.nvim_get_current_line()
	local pid = get_pid_from_line(line)

	if not pid or pid == "" then
		vim.notify("No valid PID found", vim.log.levels.ERROR)
		return
	end

	-- Get various process information
	local ps_detail_cmd = "ps -p " .. pid .. " -o user,pid,%cpu,%mem,vsz,rss,tt,stat,start,time,command"
	local detail_output = vim.fn.systemlist(ps_detail_cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("ERROR: Failed to get process details for PID " .. pid, vim.log.levels.ERROR)
		return
	end
	
	-- Format the output with proper alignment and RSS in MB, VSZ in TB
	local formatted_output = {}
	for i, line in ipairs(detail_output) do
		if i == 1 then
			-- Header line - update VSZ to VSZ(TB) and RSS to RSS(MB)
			local header = string.format(
				"%-15s %6s %5s %4s %11s %11s %4s %5s %8s %9s %s",
				"USER", "PID", "%CPU", "%MEM", "VSZ(TB)", "RSS(MB)", "TT", "STAT", "STARTED", "TIME", "COMMAND"
			)
			table.insert(formatted_output, header)
		else
			-- Data line - parse and reformat
			local parts = {}
			local idx = 1
			-- Parse fixed columns: USER, PID, %CPU, %MEM, VSZ, RSS, TT, STAT, STARTED, TIME
			for part in line:gmatch("%S+") do
				table.insert(parts, part)
				idx = idx + 1
				if idx > 10 then
					break
				end
			end
			
			-- Get the COMMAND (rest of the line after the first 10 fields)
			local command = line:match(string.rep("%S+%s+", 10) .. "(.*)")
			
			if #parts >= 10 then
				-- Convert VSZ from KB to TB
				local vsz_kb = tonumber(parts[5])
				local vsz_tb = vsz_kb and string.format("%.3f TB", vsz_kb / 1073741824) or parts[5]
				
				-- Convert RSS from KB to MB
				local rss_kb = tonumber(parts[6])
				local rss_mb = rss_kb and string.format("%.1f MB", rss_kb / 1024) or parts[6]
				
				-- Format with proper spacing
				local formatted = string.format(
					"%-15s %6s %5s %4s %11s %11s %4s %5s %8s %9s %s",
					parts[1],  -- USER
					parts[2],  -- PID
					parts[3],  -- %CPU
					parts[4],  -- %MEM
					vsz_tb,    -- VSZ (converted to TB)
					rss_mb,    -- RSS (converted to MB)
					parts[7],  -- TT
					parts[8],  -- STAT
					parts[9],  -- STARTED
					parts[10], -- TIME
					command or ""  -- COMMAND
				)
				table.insert(formatted_output, formatted)
			else
				table.insert(formatted_output, line)
			end
		end
	end
	detail_output = formatted_output

	-- Get parent process info
	local parent_info = vim.fn.systemlist("ps -p " .. pid .. " -o ppid=,comm=")
	
	-- Get child processes (recursive)
	local all_child_pids = {}
	local function get_all_children(parent_pid)
		local direct_children = vim.fn.systemlist("pgrep -P " .. parent_pid .. " 2>/dev/null")
		for _, child in ipairs(direct_children) do
			if child ~= "" and tonumber(child) then
				table.insert(all_child_pids, child)
				get_all_children(child)  -- Recursive call for grandchildren
			end
		end
	end
	get_all_children(pid)
	
	-- Get network connections - filter by exact PID match using grep
	local network = {}
	if #all_child_pids > 0 then
		local pid_pattern = pid .. "|" .. table.concat(all_child_pids, "|")
		local network_cmd = "lsof -i -n -P 2>/dev/null | grep -E '^\\S+\\s+(" .. pid_pattern .. ")\\s'"
		network = vim.fn.systemlist(network_cmd)
	else
		-- Only main PID, simpler command
		local network_cmd = "lsof -i -n -P 2>/dev/null | grep -E '^\\S+\\s+" .. pid .. "\\s'"
		network = vim.fn.systemlist(network_cmd)
	end
	
	-- Get open files (limited to first 20)
	local open_files = vim.fn.systemlist("lsof -p " .. pid .. " 2>/dev/null | head -20")
	
	-- Get working directory
	local cwd_cmd = "lsof -a -p " .. pid .. " -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-"
	local cwd_output = vim.fn.systemlist(cwd_cmd)
	local cwd = cwd_output[1] or ""

	-- Create a new buffer for inspection
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "psdetail"
	
	-- Use unique buffer name with timestamp to avoid conflicts
	local buf_name = "Process Inspector - PID: " .. pid .. " [" .. os.time() .. "]"
	vim.api.nvim_buf_set_name(bufnr, buf_name)

	-- Build the content
	local content = {
		"╔═══════════════════════════════════════════════════════════════╗",
		"║              PROCESS INSPECTOR - PID: " .. pid .. string.rep(" ", 18 - #pid) .. "║",
		"╚═══════════════════════════════════════════════════════════════╝",
		"",
	}

	-- Basic info
	table.insert(content, "📊 BASIC INFORMATION")
	table.insert(content, "═══════════════════")
	for _, detail_line in ipairs(detail_output) do
		table.insert(content, detail_line)
	end
	table.insert(content, "")

	-- Working directory
	if cwd and cwd ~= "" then
		table.insert(content, "📁 WORKING DIRECTORY")
		table.insert(content, "═══════════════════")
		table.insert(content, cwd)
		table.insert(content, "")
	end

	-- Parent process
	if parent_info and #parent_info > 0 then
		table.insert(content, "⬆️  PARENT PROCESS")
		table.insert(content, "═══════════════════")
		for _, pinfo in ipairs(parent_info) do
			if pinfo ~= "" then
				table.insert(content, "PPID: " .. pinfo)
			end
		end
		table.insert(content, "")
	end

	-- Child processes
	if #all_child_pids > 0 then
		table.insert(content, "⬇️  CHILD PROCESSES (" .. #all_child_pids .. ")")
		table.insert(content, "═══════════════════")
		for _, child in ipairs(all_child_pids) do
			local child_info = vim.fn.systemlist("ps -p " .. child .. " -o pid,comm")
			for _, child_line in ipairs(child_info) do
				table.insert(content, child_line)
			end
		end
		table.insert(content, "")
	end

	-- Network connections
	if network and #network > 0 then
		table.insert(content, "🌐 NETWORK CONNECTIONS (this process + children)")
		table.insert(content, "═══════════════════")
		for i, net in ipairs(network) do
			if i <= 20 then
				table.insert(content, net)
			end
		end
		if #network > 20 then
			table.insert(content, "... and " .. (#network - 20) .. " more")
		end
		table.insert(content, "")
	else
		table.insert(content, "🌐 NETWORK CONNECTIONS")
		table.insert(content, "═══════════════════")
		table.insert(content, "(No network connections found)")
		table.insert(content, "")
	end

	-- Open files
	if open_files and #open_files > 1 then
		table.insert(content, "📄 OPEN FILES (first 20)")
		table.insert(content, "═══════════════════")
		for _, file in ipairs(open_files) do
			table.insert(content, file)
		end
		table.insert(content, "")
	end

	-- Actions
	table.insert(content, "⌨️  ACTIONS")
	table.insert(content, "═══════════════════")
	table.insert(content, "  K  - Kill this process")
	table.insert(content, "  r  - Refresh inspector")
	table.insert(content, "  q  - Close this window")
	table.insert(content, "")

	-- Set the content
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.bo[bufnr].modifiable = false

	-- Open the buffer in a new split
	vim.cmd("belowright vsplit")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.wo.wrap = true

	-- Set up keymaps for the inspection buffer
	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "K", function()
		if kill_process(pid) then
			vim.notify("Process " .. pid .. " killed. Closing inspector.", vim.log.levels.INFO)
			vim.defer_fn(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.cmd("close")
				end
			end, 500)
		end
	end, opts)
	vim.keymap.set("n", "r", function()
		vim.cmd("close")
		inspect_process()
	end, opts)
	vim.keymap.set("n", "q", "<cmd>q!<CR>", opts)
end

local function setup_buffer()
	local bufnr = vim.api.nvim_create_buf(false, true)
	state.bufnr = bufnr

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.api.nvim_buf_set_name(bufnr, "PS")
	vim.bo[bufnr].filetype = "ps"

	-- Apply syntax highlighting immediately
	vim.api.nvim_buf_call(bufnr, function()
		require("ps.syntax").apply()
	end)

	local opts = { noremap = true, silent = true, buffer = bufnr }

	vim.keymap.set("n", "r", refresh, opts)
	vim.keymap.set("n", "K", kill_line, opts)
	vim.keymap.set("v", "K", function()
		-- Get visual selection before exiting
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")

		-- Ensure start is before end
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		-- Exit visual mode first
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)

		-- Kill the processes
		local lines = vim.api.nvim_buf_get_lines(state.bufnr, start_line - 1, end_line, false)
		local killed_pids = {}

		for _, line in ipairs(lines) do
			local pid = get_pid_from_line(line)
			if pid and kill_process(pid, true) then
				table.insert(killed_pids, pid)
			end
		end

		if #killed_pids > 0 then
			vim.notify(
				"Killed " .. #killed_pids .. " process(es): " .. table.concat(killed_pids, ", "),
				vim.log.levels.INFO
			)
		else
			vim.notify("No processes were killed", vim.log.levels.WARN)
		end
	end, opts)
	vim.keymap.set("n", "I", inspect_process, opts)
	vim.keymap.set("n", "p", open_proc_line, opts)
	vim.keymap.set("n", "q", "<cmd>q!<CR>", opts)
	vim.keymap.set("n", "f", set_filter, opts)
	vim.keymap.set("n", "gC", sort_by_cpu, opts)
	vim.keymap.set("n", "gm", sort_by_mem, opts)

	return bufnr
end

function M.open()
	local bufnr = setup_buffer()
	vim.cmd("new")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.wo.wrap = false
	state.filter = nil
	state.sort_by = nil
	refresh()
end

function M.open_this_buffer()
	state.bufnr = vim.api.nvim_get_current_buf()
	setup_buffer()
	vim.wo.wrap = false
	state.filter = nil
	state.sort_by = nil
	refresh()
end

function M.refresh()
	refresh()
end

function M.kill_line()
	kill_line()
end

function M.kill_selected_lines()
	kill_selected_lines()
end

function M.kill_word()
	kill_word()
end

function M.open_proc_line()
	open_proc_line()
end

function M.set_filter()
	set_filter()
end

function M.inspect_process()
  inspect_process()
end

return M
