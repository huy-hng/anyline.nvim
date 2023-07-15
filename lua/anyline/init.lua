local M = {}

function M.setup(user_opts)
	vim.schedule(function()
		require('anyline.opts').parse_opts(user_opts or {})

		local opts = require('anyline.opts').opts
		vim.api.nvim_set_hl(0, 'AnyLine', { link = opts.highlight })
		vim.api.nvim_set_hl(0, 'AnyLineContext', { link = opts.context_highlight })
		vim.api.nvim_create_namespace('AnyLine')

		require('anyline.animate').create_animations(opts.animation)
		require('anyline.autocmds').delete()
		require('anyline.autocmds').create()
		M.refresh()
	end)
end

function M.refresh(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	require('anyline.cache').update_cache(bufnr)
	require('anyline.markager').remove_all_marks(bufnr)
	require('anyline.setter').set_marks(bufnr)
	require('anyline.context').show_context(bufnr)
end

function M.disable()
	require('anyline.cache').clear_cache()
	require('anyline.autocmds').delete()
	require('anyline.markager').remove_all_marks()
	require('anyline.opts').opts.enabled = false
end

function M.enable()
	require('anyline.autocmds').create()
	M.refresh()
	require('anyline.opts').opts.enabled = true
end

function M.toggle()
	if require('anyline.opts').opts.enabled then
		M.disable()
	else
		M.enable()
	end
end

return M
