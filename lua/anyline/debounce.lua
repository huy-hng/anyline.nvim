local uv = vim.loop


---@class Debounce
---@field timer uv.uv_timer_t | nil
---@field fn function
---@field args table
---@field wait number
---@field leading? boolean
---overload fun(fn: function, wait: number, leading?: boolean): Debounce
local Debounce = {}

---@param fn function
---@param wait number
---@param leading? boolean
---@return Debounce
function Debounce:new(fn, wait, leading)
	vim.validate {
		fn = { fn, 'function' },
		wait = { wait, 'number' },
		leading = { leading, 'boolean', true },
	}
	local o = setmetatable({}, self)
	o.timer = nil
	o.fn = vim.schedule_wrap(fn)
	o.args = nil
	o.wait = wait
	o.leading = leading
	return o
end

function Debounce:call(...)
	local timer = self.timer
	self.args = { ... }
	if not timer then
		timer = uv.new_timer()
		self.timer = timer
		if not timer then return end

		timer:start(
			self.wait,
			self.wait,
			self.leading and function() self:cancel() end or function() self:flush() end
		)
		if self.leading then self.fn(...) end
	else
		timer:again()
	end
end

function Debounce:cancel()
	local timer = self.timer
	if timer then
		if timer:has_ref() then
			timer:stop()
			if not timer:is_closing() then timer:close() end
		end
		self.timer = nil
	end
end

function Debounce:flush()
	if self.timer then
		self:cancel()
		self.fn(unpack(self.args))
	end
end

Debounce.__index = Debounce
Debounce.__call = Debounce.call

return setmetatable(Debounce, {
	__call = Debounce.new,
})
