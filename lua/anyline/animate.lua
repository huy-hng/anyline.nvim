local M = {}

local colors = require('anyline.colors')
local opts = require('anyline.opts').opts
local utils = require('anyline.utils')
local markager = require('anyline.markager')

---@alias animations
---| 'to_cursor'
---| 'from_cursor'
---| 'top_down'
---| 'bottom_up'
---| 'none'

---@alias directions
---| 'to_cursor'
---| 'from_cursor'
---| 'top_down'
---| 'bottom_up'

local function delay_marks(bufnr, marks, hls, move_delay, color_delay, char)
	local timers = {}
	local move_timers = utils.delay_map(marks, move_delay, function(mark)
		if mark.opts then
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
		end
	end)
	timers = table.add(timers, move_timers)
	return timers
end

---@param ctx any
---@param cursor number
---@param direction directions
local function get_direction_marks(ctx, cursor, direction)
	local from_cursor = direction == 'from_cursor'

	local startln = ctx.startln - 0
	local endln = ctx.endln + 0

	local above_start
	local above_end
	local below_start
	local below_end

	local curr = vim.api.nvim_win_get_cursor(0)[1] - 1
	local position = math.clamp((curr - startln) / (endln - startln), 0, 1)

	--stylua: ignore start
	if from_cursor then
		above_end   = startln - 1
		above_start = cursor
		below_start = cursor
		below_end   = endln + 1
	else
		above_start = startln
		above_end   = cursor
		below_end   = cursor
		below_start = endln
	end
	--stylua: ignore end

	local marks_above = markager.context_range(ctx.bufnr, above_start, above_end, ctx.column)
	local marks_below = markager.context_range(ctx.bufnr, below_start, below_end, ctx.column)
	if not from_cursor then
		if position > 0.5 then
			marks_below[#marks_below] = {}
		else
			marks_above[#marks_above] = {}
		end
	end
	return marks_above, marks_below

	-- if position > 0.5 then
	-- 	if to_cursor then
	-- 		below_end = below_end + 1
	-- 	else
	-- 		above_start = above_start - 1
	-- 	end
	-- else
	-- 	if to_cursor then
	-- 		above_end = above_end - 1
	-- 	else
	-- 		below_start = below_start + 1
	-- 	end
	-- end

	-- above_end = above_end - 1
	-- return above_start, above_end, below_start, below_end
end

---@param direction directions
---@param color string[]
---@return function
local function directional(direction, color)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = opts.fps == 0 and 0 or 1000 / opts.fps

	---@param ctx context
	return function(_, ctx)
		local move_delay = utils.calc_delay(ctx.endln - ctx.startln)
		local steps = math.ceil((opts.trail_length * move_delay) / color_delay)
		if opts.lines_per_second == 0 then --
			steps = math.ceil(opts.fade_duration / color_delay)
		end
		if opts.fps == 0 then steps = 1 end
		steps = math.max(steps, 1)

		local hls = colors.create_colors(start_color, end_color, steps, 0)

		local startln = ctx.startln
		local endln = ctx.endln
		if direction == 'bottom_up' then
			startln = ctx.endln
			endln = ctx.startln
		end
		local marks = markager.context_range(ctx.bufnr, startln, endln, ctx.column)

		return delay_marks(ctx.bufnr, marks, hls, move_delay, color_delay)
	end
end

---@param direction directions
---@param color string[]
---@return function
local function cursor_animation(direction, color, type)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = opts.fps == 0 and 0 or 1000 / opts.fps

	---@param ctx context
	return function(bufnr, ctx)
		local move_delay = utils.calc_delay(ctx.endln - ctx.startln)

		local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
		if type == 'hide' then cursor = M.last_cursor_pos or cursor end

		local steps = math.ceil((opts.trail_length * move_delay) / color_delay)
		if opts.lines_per_second == 0 then --
			steps = math.ceil(opts.fade_duration / color_delay)
		end
		if opts.fps == 0 then steps = 1 end

		steps = math.max(steps, 1)
		local hls = colors.create_colors(start_color, end_color, steps, 0)

		local marks_above, marks_below = get_direction_marks(ctx, cursor, direction)

		local delay_above, delay_below
		-- if direction == 'from_cursor' then
		-- 	delay_above = move_delay
		-- 	delay_below = move_delay
		-- else
		-- 	delay_above, delay_below = utils.calc_delay_ratios(#marks_above, #marks_below)
		-- end

		delay_above, delay_below = utils.calc_delay_ratios(#marks_above, #marks_below)
		local timers_above = delay_marks(ctx.bufnr, marks_above, hls, delay_above, color_delay)
		local timers_below = delay_marks(ctx.bufnr, marks_below, hls, delay_below, color_delay)

		return table.add(timers_above, timers_below)
	end
end

local function cursor_test(direction, color, type)
	local start_color = color[1]
	local end_color = color[2]
	local color_delay = 1000 / opts.fps
	local move_delay = 1000 / opts.lines_per_second
	if opts.lines_per_second == 0 then move_delay = 0 end

	---@param ctx context
	return function(bufnr, ctx)
		local cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
		if type == 'hide' then cursor = M.last_cursor_pos or cursor end

		local above_start, above_end, below_start, below_end =
			get_direction_marks(ctx, cursor, direction)

		local marks_above = markager.context_range(ctx.bufnr, above_start, above_end, ctx.column)
		local marks_below = markager.context_range(ctx.bufnr, below_start, below_end, ctx.column)

		local delay_above, delay_below =
			utils.calc_delay_ratios(#marks_above, #marks_below, ctx.endln - ctx.startln)

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

function M.no_animation(color)
	if type(color) == 'table' then color = color[2] end

	return function(bufnr, ctx)
		local marks = markager.context_range(bufnr, ctx.startln, ctx.endln, ctx.column)
		delay_marks(ctx.bufnr, marks, { color }, 0, 0)
	end
end

function M.top_down(color) return directional('top_down', color) end
function M.bottom_up(color) return directional('bottom_up', color) end
function M.from_cursor(color, type) return cursor_animation('from_cursor', color, type) end
function M.to_cursor(color, type) return cursor_animation('to_cursor', color, type) end

local show_colors = { 'AnyLine', 'AnyLineContext' }
local hide_colors = { 'AnyLineContext', 'AnyLine' }

--stylua: ignore
local animations = {
	from_cursor = { show = M.from_cursor(show_colors),  hide = M.to_cursor(hide_colors, 'hide') },
	to_cursor   = { show = M.to_cursor(show_colors),    hide = M.from_cursor(hide_colors, 'hide') },
	top_down    = { show = M.top_down(show_colors),     hide = M.bottom_up(hide_colors) },
	bottom_up   = { show = M.bottom_up(show_colors),    hide = M.top_down(hide_colors) },
	none        = { show = M.no_animation(show_colors), hide = M.no_animation(hide_colors) },
}

function M.create_animations(animation)
	local ani = animations[animation]

	if not ani then
		vim.notify('No such animation "' .. opts.animation .. '"', vim.log.levels.ERROR)
		ani = animations.none
	end

	M.show_animation = ani.show
	M.hide_animation = ani.hide
end

return M
