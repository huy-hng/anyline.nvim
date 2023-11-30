local M = {}

-- TODO:
-- disable this plugin on a per buffer basis

local setup = vim.schedule_wrap(function(user_opts)
	require('anyline.opts').parse_opts(user_opts or {})

	local opts = require('anyline.opts').opts
	vim.api.nvim_set_hl(0, 'AnyLine', { link = opts.highlight })
	vim.api.nvim_set_hl(0, 'AnyLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('AnyLine')

	require('anyline.animate').create_animations(opts.animation)
	require('anyline.autocmds').stop()
	require('anyline.autocmds').start()

	vim.api.nvim_create_user_command('AnylineDisable', require('anyline.autocmds').stop, {})
	vim.api.nvim_create_user_command('AnylineEnable', require('anyline.autocmds').start, {})
end)

function M.setup(user_opts) --
	setup(user_opts)
end

return M
