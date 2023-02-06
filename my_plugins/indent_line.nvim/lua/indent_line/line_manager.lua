local M = {}
local cache = require('indent_line.cache')
local Line = require('indent_line.line')

---alias column number
---alias line_cache table<line, column[]>
---alias range_cache table<column, number[]> { column: { start, end } }

---@alias bufnr number
---@alias indent_line { startln: number, endln: number, column: number }
---type table<bufnr, indent_line[]>
---@type table<bufnr, Line[]>
M.buffer_lines = {}

function M.get_line(bufnr, startln, endln, column)
	local buffer = M.buffer_lines[bufnr]
	if not buffer then return end
	local data = {
		startln = startln,
		endln = endln,
		column = column,
		bufnr = bufnr,
	}
	for _, line in ipairs(buffer) do
		if line:equals(data) then
			return line
		end
	end
end

---@param linenr number?
---@param bufnr number?
---@return table<number, Line> { column: Line }
function M.get_line_range(linenr, bufnr)
	if not linenr then
		local cursor_pos = vim.fn.getcurpos(0)
		linenr = cursor_pos[2] - 1
	end

	if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

	local buffer = M.buffer_lines[bufnr]
	if not buffer then return {} end

	local found = {}
	for _, line in ipairs(buffer) do
		if line.startln <= linenr and linenr <= line.endln then found[line.column] = line end
	end
	return found
end

function M.set_buffer_lines(bufnr)
	if not cache.buffer_caches[bufnr] then --
		cache.update_cache(bufnr)
	end

	local buf_cache = cache.buffer_caches[bufnr]
	if not buf_cache then return end

	local columns = buf_cache.line_ranges
	if not columns then return end

	for column, line_pairs in pairs(columns) do
		if M.get_scroll_offset() > column then
			goto continue
		end

		for _, line_pair in ipairs(line_pairs) do
			---@type Line
			local line = Line {
				bufnr = bufnr,
				startln = line_pair[1],
				endln = line_pair[2],
				lh = 'IndentLine',
				column = column - M.get_scroll_offset(),
				ns = vim.api.nvim_create_namespace('IndentLine'),
			}
			line:add_all_extmarks()
			if not M.buffer_lines[bufnr] then M.buffer_lines[bufnr] = {} end
			table.insert(M.buffer_lines[bufnr], line)
		end
		::continue::
	end
	-- P(#M.buffer_lines[bufnr])
end

function M.clear_buffer(bufnr, ns, startln, endln)
	bufnr = bufnr or 0
	ns = ns or vim.api.nvim_create_namespace('IndentLine')
	startln = startln or 0
	endln = endln or -1
	vim.api.nvim_buf_clear_namespace(bufnr, ns, startln, endln)

	M.buffer_lines[bufnr] = {}
end

function M.get_scroll_offset()
	local win = vim.fn.winsaveview()
	local leftcol = win.leftcol

	local topline = win.topline
	local col = win.col
	local lnum = win.lnum
	return leftcol
end

return M
