local M = {}

local cache = require('indent_line.cache')
local markager = require('indent_line.markager')
local utils = require('indent_line.utils')

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@return { startln: number, endln: number, column: number } | nil
local function get_context_info(bufnr)

	local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
	-- local cursor_pos = vim.fn.getcurpos(0)
	-- local cursor_line = cursor_pos[2] - 1

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
			return { startln = startln, endln = endln, column = column }
		end
	end
end

local function same_context(new_context)
	if not M.current_ctx or not new_context then return end

	local column = M.current_ctx.column == new_context.column
	local startln = M.current_ctx.startln == new_context.startln
	local endln = M.current_ctx.endln == new_context.endln
	-- M.prev_context = new_context
	if column and startln and endln then return true end
end

local function set_context(bufnr, ctx, hl, char)
	local marks = markager.context_range(bufnr, ctx.startln, ctx.endln, ctx.column)
	for _, mark in ipairs(marks) do
		markager.set_extmark(
			bufnr,
			mark.row,
			mark.column,
			hl or 'IndentLineContext',
			char,
			{ priority = mark.opts.priority + 1, id = mark.id }
		)
	end
end

local function cancel_last_animation()
	if M.last_hide_animation then
		utils.cancel_timers(M.last_hide_animation)
		M.last_hide_animation = nil
	end
end

function M.hide_context(bufnr, animation)
	local ctx = get_context_info(bufnr)

	if M.current_ctx and not same_context(ctx) then --
		-- cancel_last_animation()
		local context_fn = animation and animation or set_context
		M.last_hide_animation = context_fn(bufnr, M.current_ctx, 'IndentLine')
		vim.schedule(function() --
		end)

		M.current_ctx = nil
	end
end

function M.show_context(bufnr, animation)
	local ctx = get_context_info(bufnr)

	if same_context(ctx) then return end

	M.current_ctx = ctx

	if not ctx then return end

	-- cancel_last_animation()

	if M.last_show_animation then utils.cancel_timers(M.last_show_animation) end
	local context_fn = animation and animation or set_context

	-- nvim.schedule(context_fn, bufnr, ctx, 'IndentLineContext')
	-- P('from show context', ctx)

	M.last_show_animation = context_fn(bufnr, ctx, 'IndentLineContext')
	vim.schedule(function() --
	end)
end

return M
