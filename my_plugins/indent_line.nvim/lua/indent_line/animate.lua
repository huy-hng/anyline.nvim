local M = {}

local fps = 45
local length_acceleration = 0.05

------------------------------------------------Utils-----------------------------------------------

local function reverse_array(tbl)
	local rev = {}
	for i = #tbl, 1, -1 do
		rev[#rev + 1] = tbl[i]
	end
	return rev
end

local function get_marks_split_by_cursor(bufnr, namespace)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local before_cursor = {}
	local after_cursor = {}

	for _, mark in ipairs(marks) do
		if mark[2] <= cursor_line then
			table.insert(before_cursor, mark[1])
		else
			table.insert(after_cursor, mark[1])
		end
	end

	return before_cursor, after_cursor
end

local function calc_delay(range)
	if fps == 0 then return 0 end

	-- local factor = math.max(range * length_acceleration, 1)
	local factor = (range * length_acceleration) + 1
	local delay = math.ceil(1000 / (fps * factor)) -- ms
	-- print('calc_delay: range, factor, delay = ', range, factor, delay)

	return delay
end

local function calc_delay_ratios(before, after)
	local total = before + after

	local delay = calc_delay(total)

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

local function cancel_last_animation(timers)
	if not timers then return end
	for _, timer in ipairs(timers) do
		timer:stop()
		if not timer:is_closing() then timer:close() end
	end
end

local function animate_direction(mark_fn, bufnr, start, stop, column)
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

local function add_extmarks(mark_fn, bufnr, start, stop, column, delay)
	local animation = {}
	local direction = stop - start > 0 and 1 or -1

	local i = 0
	for line = start, stop, direction do
		local timer = nvim.defer(i * delay, mark_fn, bufnr, line, column)
		table.insert(animation, timer)
		i = i + 1
	end

	return animation
end

local function remove_extmarks(marks, delay, bufnr, ns)
	local i = 0
	vim.tbl_map(function(id)
		nvim.defer(i * delay, vim.api.nvim_buf_del_extmark, bufnr, ns, id)
		i = i + 1
	end, marks)
end

----------------------------------------------Animations--------------------------------------------

local last_animation_up
local last_animation_down
local function show_from_cursor(mark_fn, context)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local bufnr, start, stop, column = unpack(context)

	if cursor_line > start then --
		if cursor_line > stop then cursor_line = cursor_line - 1 end
		last_animation_up = animate_direction(mark_fn, bufnr, cursor_line, start, column)
	end
	if cursor_line < stop then --
		last_animation_down = animate_direction(mark_fn, bufnr, cursor_line, stop, column)
	end
end

local function show_to_cursor(mark_fn, context)
	local bufnr, start, stop, column, namespace = unpack(context)

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local before_cursor = math.max(0, cursor_line - start)
	local after_cursor = math.max(0, stop - cursor_line)

	if before_cursor == 0 and after_cursor == 0 then return end
	-- print('before, after',before_cursor, after_cursor)

	local delay_top, delay_bot = calc_delay_ratios(before_cursor, after_cursor)

	if cursor_line > start then --
		if cursor_line > stop then cursor_line = cursor_line - 1 end
		last_animation_up = add_extmarks(mark_fn, bufnr, start, cursor_line, column, delay_top)
	end
	if cursor_line < stop then --
		last_animation_down = add_extmarks(mark_fn, bufnr, stop, cursor_line, column, delay_bot)
	end
end

local function move_away(namespace, bufnr, direction)
	local before_cursor, after_cursor = get_marks_split_by_cursor(bufnr, namespace)
	local delay_top, delay_bot = calc_delay_ratios(#before_cursor, #after_cursor)

	if direction == 0 then
		after_cursor = reverse_array(after_cursor)
	else
		before_cursor = reverse_array(before_cursor)
	end

	remove_extmarks(before_cursor, delay_top, bufnr, namespace)
	remove_extmarks(after_cursor, delay_bot, bufnr, namespace)
end

local highlights = {
	{ 'IndentLineCol1', { fg = '#000000' } },
	{ 'IndentLineCol2', { fg = '#222222' } },
	{ 'IndentLineCol3', { fg = '#444444' } },
	{ 'IndentLineCol4', { fg = '#666666' } },
	-- { 'IndentLineCol0', { link = 'IndentLine' } },
}

-- Helper function for transparency formatting
-- local alpha = function()
-- 	  return string.format("%x", math.floor(255 * vim.g.neovide_transparency_point or 0.8))
-- end
-- -- g:neovide_transparency should be 0 if you want to unify transparency of content and title bar.
-- vim.g.neovide_transparency = 0.0
-- vim.g.transparency = 0.8
-- vim.g.neovide_background_color = "#0f1117" .. alpha()

-- local function lin_interpol(a, b, x) return a + ((b - a) * x) end
-- local hex = lin_interpol(0x000000, 0xffffff, 0.9)
-- local val = string.format('%x', hex)
-- print(val)

local function fade_out(ns, bufnr)
	local delay = 100

	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
	for i, hl in ipairs(highlights) do
		Highlight(0, hl[1], hl[2])

		for j, mark in ipairs(marks) do
			local id, row, col, opts = unpack(mark)
			-- opts.id = id
			opts.virt_text_pos = 'overlay'
			opts.virt_text = { { '▏', hl[1] } }
			opts.priority = 100 + i

			P(i, j, opts.virt_text)

			-- nvim.defer(i - 1 * delay, vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, opts)
			vim.api.nvim_buf_del_extmark(bufnr, ns, id)

			local new_id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
			nvim.defer((i - 1) * delay, vim.api.nvim_buf_del_extmark, bufnr, ns, new_id)

			-- if i == #highlights then
			-- 	nvim.defer(i * delay, vim.api.nvim_buf_del_extmark, bufnr, ns, new_id)
			-- end
		end
		-- break
	end
end

-------------------------------------------------API------------------------------------------------

function M.show(mark_fn, context)
	cancel_last_animation(last_animation_up)
	cancel_last_animation(last_animation_down)

	show_from_cursor(mark_fn, context)
	-- show_to_cursor(mark_fn, context)
end

function M.remove(ns, bufnr)
	move_away(ns, bufnr, 0)
	-- fade_out(ns, bufnr)
end

return M
