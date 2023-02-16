local M = {}
R('indent_line.markager')
R('indent_line.setter')

local opts = require('indent_line.default_opts')
local cache = require('indent_line.cache')
local markager = require('indent_line.markager')
local setter = require('indent_line.setter')
local context = require('indent_line.context')
local Debounce = require('indent_line.debounce')

function M.setup(user_opts)
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('IndentLine')
	M.create_autocmds()
	return
end

function M.refresh(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.prev_context = nil
	context.update(bufnr)
end

function M.update(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	setter.update_marks(bufnr)

	context.prev_context = nil
	context.update(bufnr)
end

M.update { buf = vim.api.nvim_get_current_buf() }

--- start indentline autocmds
function M.create_autocmds()
	local debounce_time = 50
	local update_context = Debounce(context.update, debounce_time)

	Augroup('IndentLine', {
		Autocmd('WinLeave', function(data) context.remove_context(data.buf) end),
		Autocmd({ 'CursorMoved' }, function(data) update_context(data.buf) end),
		Autocmd({
			'TextChanged',
			'TextChangedI',
		}, M.update),
		Autocmd({
			'FileChangedShellPost',
			-- 'TextChanged',
			-- 'TextChangedI',
			'WinScrolled',
			'WinEnter',
			'CompleteChanged',
			'BufWinEnter',
			'BufWritePost',
			'SessionLoadPost',
		}, M.refresh),
	})
end

function M.delete_autocmds() DeleteAugroup('IndentLine') end
M.setup()
-- M.delete_autocmds()

return M
