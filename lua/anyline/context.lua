local M = {}

local cache = require('anyline.cache')
local markager = require('anyline.markager')
local utils = require('anyline.utils')
local ani_manager = require('anyline.animation_manager')

local function current_indentation(bufnr, line)
	-- FIX: doesn't check if return of get_cache is nil
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@alias context { startln: number, endln: number, column: number, bufnr: number, winid: number }

local function get_context_under_cursor(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local winid = vim.api.nvim_get_current_win()
	local cursor = vim.fn.getcurpos(winid)
	local line = cursor[2] - 1
	local column = cursor[5] - 1

	local prev = 0

	local ranges = cache.buffer_caches[bufnr].line_ranges

	local indents = utils.reverse_array(vim.tbl_keys(ranges))

	local found_indent
	for _, col in ipairs(indents) do
		if col == column or col < column then
			print(col)
			found_indent = col
			break
		end
	end
	print(found_indent)
	if not found_indent then return end

	for _, range in ipairs(ranges[found_indent]) do
		-- P(range)
		-- print(column, col)
		-- if col == column or col < column then return col end
	end
end
-- local i = get_context_under_cursor()
-- print(i)

local function find_range(bufnr, cursor, column)
	local ranges = cache.buffer_caches[bufnr].line_ranges[column]
	if not ranges then return end

	for _, line_pair in ipairs(ranges) do
		local startln, endln = unpack(line_pair)
		if cursor >= startln and cursor <= endln then --
			return startln, endln
		end
	end
end

---@return context | nil
function M.get_context_info(bufnr)
	local winid = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(winid)[1] - 1

	local column = current_indentation(bufnr, cursor)
	local next = current_indentation(bufnr, cursor + 1)

	if not column and not next then return end

	-- include context when cursor is on start of context (not inside indentation yet)
	if next > column then
		column = next
		cursor = cursor + 1
	end

	column = column - utils.get_scroll_offset()
	if column < 0 then return end

	local ranges = cache.buffer_caches[bufnr].line_ranges[column]

	if not ranges then return end
	local startln, endln = find_range(bufnr, cursor, column)
	if startln then
		return {
			startln = startln,
			endln = endln,
			column = column,
			bufnr = bufnr,
			winid = winid,
		}
	end
end

---@param ctx1 context | nil
---@param ctx2 context | nil
function M.is_same_context(ctx1, ctx2)
	ctx2 = ctx2 or M.current_ctx
	if not ctx1 or not ctx2 then return end
	--stylua: ignore
	if ctx1.column  == ctx2.column and
	   ctx1.startln == ctx2.startln and
	   ctx1.endln   == ctx2.endln and
	   ctx1.bufnr   == ctx2.bufnr and
	   ctx1.winid   == ctx2.winid
	then return true end
end

local function set_context(bufnr, ctx)
	local marks = markager.context_range(bufnr, ctx.startln, ctx.endln, ctx.column)
	for _, mark in ipairs(marks) do
		markager.set_extmark(
			ctx.bufnr,
			mark.row,
			mark.column,
			'AnyLineContext',
			nil,
			{ priority = mark.opts.priority + 1, id = mark.id }
		)
	end
end

function M.hide_context(bufnr, ctx, animation)
	ctx = ctx or M.current_ctx

	animation = animation or set_context

	if ctx then
		ani_manager.cancel_animation(ctx)
		vim.schedule(function()
			local timers = animation(bufnr, ctx)
			ani_manager.add_animation(ctx, timers)
		end)
	end
end

function M.show_context(bufnr, ctx, animation)
	ctx = ctx or M.get_context_info(bufnr)
	if not ctx then return end

	animation = animation or set_context

	ani_manager.cancel_animation(ctx)

	vim.schedule(function()
		local timers = animation(bufnr, ctx)
		ani_manager.add_animation(ctx, timers)
	end)
end

function M.update_context(bufnr, show_animation, hide_animation)
	local ctx = M.get_context_info(bufnr)
	if M.is_same_context(ctx, M.current_ctx) then return end

	if
		M.current_ctx
		and not M.is_same_context(ctx, M.current_ctx)
		and M.current_ctx.winid == vim.api.nvim_get_current_win()
	then
		M.hide_context(bufnr, M.current_ctx, hide_animation)
	end

	M.current_ctx = ctx
	if not ctx then return end

	M.show_context(bufnr, ctx, show_animation)
end

return M
