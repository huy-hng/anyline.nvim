local M = {}
local opts = R('indent_line.default_opts')

local fps = opts.fps
local mspf = 1000 / fps
local length_acceleration = opts.length_acceleration

function M.generate_number_range(start, stop, step)
	local numbers = {}
	for num = start, stop, step or 1 do
		table.insert(numbers, num)
	end
	return numbers
end

function M.reverse_array(tbl)
	local rev = {}
	for i = #tbl, 1, -1 do
		rev[#rev + 1] = tbl[i]
	end
	return rev
end

function M.get_scroll_offset()
	local win = vim.fn.winsaveview()
	local leftcol = win.leftcol

	local topline = win.topline
	local col = win.col
	local lnum = win.lnum
	return leftcol
end

function M.add_timer_callback(timers, callback)
	local max_due = 0
	for _, timer in ipairs(timers) do
		local due = timer:get_due_in()
		if due > max_due then max_due = due end
	end
	return vim.defer_fn(callback, max_due)
end

function M.cancel_timers(timers)
	if not timers then return end
	for _, timer in ipairs(timers) do
		timer:unref()
		timer:stop()
		if not timer:is_closing() then timer:close() end
	end
end

function M.calc_delay(range)
	if fps == 0 then return 0 end

	local factor = (range * length_acceleration) + 1
	local delay = math.ceil(1000 / (fps * factor)) -- ms
	-- print('calc_delay: range, factor, delay = ', range, factor, delay)

	return delay
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

function M.remove_extmarks(marks, delay, bufnr, ns)
	return M.delay_map(marks, delay, function(id) --
		nvim.schedule(vim.api.nvim_buf_del_extmark, bufnr, ns, id)
	end)
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
	if not iterable then return end

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

return M
