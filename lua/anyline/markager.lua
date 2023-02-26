local M = {}
local def = require('anyline.default_opts')
local utils = require('anyline.utils')

---@alias mark_id number
---@alias mark_info { row: number, col: number, hl: string, char: string? } saved representation of extmark
---@alias mark_opts { bufnr: number, row: number, col: number, opts: table } opts to set an extmark
---@alias rows table<number, { col: number[], mark_id: mark_id }>

---@type table<buffer, { mark_id: mark_info, rows: rows }>
M.buffer_marks = {}
M.reverse_marks = {}

M.o = {
	ns = vim.api.nvim_create_namespace('AnyLine'),
}

function M.get_buffer_marks(bufnr)
	if not M.buffer_marks[bufnr] then M.buffer_marks[bufnr] = { rows = {} } end
	return M.buffer_marks[bufnr]
end

---@return mark_opts
function M.build_mark_opts(col, hl, char, extra_opts)
	local opts = {
		virt_text = { { char or def.indent_char, hl or def.highlight } },
		virt_text_win_col = col,
		end_col = col + 1,
		priority = M.o.priority or def.priority,
		virt_text_pos = 'overlay',
		hl_mode = 'combine',
		strict = false,
	}
	return vim.tbl_extend('force', opts, extra_opts or {})
end

function M.set_extmark(bufnr, row, col, hl, char, extra_opts)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	local opts = M.build_mark_opts(col, hl, char, extra_opts)
	-- vim.schedule(function() vim.api.nvim_buf_set_extmark(bufnr, M.o.ns, row, 0, opts) end)
	return vim.api.nvim_buf_set_extmark(bufnr, M.o.ns, row, 0, opts)
end

function M.update_extmark(bufnr, mark_id, hl, char, extra_opts)
	local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, M.o.ns, mark_id, { details = true })
	if not mark then return end

	local row = mark[1]
	if not mark[3] then return end

	local col = mark[3].virt_text_win_col
	M.set_extmark(bufnr, row, col, hl, char, extra_opts)
end

function M.remove_all_marks(bufnr)
	local ns = vim.api.nvim_create_namespace('AnyLine')
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

function M.get_mark_range(bufnr, startln, endln, col)
	local buffer_marks = M.get_buffer_marks(bufnr)
	local marks = {}

	for mark_id, value in pairs(buffer_marks) do
		if col == value.col and value.row >= startln and value.row <= endln then --
			table.insert(marks, { row = value.row, mark_id = mark_id, col = value.col })
		end
	end

	table.sort(marks, function(a, b) return a.row < b.row end)

	return vim.tbl_map(function(value) return value.mark_id end, marks)
end

---@alias mark_with_id { id: number, row: number, col: number, opts: table }
---@alias mark { row: number, col: number, opts: table }

---@return mark | mark_with_id
function M.parse_mark(mark)
	if #mark == 3 then
		local row, col, opts = unpack(mark)
		col = opts.virt_text_win_col
		return { row = row, col = col, opts = opts }
	end

	local id, row, col, opts = unpack(mark)
	col = opts.virt_text_win_col
	return { id = id, row = row, col = col, opts = opts }
end

---@return { col: number, char: string, hl: string, prio: number }
function M.parse_opts(opts)
	local col = opts.virt_text_win_col
	local char = opts.virt_text[1][1]
	local hl = opts.virt_text[1][2]
	local prio = opts.virt_text[1][2]
	return { col = col, char = char, hl = hl, prio = prio }
end

function M.context_range(bufnr, startln, endln, target_column, ignore_color)
	local marks = utils.npcall(
		vim.api.nvim_buf_get_extmarks,
		bufnr,
		M.o.ns,
		{ startln, 0 },
		{ endln, 0 },
		{ details = true }
	)

	local new = {}

	if not marks then return new end

	for _, mark in ipairs(marks) do
		local opts = mark[4]
		local column = opts.virt_text_win_col

		local color = opts.virt_text[1][2]

		-- if color == ignore_color then
		-- if true then return marks end
		-- 	print(ignore_color, color, column, mark[2])
		-- end

		if column == target_column then
			opts.virt_text_pos = 'overlay'
			table.insert(new, {
				id = mark[1],
				row = mark[2],
				column = target_column,
				opts = opts,
			})
		end
	end

	return new
end
return M
