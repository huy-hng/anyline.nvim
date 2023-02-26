local M = {}

local opts = require('anyline.default_opts')
local autocmds = require('anyline.autocmds')

function M.setup(user_opts)
	vim.api.nvim_set_hl(0, 'AnyLine', { link = opts.highlight })
	vim.api.nvim_set_hl(0, 'AnyLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('AnyLine')
	autocmds.create()
end

--M.setup()

return M
