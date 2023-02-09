local M = {}
local utils = R('indent_line.utils')
local opts = R('indent_line.default_opts')

local fps = opts.fps
local mspf = 1000 / fps
local length_acceleration = opts.length_acceleration

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

function M.calc_delay(range)
	if fps == 0 then return 0 end

	-- local factor = math.max(range * length_acceleration, 1)
	local factor = (range * length_acceleration) + 1
	local delay = math.ceil(1000 / (fps * factor)) -- ms
	-- print('calc_delay: range, factor, delay = ', range, factor, delay)

	return delay
end


function M.calc_delay_ratios(before, after)
	before = math.abs(before)
	after = math.abs(after)

	local total = before + after
	local delay = M.calc_delay(total)

	local delay_top = delay
	local delay_bot = delay

	local top_ratio = before / total
	local bot_ratio = after / total
	if before > after then
		delay_bot = math.max((top_ratio / bot_ratio) * delay, 0)
	else
		delay_top = math.max((bot_ratio / top_ratio) * delay, 0)
	end
	return delay_top, delay_bot
end

---@param line Line
function M.show_direction(line, start, stop)
	start = start or line.startln
	stop = stop or line.endln

	local direction = stop - start > 0 and 1 or -1
	local lines = utils.generate_number_range(start, stop, direction)
	local delay = utils.calc_delay(math.abs(stop - start))

	local timers = utils.delay_map(lines, delay, function(linenr) --
		line:update_extmark(linenr, 'ModeMsg')
	end)

	return timers
end

return M
