local M = {}
local utils = require('anyline.utils')
local cache = require('anyline.cache')
local setter = require('anyline.setter')
local context = require('anyline.context')
local animate = require('anyline.animate')
local opts = require('anyline.opts').opts
local markager = require('anyline.markager')
local Debounce = require('anyline.debounce')

local autocmd = vim.api.nvim_create_autocmd

local function skip_buffer(bufnr)
	-- TODO: include window types and other filters
	local ft = vim.bo[bufnr].filetype
	if not vim.tbl_contains(opts.ft_ignore, ft) then return true end
end

local function hard_refresh(data)
	local bufnr = data.buf

	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.show_context(bufnr)
end

local function update_lines(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	setter.update_marks(bufnr)

	context.show_context(bufnr)
end

local function update_context(data)
	context.update_context(data.buf, animate.show_animation, animate.hide_animation)
	-- FIX: this weird hack
	vim.defer_fn(function() --
		animate.last_cursor_pos = vim.api.nvim_win_get_cursor(0)[1] - 1
	end, 200)
end

local prev_scroll_offset = 0
local function window_scrolled(data)
	local offset = utils.get_scroll_offset()
	if offset == 0 and prev_scroll_offset == 0 then
		prev_scroll_offset = offset
		return
	end

	prev_scroll_offset = offset

	local bufnr = data.buf
	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)
	context.show_context(bufnr)
end

function M.delete() --
	pcall(vim.api.nvim_del_augroup_by_name, 'AnyLine')
end

function M.create()
	local context_updater = Debounce(update_context, opts.debounce_time)
	local group = vim.api.nvim_create_augroup('AnyLine', { clear = true })

	autocmd('WinLeave', {
		group = group,
		callback = function(data)
			local ctx = context.get_context_info(data.buf)
			if not ctx then return end
			animate.hide_animation(data.buf, ctx)
		end,
	})

	autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = group,
		callback = update_lines,
	})

	autocmd('CursorMoved', {
		group = group,
		callback = function(data) context_updater(data) end,
	})

	local win_scroller = Debounce(window_scrolled, 30)
	autocmd('WinScrolled', {
		group = group,
		callback = function(data) win_scroller(data) end,
	})

	autocmd({
		'FileChangedShellPost',
		'TextChanged',
		'TextChangedI',
		'CompleteChanged',
		'BufWinEnter',
		'BufWritePost',
		'SessionLoadPost',
	}, {
		group = group,
		callback = hard_refresh,
	})
end

-- M.delete()
-- M.create()

return M
