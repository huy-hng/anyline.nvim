local M = {}
R('indent_line.markager')
R('indent_line.setter')
R('indent_line.context')
R('indent_line.animate')
R('indent_line.default_opts')
R('indent_line.utils')

local opts = require('indent_line.default_opts')
local cache = require('indent_line.cache')
local markager = require('indent_line.markager')
local setter = require('indent_line.setter')
local context = require('indent_line.context')
local Debounce = require('indent_line.debounce')
local animate = require('indent_line.animate')

function M.setup(user_opts)
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('IndentLine')
	M.create_autocmds()
end

function M.refresh(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.current_ctx = nil
	context.show_context(bufnr)
end

function M.update(data)
	local bufnr = data.buf
	vim.schedule(function()
		cache.update_cache(bufnr)
		setter.update_marks(bufnr)
		context.current_ctx = nil
		context.show_context(bufnr)
	end)
end

--- start indentline autocmds
function M.create_autocmds()
	local debounce_time = 50
	local show_context = Debounce(context.show_context, debounce_time)
	local update_context = Debounce(context.update_context, debounce_time)
	local show_animation = animate.from_cursor { 'IndentLine', 'IndentLineContext' }
	local hide_animation = animate.to_cursor { 'IndentLineContext', 'IndentLine' }
	Augroup('IndentLine', {
		Autocmd('WinLeave', function(data) --
			context.hide_context(data.buf, hide_animation)
		end),
		Autocmd({ 'CursorMoved', 'WinEnter' }, function(data) --
			-- context.hide_context(data.buf, hide_animation)
			-- show_context(data.buf, show_animation)
			update_context(data.buf, show_animation, hide_animation)
		end),
		-- Autocmd({ 'TextChanged', 'TextChangedI' }, M.update),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'WinScrolled',
			'CompleteChanged',
			'BufWinEnter',
			'BufWritePost',
			'SessionLoadPost',
		}, M.refresh),

	})
end

function M.delete_autocmds() DeleteAugroup('IndentLine') end
-- M.delete_autocmds()
M.setup()

return M
