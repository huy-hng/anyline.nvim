local utils = R('indent_line.animation.utils')
local animation = R('indent_line.animation')

---@class Context
---@field start number
---@field stop number
---@field column number
---@field active boolean wether the context is highlighted or in an animation
---
---@field bufnr number
---@field ns number namespace
---
---@field hl string highlight group
---@field char string line character
---@field prio number extmark priority
---
---@field timers table
---@field marks table
---overload fun(fn: function, wait: number, leading?: boolean): UfoDebounce
local Context = {}

-- function Context:new(bufnr, ns, start, stop, column, hl, char, prio)
function Context:new(ns, bufnr, data, opts)
	local new = setmetatable({}, self)
	new.start = data.start
	new.stop = data.stop
	new.column = data.column
	new.active = false

	new.bufnr = bufnr
	new.ns = ns

	if opts then
		new.hl = opts.hl
		new.char = opts.char
		new.prio = opts.prio
	end

	new.marks = {}
	new.timers = {}
	return new
end

function Context:call(...) end

function Context:set_extmark(row, col)
	col = col or self.column
	if col < 0 then return end

	local mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, row, 0, {
		virt_text_hide = false,
		virt_text_win_col = col,
		virt_text = { { self.char, self.hl } },
		virt_text_pos = 'overlay',
		hl_mode = 'combine',
		-- hl_eol = true,
		priority = self.prio or 1,
		right_gravity = true,
		end_right_gravity = false,
		end_col = col + 1,
		strict = false,
	})
	table.insert(self.marks, { mark_id, row })
	-- self.marks[row] = mark_id
end

function Context:show()
	-- for i, val in ipairs(self.marks) do
	-- 	nvim.defer(i * 0, vim.api.nvim_buf_del_extmark, self.bufnr, self.ns, val)
	-- end
	self.active = true
	self.timers = animation.show_from_cursor(self)
end

function Context:animate(fn, callback)
	local timers = fn(self)

	utils.add_timer_callback(timers, function()
		if callback then
			callback()
		end
		-- local marks = vim.api.nvim_buf_get_extmarks(self.bufnr, self.ns, 0, -1, { details = true })
		-- for _, mark in ipairs(marks) do
		-- 	local opts = mark[4]
		-- 	if opts.virt_text_win_col == self.column then
		-- 		vim.api.nvim_buf_del_extmark(self.bufnr, self.ns, mark[1])
		-- 		P(marks[1])
		-- 	end
		-- end
	end)
end

function Context:remove()
	self:cancel_animation()
	nvim.schedule(function() self:animate(animation.move_marks) end)

	animation.fade_out(self.ns, self.bufnr)
	-- if not self.active then return end
	-- self.active = false
	-- local timers = animation.move_marks(self, 0)
end

function Context:cancel_animation()
	if self.timers then --
		utils.cancel_timers(self.timers)
	end
end

function Context:equals(other)
	local start = self.start == other.start
	local stop = self.stop == other.stop
	local column = self.column == other.column
	local bufnr = self.bufnr == other.bufnr

	return start and stop and column and bufnr and true or false
	-- return false
end

Context.__index = Context
Context.__call = Context.call
Context.__eq = Context.equals

setmetatable(Context, {
	__call = Context.new,
})
return Context
