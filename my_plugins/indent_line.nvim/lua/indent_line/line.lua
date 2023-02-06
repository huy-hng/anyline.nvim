local animation = require('indent_line.animation')
local ani_utils = require('indent_line.animation.utils')
local utils = require('indent_line.utils')

local function calc_middle(lower, upper) return math.ceil((upper - lower) / 2) + lower end

local line_data = {
	startln = 0,
	endln = 0,
	column = 0,
	bufnr = 0,
	ns = 0,
	char = '▏',
	priority = 20,
	hl = 'IndentLine',
}
---@alias line_data `line_data`

---@return table | nil
local function bin_search_row(row_num, extmarks)
	local lower = 0
	local upper = #extmarks
	local middle = calc_middle(lower, upper)
	for _ = 1, 30 do
		local ext_row_num = extmarks[middle][2]
		if ext_row_num > row_num then
			upper = middle
		elseif ext_row_num < row_num then
			lower = middle
		else
			return extmarks[middle]
		end
		middle = calc_middle(lower, upper)
	end
end

---@class Line
---@field data table
---@field startln number
---@field endln number
---@field column number
---@field current_hl string
---
---@field bufnr number
---@field ns number
---
---@field marks table
---@field rows table
---@field timers table
---@field mark_details table
local Line = {}

---param data LineData
---@return Line
function Line:new(data)
	local new = setmetatable({}, self)
	new.data = vim.tbl_extend('force', line_data, data)
	new.bufnr = data.bufnr

	new.ns = type(data.ns) == 'string' and vim.api.nvim_create_namespace(data.ns) or data.ns
	new.current_hl = data.hl

	new.startln = data.startln
	new.endln = data.endln
	new.column = data.column

	return new
end

function Line:get_extmark(id)
	return vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.ns, id, { details = true })
end

function Line:set_extmark(row, opts)
	return vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, row, 0, opts)
end

---@param row number
---@param char string?
---@param hl string?
function Line:add_extmark(row, char, hl)
	self.current_hl = hl or self.current_hl

	local data = self.data
	--stylua: ignore
	local opts = {
		virt_text         = { { char or data.char, hl or data.hl } },
		virt_text_win_col = self.column,
		end_col           = self.column + 1,
		priority          = data.priority or 1,
		virt_text_pos     = 'overlay',
		hl_mode           = 'combine',
		strict            = false,
	}
	local mark_id = self:set_extmark(row, opts)

	self.mark_details[mark_id] = opts
	self.rows[row] = mark_id
	table.insert(self.marks, { mark_id, row })
	table.sort(self.marks, function(a, b) return a[2] < b[2] end)
end

---@param row number
---@param hl string?
function Line:update_extmark(row, hl)
	local mark_id = self.rows[row]
	local opts = self.mark_details[mark_id]
	if not opts then return end

	opts.virt_text = { { self.data.char, hl } }
	opts.priority = opts.priority + 1
	-- opts.virt_text[1][2] = hl

	mark_id = self:set_extmark(row, opts)
	self.mark_details[mark_id] = opts
end

---@param row number
---@param color string | string[]
function Line:change_mark_color(row, color, delay, steps, delete)
	-- local start_color = self.current_hl or self.data.hl
	local start_color = 'IndentLineContext'
	local end_color = color

	if type(color) == 'table' then
		start_color = color[1]
		end_color = color[2]
	end

	-- local highlights = animation.create_colors(start_color, end_color, steps or 10, self.ns)
	local highlights = animation.create_colors(start_color, end_color, steps or 10, 0)

	local timers = ani_utils.delay_map(highlights, delay, function(hl) --
		vim.schedule(function() self:update_extmark(row, hl) end)
	end)

	return timers
end

function Line:add_all_extmarks(char, hl)
	self.current_hl = hl or self.current_hl

	self:remove_line()
	for i = self.startln, self.endln do
		self:add_extmark(i, char, hl)
	end
end

function Line:remove_line()
	self.rows = {}
	self.marks = {}
	self.mark_details = {}

	for _, mark_id in pairs(self.rows) do
		vim.api.nvim_buf_del_extmark(self.bufnr, self.ns, mark_id)
	end
end

function Line:hide(startln, endln) end

----------------------------------------------Animation---------------------------------------------

function Line:animate(fn, callback)
	local timers = fn(self)
end

function Line:cancel_animation()
	if self.timers then --
		utils.cancel_timers(self.timers)
	end
end

---@param other Line
function Line:equals(other)
	if not other then return end
	--stylua: ignore
	if self.startln == other.startln
		and self.endln == other.endln
		and self.column == other.column
		and self.bufnr == other.bufnr
	then return true end
end

Line.__index = Line
Line.__eq = Line.equals

setmetatable(Line, {
	__call = Line.new,
})

return Line
