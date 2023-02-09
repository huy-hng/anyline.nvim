local M = {}

local utils = require('indent_line.utils')
local animation = require('indent_line.animation.utils')
local colors = R('indent_line.animation.colors')

---@param line Line
function M.fade_color(line, color, color_delay, move_delay)
	local lines = utils.generate_number_range(line.startln, line.endln)

	color = color or 'IndentLine'
	move_delay = move_delay or 0
	color_delay = color_delay or 20

	local timers = utils.delay_map(lines, move_delay, function(linenr) --
		line:change_mark_color(linenr, color, color_delay)
	end)

	return timers
end


local function create_colors(color, steps)
	-- local start_color = 'IndentLineContext'
	-- local start_color = opts and Contextopts.virt_text[1][2] or 'IndentLine'
	local start_color = 'IndentLineContext'
	local end_color = color

	if type(color) == 'table' then
		start_color = color[1]
		end_color = color[2]
	end

	-- local highlights = animation.create_colors(start_color, end_color, steps or 10, self.ns)
	return colors.get_colors(start_color, end_color, steps, 0)
end

---@param line Line
---@param color string
---@param startln number?
---@param endln number?
---@param move_duration number?
---@param color_duration number?
function M.animate(line, color, startln, endln, move_duration, color_duration)
	startln = startln or line.startln
	endln = endln or line.endln

	move_duration = move_duration or utils.calc_delay(math.abs(endln - startln))
	local total_duration = move_duration * math.abs(endln - startln)

	color_duration = color_duration or 20
	local steps = colors.color_step_amount(total_duration)

	local direction = endln - startln > 0 and 1 or -1
	local lines = utils.generate_number_range(startln, endln, direction)

	local highlights = create_colors(color, steps)

	local timers = utils.delay_map(lines, move_duration, function(linenr) --
		line:update_extmark(linenr, color)
		-- line:change_mark_color(linenr, highlights, color_duration)
	end)

	return timers
end

---@param line Line
---@param color string
---@param direction number
function M.to_cursor(line, color, direction)
	local to_cursor = (direction or 0) == 1

	local startln = line.startln
	local endln = line.endln

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local up_cursor = cursor_line <= endln and cursor_line or cursor_line - 2
	local up_start = up_cursor
	local up_end = startln
	local down_start = cursor_line
	local down_end = endln

	if to_cursor then
		up_start = startln
		up_end = cursor_line
		down_start = endln
		down_end = cursor_line
	end
	local dur_up, dur_down = animation.calc_delay_ratios(startln - cursor_line, up_cursor - endln)

	-- local move_up = cursor_line > startln and M.animate(line, color, up_start, up_end, dur_up) or {}
	-- local move_down = cursor_line <= endln
	-- 		and M.animate(line, color, down_start, down_end, dur_down)
	-- 	or {}

	local move_up
	if cursor_line > startln then
		if cursor_line > endln then cursor_line = cursor_line - 1 end
		move_up = M.animate(line, color, up_start, up_end, dur_up)
	end

	local move_down
	if cursor_line <= endln then --
		move_down = M.animate(line, color, down_start, down_end, dur_down)
	end

	return table.add(move_up, move_down)
end

---@param line Line
function M.show_from_cursor(line)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local startln = line.startln
	local endln = line.endln

	local move_up
	if cursor_line > startln then
		if cursor_line > endln then cursor_line = cursor_line - 1 end
		move_up = animation.show_direction(line, cursor_line, startln)
	end

	local move_down
	if cursor_line <= endln then --
		move_down = animation.show_direction(line, cursor_line, endln)
	end

	return table.add(move_up, move_down)
end

return M
