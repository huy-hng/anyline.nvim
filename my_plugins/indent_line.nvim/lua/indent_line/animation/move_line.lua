local generate_number_range = R('indent_line.utils').generate_number_range
local utils = R('indent_line.animation.utils')

local M = {}

---@param line Line
function M.show_direction(line, start, stop)
	start = start or line.startln
	stop = stop or line.endln

	local direction = stop - start > 0 and 1 or -1
	local lines = generate_number_range(start, stop, direction)
	local delay = utils.calc_delay(math.abs(stop - start))

	local timers = utils.delay_map(lines, delay, function(linenr) --
		line:update_extmark(linenr, 'ModeMsg')
	end)

	return timers
end

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

---@param line Line
function M.show_from_cursor(line)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local startln = line.startln
	local endln = line.endln

	local animation_up
	local animation_down
	if cursor_line > startln then
		if cursor_line > endln then cursor_line = cursor_line - 1 end
		animation_up = M.show_direction(line, cursor_line, startln)
	end

	if cursor_line <= endln then --
		animation_down = M.show_direction(line, cursor_line, endln)
	end

	return table.add(animation_up, animation_down)
end

return M
