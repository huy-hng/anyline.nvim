local M = {}

local fps = 45
local length_acceleration = 0.05

function M.calc_delay(range)
	if fps == 0 then return 0 end

	-- local factor = math.max(range * length_acceleration, 1)
	local factor = (range * length_acceleration) + 1
	local delay = math.ceil(1000 / (fps * factor)) -- ms
	-- print('calc_delay: range, factor, delay = ', range, factor, delay)

	return delay
end

function M.reverse_array(tbl)
	local rev = {}
	for i = #tbl, 1, -1 do
		rev[#rev + 1] = tbl[i]
	end
	return rev
end

function M.get_marks_split_by_cursor(bufnr, namespace)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	local before_cursor = {}
	local after_cursor = {}

	for _, mark in ipairs(marks) do
		if mark[2] < cursor_line then
			table.insert(before_cursor, mark[1])
		else
			table.insert(after_cursor, mark[1])
		end
	end

	return before_cursor, after_cursor
end

function M.split_marks_by_cursor(marks)
	table.sort(marks, function(a, b) return a[2] < b[2] end)

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	local before_cursor = {}
	local after_cursor = {}

	for _, mark in ipairs(marks) do
		if mark[2] < cursor_line then
			table.insert(before_cursor, mark[1])
		else
			table.insert(after_cursor, mark[1])
		end
	end

	return before_cursor, after_cursor
end

function M.calc_delay_ratios(before, after)
	local total = before + after

	local delay = M.calc_delay(total)

	local delay_top = delay
	local delay_bot = delay

	local top_ratio = before / total
	local bot_ratio = after / total
	if before > after then
		delay_bot = (top_ratio / bot_ratio) * delay
	else
		delay_top = (bot_ratio / top_ratio) * delay
	end
	return delay_top, delay_bot
end

function M.remove_extmarks(marks, delay, bufnr, ns)
	return M.delay_map(marks, delay, function(id) --
		nvim.schedule(vim.api.nvim_buf_del_extmark, bufnr, ns, id)
	end)
end

function M.cancel_timers(timers)
	if not timers then return end
	for _, timer in ipairs(timers) do
		timer:unref()
		timer:stop()
		if not timer:is_closing() then timer:close() end
	end
end

function M.mark_map(marks, delay, fn, ...)
	local animation = {}
	if type(marks[1]) == 'string' then
		-- vim.api.nvim_buf_get_extmark_by_id()
	end

	for i, mark in ipairs(marks) do
		if delay == 0 then
			fn(mark, ...)
		else
			local timer = nvim.defer((i - 1) * delay, fn, mark, ...)
			table.insert(animation, timer)
		end
	end
	return animation
end

function M.delay_map(iterable, delay, fn, ...)
	local timers = {}

	for i, mark in ipairs(iterable) do
		if delay == 0 then
			fn(mark, ...)
		else
			local timer = nvim.defer((i - 1) * delay, fn, mark, ...)
			table.insert(timers, timer)
		end
	end

	return timers
end

function M.add_timer_callback(timers, callback)
	local max_due = 0
	for _, timer in ipairs(timers) do
		local due = timer:get_due_in()
		if due > max_due then max_due = due end
	end
	-- vim.defer_fn(callback, max_due * 1.1)
	return vim.defer_fn(callback, max_due)
end

return M
