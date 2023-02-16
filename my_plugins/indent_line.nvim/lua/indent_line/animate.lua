local M = {}

local colors = require('indent_line.colors')
local utils = require('indent_line.utils')
local markager = require('indent_line.markager')

---@param mark_id number
---@param colors string[]
---@param delay number
function M.change_mark_color(bufnr, mark_id, colors, delay)
	for i, hl in ipairs(colors) do
		nvim.defer((i - 1) * delay, function() --
			markager.update_extmark(bufnr, mark_id, hl)
		end)
	end
end

function M.fade_color(color, char)
	local start_color = color[1]
	local end_color = color[2]

	local hl_names = colors.create_colors(start_color, end_color, 10, 0)
	local color_delay = 30
	local move_delay = 20

	return function(bufnr, marks)
		utils.delay_map(marks, move_delay, function(mark)
			utils.delay_map(hl_names, color_delay, function(hl) --
				markager.set_extmark(
					bufnr,
					mark.row,
					mark.column,
					hl,
					char,
					{ priority = mark.opts.priority + 1, id = mark.id }
				)
			end)
		end)
	end
end

return M
