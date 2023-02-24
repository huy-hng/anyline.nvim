local M = {}

local colors = require('anyline.colors')
local opts = require('anyline.default_opts')
local utils = require('anyline.utils')
local markager = require('anyline.markager')

local function delay_marks(bufnr, marks, hls, move_delay, color_delay, char)
	local timers = {}
	local move_timers = utils.delay_map(marks, move_delay, function(mark)
		local color_timers = utils.delay_map(hls, color_delay, function(hl) --
			markager.set_extmark(
				bufnr,
				mark.row,
				mark.column,
				hl,
				char,
				{ priority = mark.opts.priority + 1, id = mark.id }
			)
		end)
		timers = table.add(timers, color_timers)
	end)
	timers = table.add(timers, move_timers)
	return timers
end

local function get_direction_locations(ctx, cursor, direction)
	local toward_cursor = (direction or 0) == 1
	local startln = ctx.startln - 1
	local endln = ctx.endln + 1

	--stylua: ignore start
	local up_start   = toward_cursor and startln or cursor
	local up_end     = toward_cursor and cursor  or startln
	local down_start = toward_cursor and endln   or cursor
	local down_end   = toward_cursor and cursor  or endln
	--stylua: ignore end

	up_end = up_end - 1
	-- down_start = down_start - 1

	return up_start, up_end, down_start, down_end
end

local function move_line(direction, color, char)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = 1000 / opts.fps
	local move_delay = 1000 / opts.lines_per_second

	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1]
		cursor = cursor - 1

		-- get marks
		local up_start, up_end, down_start, down_end =
			get_direction_locations(ctx, cursor, direction)

		local marks_above = markager.context_range(bufnr, up_start, up_end, ctx.column, end_color)
		local marks_below =
			markager.context_range(bufnr, down_start, down_end, ctx.column, end_color)

		local steps = math.ceil((opts.trail_length * move_delay) / color_delay)
		local hls = colors.create_colors(start_color, end_color, steps, 0)

		local delay_above, delay_below = utils.calc_delay_ratios(#marks_above, #marks_below)

		local timers_above = delay_marks(bufnr, marks_above, hls, delay_above, color_delay)
		local timers_below = delay_marks(bufnr, marks_below, hls, delay_below, color_delay)

		-- local steps_above = math.ceil((opts.trail_length * delay_above) / color_delay)
		-- local steps_below = math.ceil((opts.trail_length * delay_below) / color_delay)
		-- local hls_above = colors.create_colors(start_color, end_color, steps_above, 0)
		-- local hls_below = colors.create_colors(start_color, end_color, steps_below, 0)
		-- local timers_above = delay_marks(bufnr, marks_above, hls_above, delay_above, color_delay)
		-- local timers_below = delay_marks(bufnr, marks_below, hls_below, delay_below, color_delay)

		return table.add(timers_above, timers_below)
	end
end

function M.from_cursor(color, char) --
	return move_line(0, color, char)
end

function M.to_cursor(color, char) --
	return move_line(1, color, char)
end

return M
