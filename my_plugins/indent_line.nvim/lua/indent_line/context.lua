local M = {}
local cache = require('indent_line.cache')
local def = require('indent_line.default_opts')
local markager = require('indent_line.markager')
local animate = require('indent_line.animate')
local colors = require('indent_line.colors')
local utils = require('indent_line.utils')

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@return { startln: number, endln: number, column: number } | nil
local function get_context_info(bufnr)
	local cursor_pos = vim.fn.getcurpos(0)
	local cursor_line = cursor_pos[2] - 1

	local column = current_indentation(bufnr, cursor_line)
	local next = current_indentation(bufnr, cursor_line + 1)

	if not column and not next then return end

	-- include context when cursor is on start of context (not inside indentation yet)
	if next > column then
		column = next
		cursor_line = cursor_line + 1
	end

	local ranges = cache.buffer_caches[bufnr].line_ranges[column]

	if not ranges then return end

	for _, line_pair in ipairs(ranges) do
		local startln = line_pair[1]
		local endln = line_pair[2]

		if cursor_line >= startln and cursor_line <= endln then --
			return { startln = startln, endln = endln, column = column }
		end
	end
end

local function same_context(new_context)
	if not M.prev_context or not new_context then return end

	local column = M.prev_context.column == new_context.column
	local startln = M.prev_context.startln == new_context.startln
	local endln = M.prev_context.endln == new_context.endln
	-- M.prev_context = new_context
	if column and startln and endln then return true end
end

local function set_context(bufnr, context, animation, hl, char)
	if not context then return end

	context.column = context.column - utils.get_scroll_offset()
	if context.column < 0 then return end

	local marks = markager.context_range(bufnr, context.startln, context.endln, context.column)

	if animation then
		animation(bufnr, marks)
		return
	end

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

function M.hide_context(bufnr, animation)
	local context = get_context_info(bufnr)

	if M.prev_context and not same_context(context) then --
		set_context(bufnr, M.prev_context, animation, 'IndentLine')
		M.prev_context = nil
	end

end

function M.show_context(bufnr, animation)
	local context = get_context_info(bufnr)

	if context then
		if same_context(context) then return end
		nvim.schedule(set_context, bufnr, context, animation)
	end

	M.prev_context = context
end

return M
