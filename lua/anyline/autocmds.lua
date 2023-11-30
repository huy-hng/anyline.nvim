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

local function bufnr_wrapper(fn)
	return function(data) fn(data.buf) end
end

local function skip_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return true end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count > opts.max_lines then return true end

	-- TODO: include window types and other filters
	local ft = vim.bo[bufnr].filetype
	if vim.tbl_contains(opts.ft_ignore, ft) then return true end
end

local function hard_refresh(bufnr)
	if skip_buffer(bufnr) then return end

	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.show_context(bufnr)
end

local function update_lines(bufnr)
	if skip_buffer(bufnr) then return end

	local bufnr = bufnr
	cache.update_cache(bufnr)
	setter.update_marks(bufnr)

	context.show_context(bufnr)
end

local function update_context(bufnr)
	if skip_buffer(bufnr) then return end

	context.update_context(bufnr, animate.show_animation, animate.hide_animation)
	-- FIX: this weird hack
	vim.defer_fn(function() --
		animate.last_cursor_pos = vim.api.nvim_win_get_cursor(0)[1] - 1
	end, 200)
end

local prev_scroll_offset = 0
local function window_scrolled(bufnr)
	if skip_buffer(bufnr) then return end

	local offset = utils.get_scroll_offset()
	if offset == 0 and prev_scroll_offset == 0 then
		prev_scroll_offset = offset
		return
	end

	prev_scroll_offset = offset

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)
	context.show_context(bufnr)
end

function M.stop()
	pcall(vim.api.nvim_del_augroup_by_name, 'AnyLine')
	local buffers = vim.api.nvim_list_bufs()

	for _, bufnr in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(bufnr) then markager.remove_all_marks(bufnr) end
	end
end

function M.start()
	local context_updater = Debounce(update_context, opts.debounce_time)
	local group = vim.api.nvim_create_augroup('AnyLine', { clear = true })

	-- vim.schedule(function()
	-- 	local buffers = vim.api.nvim_list_bufs()
	-- 	for _, bufnr in ipairs(buffers) do
	-- 		if vim.api.nvim_buf_is_valid(bufnr) then hard_refresh(bufnr) end
	-- 	end
	-- end)

	autocmd('ColorScheme', {
		group = group,
		callback = function()
			vim.api.nvim_set_hl(0, 'AnyLine', { link = opts.highlight })
			vim.api.nvim_set_hl(0, 'AnyLineContext', { link = opts.context_highlight })
		end,
	})
	autocmd('WinLeave', {
		group = group,
		callback = bufnr_wrapper(function(bufnr)
			if skip_buffer(bufnr) then return end
			local ctx = context.get_context_info(bufnr)
			if not ctx then return end
			animate.hide_animation(bufnr, ctx)
		end),
	})

	autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = group,
		callback = bufnr_wrapper(update_lines),
	})

	autocmd('CursorMoved', {
		group = group,
		callback = bufnr_wrapper(context_updater),
	})

	local win_scroller = Debounce(window_scrolled, 30)
	autocmd('WinScrolled', {
		group = group,
		callback = bufnr_wrapper(window_scrolled),
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
		callback = bufnr_wrapper(hard_refresh),
	})
end

-- M.delete()
-- M.create()

return M
