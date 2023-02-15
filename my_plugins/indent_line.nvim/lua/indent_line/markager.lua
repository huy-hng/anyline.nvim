local M = {}
local def = require('indent_line.default_opts')

---@alias mark_id number
---@alias mark_info { row: number, col: number, hl: string, char: string? } saved representation of extmark
---@alias mark_opts { bufnr: number, row: number, col: number, opts: table } opts to set an extmark
---@alias rows table<number, { col: number[], mark_id: mark_id }>

---@type table<buffer, { mark_id: mark_info, rows: rows }>
M.buffer_marks = {}
M.reverse_marks = {}

M.o = {
	ns = vim.api.nvim_create_namespace('IndentLine'),
}

function M.get_buffer_marks(bufnr)
	if not M.buffer_marks[bufnr] then M.buffer_marks[bufnr] = { rows = {} } end
	return M.buffer_marks[bufnr]
end

---@return mark_opts
function M.build_mark_opts(bufnr, row, col, char, hl, extra_opts)
	--stylua: ignore
	local opts = {
		virt_text         = { { char or def.indent_char, hl or def.highlight } },
		virt_text_win_col = col,
		end_col           = col + 1,
		priority          = M.o.priority or def.priority,
		virt_text_pos     = 'overlay',
		hl_mode           = 'combine',
		strict            = false,
	}
	vim.tbl_extend('force', opts, extra_opts or {})
	return { bufnr = bufnr, row = row, col = col, opts = opts }
end

---@param mark mark_opts
function M.set_extmark(mark, id)
	if not vim.api.nvim_buf_is_valid(mark.bufnr) then return end

	if id then mark.opts.id = id end
	-- P(mark.opts.virt_text_win_col)
	-- local mark_id
	vim.schedule(function()
		local mark_id = vim.api.nvim_buf_set_extmark(mark.bufnr, M.o.ns, mark.row, 0, mark.opts)

		local marks = M.get_buffer_marks(mark.bufnr)

		-- TODO: get rid of opts.opts? its the entire mark opts that can be queried via nvim api
		marks[mark_id] = mark

		-- update reverse lookup as well
		-- TODO: refactor this crap
		local row = marks.rows[mark.row] or { col = {}, mark_id = nil }
		row.mark_id = mark_id
		table.insert(row.col, mark.col)
	end)

	-- return mark_id
end

function M.remove_all_marks(bufnr)
	local ns = vim.api.nvim_create_namespace('IndentLine')
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

function M.context_range(bufnr, startln, endln, column)
	local marks = vim.api.nvim_buf_get_extmarks(
		bufnr,
		M.o.ns,
		{ startln - 1, 0 },
		{ endln + 1, 0 },
		{ details = true }
	)
	-- if true then return marks end

	local new = {}
	for _, mark in ipairs(marks) do
		local opts = mark[4]
		local col = opts.virt_text_win_col
		if col == column then
			opts.virt_text_pos = 'overlay'
			table.insert(new, {
				id = mark[1],
				row = mark[2],
				column = column,
				opts = opts,
			})
		end
	end

	return new
end

-- TODO: not needed anymore
local function add_extmark(bufnr, row, col, char, hl, extra_opts)
	local opts = M.build_mark_opts(bufnr, row, col, char, hl, extra_opts)
	local mark_id = M.set_extmark(opts)
end

local function test()
	local bufnr = vim.api.nvim_get_current_buf()
	add_extmark(bufnr, 12, 23, 'a', 'a')
	P(M.buffer_marks[bufnr])
end

return M
