local generate_number_range = R('indent_line.utils').generate_number_range
local utils = R('indent_line.animation.utils')

local M = {}

function M.show_to_cursor(mark_fn, context)
	local bufnr, start, stop, column, namespace = unpack(context)

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local before_cursor = math.max(0, cursor_line - start)
	local after_cursor = math.max(0, stop - cursor_line)

	if before_cursor == 0 and after_cursor == 0 then return end

	local delay_top, delay_bot = utils.calc_delay_ratios(before_cursor, after_cursor)

	local animation_up
	local animation_down
	if cursor_line > start then
		if cursor_line > stop then cursor_line = cursor_line - 1 end
		animation_up = M.show_direction(context, start, cursor_line)
	end

	if cursor_line <= stop then --
		animation_down = M.show_direction(context, stop, cursor_line)
	end

	return table.add(animation_up, animation_down)
end

function M.move_away(namespace, bufnr, direction)
	local before_cursor, after_cursor = utils.get_marks_split_by_cursor(bufnr, namespace)
	local delay_top, delay_bot = utils.calc_delay_ratios(#before_cursor, #after_cursor)

	if direction == 0 then
		after_cursor = utils.reverse_array(after_cursor)
	else
		before_cursor = utils.reverse_array(before_cursor)
	end

	local before = utils.remove_extmarks(before_cursor, delay_top, bufnr, namespace)
	local after = utils.remove_extmarks(after_cursor, delay_bot, bufnr, namespace)

	return table.add(before, after)
end

function M.move_marks(context, direction)
	local bufnr = context.bufnr
	local namespace = context.ns

	local before_cursor, after_cursor = utils.split_marks_by_cursor(context.marks)
	local delay_top, delay_bot = utils.calc_delay_ratios(#before_cursor, #after_cursor)

	-- if direction == 1 then
	after_cursor = utils.reverse_array(after_cursor)
	-- else
	-- 	before_cursor = utils.reverse_array(before_cursor)
	-- end

	local before = utils.remove_extmarks(before_cursor, delay_top, bufnr, namespace)
	local after = utils.remove_extmarks(after_cursor, delay_bot, bufnr, namespace)

	return table.add(before, after)
end

return M
