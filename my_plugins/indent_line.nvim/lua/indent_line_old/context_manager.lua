---@diagnostic disable: undefined-field

local cache = require('indent_line.cache')
local manager = require('indent_line.line_manager')
local anime = require('indent_line.anime')

local function printer(...)
	-- print(...)
end

local M = {}
---@type Line
M.current_context = nil

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@return { start: number, stop: number, column: number } | nil
local function get_context_info(bufnr)
	local cursor_pos = vim.fn.getcurpos(0)
	local cursor_line = cursor_pos[2] - 1

	local column = current_indentation(bufnr, cursor_line)
	local next = current_indentation(bufnr, cursor_line + 1)

	if not column and not next then return end

	-- include context when cursor is on start of context (not inside indentation yet)
	if next > column then
		column = next
		cursor_line = cursor_line + 1
	end

	local ranges = cache.buffer_caches[bufnr].line_ranges[column]

	if not ranges then return end

	for _, line_pair in ipairs(ranges) do
		local startln = line_pair[1]
		local endln = line_pair[2]

		if cursor_line >= startln and cursor_line <= endln then --
			return { startln = startln, endln = endln, column = column }
		end
	end
end

function M.get_current_context_line(bufnr)
	local cur_ctx = get_context_info(bufnr)

	local markager = require('indent_line_v2.markager')

	if cur_ctx then
		markager.get_mark_range(bufnr, cur_ctx.startln, cur_ctx.endln, cur_ctx.column)
		if true then return end
		return manager.get_line(bufnr, cur_ctx.startln, cur_ctx.endln, cur_ctx.column)
	end

	local cursor_pos = vim.fn.getcurpos(0)
	local cursor_line = cursor_pos[2] - 1

	local lines = manager.get_line_range(cursor_line, bufnr)

	local most_indented_line
	local biggest_column = -1
	for column, line in pairs(lines) do
		if column > biggest_column then
			biggest_column = column
			most_indented_line = line
		end
	end

	return most_indented_line
end

function M.update_buffer(data)
	local bufnr = data.buf

	if not cache.buffer_caches[bufnr] then cache.update_cache(bufnr) end

	local line = M.get_current_context_line(bufnr)

	printer(' ')
	if not line then
		printer('no line')
		M.remove_current_context()
		return
	end

	if line then printer('new context:', line.startln, line.endln, line.column, line.bufnr) end

	if line == M.current_context then
		printer('--------same--------')
		return
	end

	M.remove_current_context()
	printer('========new========')

	if not line then return end

	line:animate(anime.to_cursor, { 'IndentLine', 'IndentLineContext' }, 1)
	M.current_context = line
end

function M.is_new_context(bufnr)
	local line = M.get_current_context_line(bufnr)
	if line ~= M.current_context then return true end
end

function M.remove_current_context()
	if not M.current_context then return end

	M.current_context:cancel_animation()

	M.current_context:animate(anime.to_cursor, { 'IndentLineContext', 'IndentLine' }, 1)
	M.current_context = nil
end

function M.wrap(fn)
	return function(...) fn(...) end
end

return M
