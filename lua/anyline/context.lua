local M = {}

local cache = require('anyline.cache')
local markager = require('anyline.markager')
local utils = require('anyline.utils')

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@return { startln: number, endln: number, column: number, bufnr: number } | nil
local function get_context_info(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1

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

	for _, line_pair in ipairs(ranges) do
		local startln = line_pair[1]
		local endln = line_pair[2]

		if cursor >= startln and cursor <= endln then --
			-- print(startln, cursor, endln)
			-- print('returning')
			return { startln = startln, endln = endln, column = column, bufnr = bufnr }
		end
	end
end

local function is_same_context(context1, context2)
	context2 = context2 or M.current_ctx
	if not context1 or not context2 then return end

	local column = context1.column == context2.column
	local startln = context1.startln == context2.startln
	local endln = context1.endln == context2.endln
	if column and startln and endln then return true end
end

local function set_context(bufnr, ctx, hl, char)
	local marks = markager.context_range(bufnr, ctx.startln, ctx.endln, ctx.column)
	for _, mark in ipairs(marks) do
		markager.set_extmark(
			bufnr,
			mark.row,
			mark.column,
			hl or 'AnyLineContext',
			char,
			{ priority = mark.opts.priority + 1, id = mark.id }
		)
	end
end

function M.remove_running_animations()
	if M.last_show_animation then utils.cancel_timers(M.last_show_animation) end
	if M.last_hide_animation then utils.cancel_timers(M.last_hide_animation) end
end

function M.hide_context(bufnr, ctx, animation)
	ctx = ctx or M.current_ctx
	if ctx then
		M.last_hide_animation = animation(bufnr, ctx, 'AnyLine')
	end
end

function M.show_context(bufnr, ctx, animation)
	if not ctx then return end
	-- if M.last_show_animation then utils.cancel_timers(M.last_show_animation) end
	M.last_show_animation = animation(bufnr, ctx, 'AnyLineContext')
end

function M.update_context(bufnr, show_animation, hide_animation)
	local ctx = get_context_info(bufnr)
	if is_same_context(ctx) then return end

	if M.current_ctx and not is_same_context(ctx) then --
		if bufnr == M.current_ctx.bufnr then M.remove_running_animations() end

		local context_fn = hide_animation and hide_animation or set_context
		M.last_hide_animation = context_fn(bufnr, M.current_ctx)
	end

	M.current_ctx = ctx

	if not ctx then return end

	local context_fn = show_animation and show_animation or set_context

	-- M.last_show_animation = context_fn(bufnr, ctx)
	M.show_context(bufnr, ctx, context_fn)
end

return M
