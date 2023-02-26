local M = {}
local cache = require('anyline.cache')
local setter = require('anyline.setter')
local context = require('anyline.context')
local animate = require('anyline.animate')
local opts = require('anyline.default_opts')
local markager = require('anyline.markager')
local Debounce = require('anyline.debounce')

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
function M.delete() vim.api.nvim_del_augroup_by_name('AnyLine') end

function M.create()
	local updater = Debounce(update_context, opts.debounce_time)
	local group = vim.api.nvim_create_augroup('AnyLine', { clear = true })

	vim.api.nvim_create_autocmd('WinLeave', {
		group = group,
		callback = function(data)
			local ctx = context.get_context_info(data.buf)
			if not ctx then return end
			hide_animation(data.buf, ctx)
		end,
	})

	vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = group,
		callback = update,
	})

	vim.api.nvim_create_autocmd('CursorMoved', {
		group = group,
		callback = function(data) updater(data) end,
	})

	vim.api.nvim_create_autocmd({
		'FileChangedShellPost',
		'TextChanged',
		'TextChangedI',
		'WinScrolled',
		'CompleteChanged',
		'BufWinEnter',
		'BufWritePost',
		'SessionLoadPost',
	}, {
		group = group,
		callback = hard_refresh,
	})
end

return M
