local M = {}
-- R('anyline.markager')
-- R('anyline.setter')
-- R('anyline.context')
-- R('anyline.animate')
-- R('anyline.animation_manager')
-- R('anyline.default_opts')
-- R('anyline.utils')

local opts = require('anyline.default_opts')
local cache = require('anyline.cache')
local markager = require('anyline.markager')
local setter = require('anyline.setter')
local context = require('anyline.context')
local Debounce = require('anyline.debounce')
local animate = require('anyline.animate')

function M.setup(user_opts)
	vim.api.nvim_set_hl(0, 'AnyLine', { link = opts.highlight })
	vim.api.nvim_set_hl(0, 'AnyLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('AnyLine')
	M.create_autocmds()
end

local function hard_refresh(data)
	local bufnr = data.buf

	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.current_ctx = nil
	context.show_context(bufnr)
end

local function update(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	setter.update_marks(bufnr)

	context.current_ctx = nil

	context.show_context(bufnr)
end

local show_animation = animate.from_cursor { 'AnyLine', 'AnyLineContext' }
local hide_animation = animate.to_cursor { 'AnyLineContext', 'AnyLine' }

local function update_context(data) context.update_context(data.buf, show_animation, hide_animation) end

--- start AnyLine autocmds
function M.create_autocmds()
	Augroup('AnyLine', {
		Autocmd('WinLeave', function(data)
			local ctx = context.get_context_info(data.buf)
			if not ctx then return end
			hide_animation(data.buf, ctx)
		end),
		Autocmd({ 'CursorMoved' }, Debounce(update_context, opts.debounce_time)),

		Autocmd({ 'TextChanged', 'TextChangedI' }, update),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'WinScrolled',
			'CompleteChanged',
			'BufWinEnter',
			'BufWritePost',
			'SessionLoadPost',
		}, hard_refresh),
	})
end

function M.delete_autocmds() DeleteAugroup('AnyLine') end
-- M.delete_autocmds()
-- M.setup()

return M
