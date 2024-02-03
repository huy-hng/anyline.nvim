local M = {}
local opts = require('anyline.opts').opts

local function handle_pcall(status, ...) --
	return status and ... or nil
end

function M.nrequire(name) --
	return handle_pcall(pcall(require, name))
end

function M.npcall(fn, ...) return handle_pcall(pcall(fn, ...)) end

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
	---@diagnostic disable-next-line: undefined-field
	return win.leftcol
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
	if opts.lines_per_second == 0 then return 0 end
	range = math.abs(range or 0)

	local factor = (range * opts.length_acceleration) + 1
	local delay = math.ceil(1000 / (opts.lines_per_second * factor))

	-- print('calc_delay: range, factor, delay = ', range, factor, delay)

	return delay
end

function M.calc_delay_ratios(above, below)
	above = math.abs(above)
	below = math.abs(below)

	local total = (above + below) - 1
	local delay = M.calc_delay(total)

	local delay_above = delay
	local delay_below = delay

	local ratio_above = above / total
	local ratio_below = below / total

	if above < below then
		delay_above = ratio_above == 0 and 0 or (ratio_below / ratio_above) * delay
	else
		delay_below = ratio_below == 0 and 0 or (ratio_above / ratio_below) * delay
	end

	return delay_above, delay_below
end

function M.remove_extmarks(marks, delay, bufnr, ns)
	return M.delay_map(marks, delay, function(id) --
		vim.schedule(function() vim.api.nvim_buf_del_extmark(bufnr, ns, id) end)
	end)
end

function M.delay_map(iterable, delay, fn, callback)
	local timers = {}
	if not iterable then return end

	for i, item in ipairs(iterable) do
		if delay == 0 then
			fn(item)
		else
			local timer = vim.defer_fn(function() fn(item) end, (i - 1) * delay)
			table.insert(timers, timer)
		end
		if type(callback) == 'function' and i == #iterable then
			local timer = vim.defer_fn(function() callback(item) end, (i - 1) * delay)
			table.insert(timers, timer)
		end
	end

	return timers
end

function M.add(...)
	local new = select(1, ...)
	new = type(new) == 'table' and new or { new }

	for _, list in ipairs { select(2, ...) } do
		if type(list) ~= 'table' then
			table.insert(new, list)
			goto continue
		end

		for _, val in ipairs(list) do
			table.insert(new, val)
		end
		::continue::
	end
	return new
end

function M.clamp(x, lower, upper) --
	return math.min(upper, math.max(x, lower))
end

return M
