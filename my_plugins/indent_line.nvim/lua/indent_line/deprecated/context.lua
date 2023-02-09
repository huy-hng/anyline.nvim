local utils = require('indent_line.animation.utils')
local animation = require('indent_line.animation')
local manager = require('indent_line.line_manager')

---@class Context
---@field line Line
---@field startln number
---@field endln number
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

---@param ns number
---@param bufnr number
---@param data table
---@param opts table
-- function Context:new(line, opts)
function Context:new(ns, bufnr, data, opts)
	local startln = data.startln
	local endln = data.endln
	local column = data.column
	local line = manager.get_line(bufnr, startln, endln, column)

	if not line then return end

	local new = setmetatable({}, self)
	new.line = line
	new.startln = line.startln
	new.endln = line.endln
	new.column = line.column

	new.bufnr = bufnr
	new.ns = ns

	if opts then
		new.hl = opts.hl
		new.char = opts.char
		new.prio = opts.prio
	end

	new.active = false
	new.timers = {}
	return new
end

function Context:call(...) end

function Context:show()
	self.active = true
	self.timers = animation.show_from_cursor(self.line)
end

function Context:animate(fn, callback)
	local timers = fn(self.line)
end

function Context:remove()
	self:cancel_animation()

	local line = self.line

	for linenr = line.startln, line.endln do
		line:change_mark_color(linenr, 'IndentLine', 20, 10, false)
	end
end

function Context:cancel_animation()
	if self.timers then --
		utils.cancel_timers(self.timers)
	end
end

function Context:equals(other)
	local startln = self.startln == other.startln
	local endln = self.endln == other.endln
	local column = self.column == other.column
	local bufnr = self.bufnr == other.bufnr

	return startln and endln and column and bufnr and true or false
	-- return false
end

Context.__index = Context
Context.__call = Context.call
Context.__eq = Context.equals

setmetatable(Context, {
	__call = Context.new,
})
return Context
