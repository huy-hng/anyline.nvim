local M = {}

local colors = require('indent_line.colors')
local opts = require('indent_line.default_opts')
local utils = require('indent_line.utils')
local markager = require('indent_line.markager')

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
	local endln = ctx.endln - 0

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

local function animate(bufnr, marks, hls, move_delay, color_delay, char)
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

function M.test(color)
	local start_color = color[1]
	local end_color = color[2]

	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1]
		cursor = cursor - 1

		local move_dur = opts.animation_duration * (1 - opts.speed_color_ratio)
		local color_dur = opts.animation_duration * opts.speed_color_ratio

		local lines = math.abs(ctx.startln - ctx.endln) + 1
		local move_delay = move_dur / lines
		if lines < 3 then move_delay = 0 end

		local steps = math.ceil(color_dur / (1000 / 60))
		local hl_names = colors.create_colors(start_color, end_color, steps, 0)
		local color_delay = color_dur / steps

		local marks = markager.context_range(bufnr, ctx.startln, ctx.endln, ctx.column)
		local timers = delay_marks(bufnr, marks, hl_names, move_delay, color_delay)

		-- print(' ')
		-- print(move_dur, color_dur)
		-- print(lines, move_delay, color_delay, steps)
		-- print(color_delay * steps + move_delay * lines)

		return timers
	end
end

local function direction(bufnr, move_delay, color_delay, startln, endln, column)
	local marks = markager.context_range(bufnr, startln, endln, column)
	local hl_names

	local up_timers = delay_marks(bufnr, marks, move_delay, color_delay)
end

function M.lines_per_s(direction, color, char)
	local start_color = color[1]
	local end_color = color[2]
	local color_dur = 200

	local steps = math.ceil(color_dur / (1000 / 60))
	local hl_names = colors.create_colors(start_color, end_color, steps, 0)

	local function calc_color_dur(move_delay, lines, color_delay)
		local total_duration = (move_delay * lines) + color_delay
		local color_dur_down = total_duration - (delay_down * after_cursor)
		local steps_down = math.ceil(color_dur_down / (1000 / 60))
		color_down = math.ceil(color_dur_down / steps_down)

		hl_down = colors.create_colors(start_color, end_color, steps_down, 0)
		print(steps, steps_down, total_duration, color_dur_down, color_down)
	end

	return function(bufnr, ctx)
		print(' ')
		local cursor = vim.api.nvim_win_get_cursor(0)[1]
		cursor = cursor - 1

		local lines = math.abs(ctx.startln - ctx.endln) + 1

		local position = (cursor - ctx.startln + 1) / (ctx.endln - ctx.startln + 1)

		local before_cursor = math.max(0, cursor - ctx.startln)
		local after_cursor = math.max(0, ctx.endln - cursor)

		local delay_up, delay_down = utils.calc_delay_ratios(before_cursor, after_cursor)

		local up_start, up_end, down_start, down_end =
			get_direction_locations(ctx, cursor, direction)

		local color_delay = color_dur / steps
		local color_up = color_delay
		local color_down = color_delay
		local hl_up = hl_names
		local hl_down = hl_names
		print(delay_up, delay_down)

		if delay_up > delay_down then
			local total_duration = (delay_up * before_cursor) + color_delay
			local color_dur_down = total_duration - (delay_down * after_cursor)
			local steps_down = math.ceil(color_dur_down / (1000 / 60))
			color_down = math.ceil(color_dur_down / steps_down)

			hl_down = colors.create_colors(start_color, end_color, steps_down, 0)
			print(steps, steps_down, total_duration, color_dur_down, color_down)
		else
			local total_duration = (delay_down * before_cursor) + color_delay
			local color_dur_up = total_duration - (delay_up * after_cursor)
			local steps_up = math.ceil(color_dur_up / (1000 / 60))
			color_up = math.ceil(color_dur_up / steps_up)

			hl_up = colors.create_colors(start_color, end_color, steps_up, 0)
			print(steps, steps_up, total_duration, color_dur_up, color_up)
		end

		local marks_before = markager.context_range(bufnr, up_start, up_end, ctx.column)
		local marks_after = markager.context_range(bufnr, down_start, down_end, ctx.column)

		local up_timers = delay_marks(bufnr, marks_before, hl_up, delay_up, color_up)
		local down_timers = delay_marks(bufnr, marks_after, hl_down, delay_down, color_down)
		print(color_up, color_down)

		return table.add(up_timers, down_timers)
	end
end

local function move_line(direction, color, char)
	local start_color = color[1]
	local end_color = color[2]

	local hl_names = colors.create_colors(start_color, end_color, 10, 0)
	local color_delay = 20

	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1]
		cursor = cursor - 1

		local before_cursor = math.max(0, cursor - ctx.startln)
		local after_cursor = math.max(0, ctx.endln - cursor)

		local delay_top, delay_bot = utils.calc_delay_ratios(before_cursor, after_cursor)
		local up_start, up_end, down_start, down_end =
			get_direction_locations(ctx, cursor, direction)

		local marks_before = markager.context_range(bufnr, up_start, up_end, ctx.column)
		local marks_after = markager.context_range(bufnr, down_start, down_end, ctx.column)

		local up_timers = delay_marks(bufnr, marks_before, hl_names, delay_top, color_delay)
		local down_timers = delay_marks(bufnr, marks_after, hl_names, delay_bot, color_delay)

		return table.add(up_timers, down_timers)
	end
end

function M.from_cursor(color, char) --
	return M.lines_per_s(0, color, char)
	-- return move_line(0, color, char)
end

function M.to_cursor(color, char) --
	return M.lines_per_s(1, color, char)
	-- return move_line(1, color, char)
end

return M
