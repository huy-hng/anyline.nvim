local M = {}

local utils = require('indent_line.utils')
local animation = require('indent_line.animation.utils')
local colors = require('indent_line.animation.colors')

local function create_colors(color, steps)
	-- local start_color = 'IndentLineContext'
	-- local start_color = opts and Contextopts.virt_text[1][2] or 'IndentLine'
	local start_color = 'IndentLineContext'
	local end_color = color

	if type(color) == 'table' then
		start_color = color[1]
		end_color = color[2]
	end

	return colors.create_colors(start_color, end_color, steps or steps, 0)
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
	color_duration = color_duration or 20

	local total_duration = move_duration * math.abs(endln - startln)
	local steps = colors.color_step_amount(total_duration)
	local highlights = create_colors(color, steps)

	local direction = endln - startln > 0 and 1 or -1

	local lines = utils.generate_number_range(startln, endln, direction)

	local timers = utils.delay_map(lines, move_duration, function(linenr) --
		line:change_mark_color(linenr, highlights, color_duration)
	end)

	return timers
end

---@param line Line
---@param color string
---@param direction number
function M.to_cursor(line, color, direction)
	local startln = line.startln
	local endln = line.endln

	local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1

	local up_start = cursor
	local up_end = startln
	local down_start = cursor
	local down_end = endln

	local toward_cursor = (direction or 0) == 1
	if toward_cursor then
		up_start = startln
		up_end = cursor
		down_start = endln
		down_end = cursor
	end

	local dur_up, dur_down = animation.calc_delay_ratios(startln - cursor, cursor - endln)
	-- print('lines', cursor, startln, endln)

	local move_up
	local move_down

	if cursor > startln then
		if cursor > endln then cursor = cursor - 1 end
		move_up = M.animate(line, color, up_start, up_end, dur_up)
	end
	if cursor <= endln then --
		move_down = M.animate(line, color, down_start, down_end, dur_down)
	end

	return table.add(move_up, move_down)
end

return M
