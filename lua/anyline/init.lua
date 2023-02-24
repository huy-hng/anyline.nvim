local M = {}
R('anyline.markager')
R('anyline.setter')
R('anyline.context')
R('anyline.animate')
R('anyline.default_opts')
R('anyline.utils')

local opts = require('anyline.default_opts')
local cache = require('anyline.cache')
local markager = require('anyline.markager')
local setter = require('anyline.setter')
local context = require('anyline.context')
local Debounce = require('anyline.debounce')
local animate = require('anyline.animate')

function M.setup(user_opts)
	Highlight(0, 'AnyLine', { link = opts.highlight })
	Highlight(0, 'AnyLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('AnyLine')
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

--- start AnyLine autocmds
function M.create_autocmds()
	local debounce_time = 50
	local show_context = Debounce(context.show_context, debounce_time)
	local update_context = Debounce(context.update_context, debounce_time)
	local show_animation = animate.from_cursor { 'AnyLine', 'AnyLineContext' }
	local hide_animation = animate.to_cursor { 'AnyLineContext', 'AnyLine' }
	Augroup('AnyLine', {
		Autocmd('WinLeave', function(data) --
			-- context.hide_context(data.buf, hide_animation)
			context.hide_context(data.buf, nil, hide_animation)
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

function M.delete_autocmds() DeleteAugroup('AnyLine') end
-- M.delete_autocmds()
M.setup()

return M
