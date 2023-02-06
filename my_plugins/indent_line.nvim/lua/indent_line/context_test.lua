---@diagnostic disable: undefined-field

---@module 'my_plugins.indent_line.nvim.lua.indent_line.line_manager'
local manager = require('indent_line.line_manager')
local cache = require('indent_line.cache')
local animation = require('indent_line.animation.utils')
local utils = require('indent_line.utils')

local M = {}

local function get_current_context_line(bufnr)
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

function M.update_context(data)
	local bufnr = data.buf
	---@type Line
	local line = get_current_context_line(bufnr)
	if not line then return end

	-- local line_range = utils.generate_number_range(line.startln, line.endln)

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	animation.delay_map(line.marks, 50, function(mark)
		if mark[2] > cursor_line then --
			line:update_extmark(mark[2], 'ModeMsg')
		end
	end)

	animation.delay_map(utils.reverse_array(line.marks), 50, function(mark)
		if mark[2] < cursor_line then --
			line:update_extmark(mark[2], 'ModeMsg')
		end
	end)
end

return M
