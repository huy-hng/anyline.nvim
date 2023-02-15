local M = {}

local opts = require('indent_line.default_opts')
local cache = require('indent_line.cache')
local markager = R('indent_line.markager')
local setter = R('indent_line.setter')
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

	setter.prev_context = nil
	setter.context(data)
end

--- start indentline autocmds
function M.create_autocmds()
	local debounce_time = 10
	local update_context = Debounce(setter.context, debounce_time)
	Augroup('IndentLine', {
		-- Autocmd('WinLeave', ctx_man.remove_current_context),
		Autocmd({ 'CursorMoved' }, update_context),
		-- Autocmd({ 'CursorMoved', 'CursorMovedI' }, update_context),
		-- Autocmd('WinScrolled', update_lines),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			'WinEnter',
			'BufWritePost',
			'SessionLoadPost',
		}, M.refresh),
	})
end

function M.delete_autocmds() DeleteAugroup('IndentLine') end
M.setup()

return M
