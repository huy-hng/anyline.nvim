local M = {}

local fps = 15
local speed_factor = 1.5

local function calc_delay(range)
	if fps == 0 then return 0 end

	local factor = range * speed_factor
	local delay = math.ceil(1000 / (fps + factor)) -- ms
	print('calc_delay', range, factor, delay)

	-- P(speed, speed_factor, range, factor, delay)
	return delay
end

function M.animate_direction(mark_fn, bufnr, start, stop, column)
	local delay = calc_delay(math.abs(stop - start))

	local animation = {}
	local direction = stop - start > 0 and 1 or -1

	-- local timer = vim.loop.new_timer()

	local i = 0
	for line = start, stop, direction do
		local timer = nvim.defer(i * delay, mark_fn, bufnr, line, column)
		table.insert(animation, timer)
		i = i + 1
	end
	return animation
end

local function convert_marks(bufnr, ns)
	if not ns then return end
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
	-- { linenr: extmark_id }
	local converted = {}
	for _, mark in ipairs(marks) do
		converted[mark[2]] = mark[1]
	end
	return converted
end

function M.remove_direction(marks, namespace, bufnr, start, stop)
	local delay = calc_delay(math.abs(stop - start))

	local direction = stop - start > 0 and 1 or -1
	local i = 0
	for line = start, stop, direction do
		local id = marks[line]

		if id then --
			nvim.defer(i * delay, vim.api.nvim_buf_del_extmark, bufnr, namespace, id)
		end
		i = i + 1
	end
end

function M.remove_context(context, namespace)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local bufnr, start, stop, column = unpack(context)

	if not context[1] then return end

	-- local marks = convert_marks(context[1], namespace)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
	-- P(marks)
	-- M.remove_direction(marks, namespace, bufnr, start, cursor_line)
	-- M.remove_direction(marks, namespace, bufnr, stop, cursor_line)
end

local function get_marks_split_by_cursor(bufnr, namespace)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local before_cursor = {}
	local after_cursor = {}

	for _, mark in ipairs(marks) do
		if mark[2] < cursor_line then
			table.insert(before_cursor, mark[1])
		else
			table.insert(after_cursor, 1, mark[1])
		end
	end

	return before_cursor, after_cursor
end

local function calc_delay_ratios(before, after)
	local total = before + after

	local delay = calc_delay(total)

	-- print(bot_ratio, top_ratio)

	local top_ratio = 1
	local bot_ratio = 1
	if after > 0 and before > 0 then
		-- bot_ratio = math.abs(before / total) + 0.5
		-- top_ratio = math.abs(after / total) + 0.5
		bot_ratio = math.abs(before / total)
		top_ratio = math.abs(after / total)
	end

	local delay_top = delay * top_ratio
	local delay_bot = delay * bot_ratio

	print('delay_ratios', delay, delay_top, delay_bot)
	return delay_top, delay_bot
end

function M.animate_removal(bufnr, namespace)
	print('remove context')
	local before_cursor, after_cursor = get_marks_split_by_cursor(bufnr, namespace)
	local delay_top, delay_bot = calc_delay_ratios(#before_cursor, #after_cursor)

	local i = 0
	for _, id in ipairs(before_cursor) do
		nvim.defer(i * delay_top, vim.api.nvim_buf_del_extmark, bufnr, namespace, id)
		i = i + 1
	end

	i = 0
	for _, id in ipairs(after_cursor) do
		nvim.defer(i * delay_bot, vim.api.nvim_buf_del_extmark, bufnr, namespace, id)
		i = i + 1
	end
end

local function cancel_last_animation(timers)
	if not timers then return end
	for _, timer in ipairs(timers) do
		timer:stop()
		if not timer:is_closing() then timer:close() end
	end
end

local last_animation_up
local last_animation_down
function M.animate(mark_fn, context)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local bufnr, start, stop, column = unpack(context)

	cancel_last_animation(last_animation_up)
	cancel_last_animation(last_animation_down)

	if cursor_line > start then --
		if cursor_line > stop then cursor_line = cursor_line - 1 end
		last_animation_up = M.animate_direction(mark_fn, bufnr, cursor_line, start, column)
	end
	if cursor_line < stop then --
		last_animation_down = M.animate_direction(mark_fn, bufnr, cursor_line, stop, column)
	end

	-- P(animation)
end

return M
