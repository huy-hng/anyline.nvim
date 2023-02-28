local M = {}

local colors = require('anyline.colors')
local opts = require('anyline.opts').opts
local utils = require('anyline.utils')
local markager = require('anyline.markager')

---@alias directions
---| 'to_cursor'
---| 'from_cursor'

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

---@param ctx any
---@param cursor number
---@param direction directions
local function get_direction_locations(ctx, cursor, direction)
	local to_cursor = direction == 'to_cursor'
	local startln = ctx.startln - 1
	local endln = ctx.endln + 1

	--stylua: ignore start
	local above_start = to_cursor and startln or cursor
	local above_end   = to_cursor and cursor  or startln
	local below_start = to_cursor and endln   or cursor
	local below_end   = to_cursor and cursor  or endln
	--stylua: ignore end

	-- above_end = above_end - 1
	return above_start, above_end, below_start, below_end
end

---@param direction directions
---@param color string[]
---@return function
local function move_line(direction, color)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = opts.fps == 0 and 0 or 1000 / opts.fps
	local move_delay = utils.calc_delay()

	---@param ctx context
	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1

		local steps = math.ceil((opts.trail_length * move_delay) / color_delay)
		if opts.lines_per_second == 0 then --
			steps = math.ceil(opts.fade_duration / color_delay)
		end
		if opts.fps == 0 then steps = 1 end
		steps = math.max(steps, 1)

		local hls = colors.create_colors(start_color, end_color, steps, 0)

		local above_start, above_end, below_start, below_end =
			get_direction_locations(ctx, cursor, direction)

		local marks_above = markager.context_range(ctx.bufnr, above_start, above_end, ctx.column)
		local marks_below = markager.context_range(ctx.bufnr, below_start, below_end, ctx.column)

		local delay_above, delay_below = utils.calc_delay_ratios(#marks_above, #marks_below)

		local timers_above = delay_marks(ctx.bufnr, marks_above, hls, delay_above, color_delay)
		local timers_below = delay_marks(ctx.bufnr, marks_below, hls, delay_below, color_delay)

		return table.add(timers_above, timers_below)
	end
end

local function move_line_test(direction, color, char)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = 1000 / opts.fps
	local move_delay = 1000 / opts.lines_per_second
	if opts.lines_per_second == 0 then move_delay = 0 end

	---@param ctx context
	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1

		local above_start, above_end, below_start, below_end =
			get_direction_locations(ctx, cursor, direction)

		local marks_above = markager.context_range(ctx.bufnr, above_start, above_end, ctx.column)
		local marks_below = markager.context_range(ctx.bufnr, below_start, below_end, ctx.column)

		local delay_above, delay_below = utils.calc_delay_ratios(#marks_above, #marks_below)

		local steps_above = math.ceil((opts.trail_length * delay_above) / color_delay)
		local steps_below = math.ceil((opts.trail_length * delay_below) / color_delay)

		local hls_above = colors.create_colors(start_color, end_color, steps_above, 0)
		local hls_below = colors.create_colors(start_color, end_color, steps_below, 0)

		local timers_above =
			delay_marks(ctx.bufnr, marks_above, hls_above, delay_above, color_delay)
		local timers_below =
			delay_marks(ctx.bufnr, marks_below, hls_below, delay_below, color_delay)

		return table.add(timers_above, timers_below)
	end
end

---@alias animations
---| 'to_cursor'
---| 'from_cursor'
---| 'top_down'
---| 'bottom_up'
---| 'none'

local function no_animation(bufnr, ctx)
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

function M.from_cursor(color) --
	return move_line('from_cursor', color)
end

function M.to_cursor(color) --
	return move_line('to_cursor', color)
end

local animations = {
	from_cursor = { show = M.from_cursor, hide = M.to_cursor },
	to_cursor = { show = M.to_cursor, hide = M.from_cursor },
	none = { show = no_animation, hide = no_animation },
}

function M.create_animations(animation)
	local ani = animations[animation]

	if not ani then
		vim.notify('No such animation "' .. opts.animation .. '"', vim.log.levels.ERROR)
		return no_animation
	end

	M.show_animation = ani.show { 'AnyLine', 'AnyLineContext' }
	M.hide_animation = ani.hide { 'AnyLineContext', 'AnyLine' }
end

return M
