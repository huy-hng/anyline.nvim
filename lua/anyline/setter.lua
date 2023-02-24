local M = {}

local cache = require('anyline.cache')
local markager = require('anyline.markager')
local utils = require('anyline.utils')
local ns = vim.api.nvim_create_namespace('AnyLine')

function M.set_marks(bufnr)
	local marks = cache.buffer_caches[bufnr]
	for linenr, columns in ipairs(marks.lines) do
		for _, col in ipairs(columns) do
			col = col - utils.get_scroll_offset()
			if col < 0 then return end
			markager.set_extmark(bufnr, linenr, col)
		end
	end
end

local function find_col_in_cache(indents, mark)
	for i, val in ipairs(indents) do
		if val == mark.col then return i end
	end
end

function M.update_marks(bufnr)
	local lines = cache.buffer_caches[bufnr].lines
	local copy = table.copy(lines)

	-- {mark_id, row, col, opts}
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { 0, 0 }, { -1, 0 }, { details = true })
	for i, mark in ipairs(marks) do
		mark = markager.parse_mark(mark)
		local row = mark.row + 0
		local found_index = find_col_in_cache(copy[row], mark)

		if found_index then
			copy[row][found_index] = nil
			marks[i] = nil
		end
	end

	for i, mark in ipairs(marks) do
		mark = markager.parse_mark(mark)
		vim.api.nvim_buf_del_extmark(bufnr, ns, mark.id)
	end

	for linenr, columns in ipairs(copy) do
		for _, col in ipairs(columns) do
			col = col - utils.get_scroll_offset()
			if col < 0 then return end
			markager.set_extmark(bufnr, linenr, col)
		end
	end
end

return M
