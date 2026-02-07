if vim.g.loaded_ps_nvim then
	return
end
vim.g.loaded_ps_nvim = 1

vim.api.nvim_create_user_command("PS", function()
	require("ps").open()
end, {})

vim.api.nvim_create_user_command("PsThisBuffer", function()
	require("ps").open_this_buffer()
end, {})

vim.api.nvim_create_user_command("PsRefresh", function()
	require("ps").refresh()
end, {})

vim.api.nvim_create_user_command("PsKillLine", function()
	require("ps").kill_line()
end, {})

vim.api.nvim_create_user_command("PsKillAllLines", function()
	require("ps").kill_selected_lines()
end, { range = true })

vim.api.nvim_create_user_command("PsKillWord", function()
	require("ps").kill_word()
end, {})

vim.api.nvim_create_user_command("PsOpenProcLine", function()
	require("ps").open_proc_line()
end, {})

vim.api.nvim_create_user_command("PsFilter", function()
	require("ps").set_filter()
end, {})

vim.api.nvim_create_user_command("PsInspect", function()
	require("ps").inspect_process()
end, {})

-- LSOF commands
vim.api.nvim_create_user_command("Lsof", function()
	require("ps.lsof").open()
end, {})

vim.api.nvim_create_user_command("LsofRefresh", function()
	require("ps.lsof").refresh()
end, {})

vim.api.nvim_create_user_command("LsofFilter", function()
	require("ps.lsof").set_filter()
end, {})
