local M = {}

local context_manager = require('anyline.context')

---@alias context { startln: number, endln: number, column: number, bufnr: number }
---@type { ctx: context, timers: table }[]
local animations = {}

--- add a running animation to animations table
---@param ctx context context to identify which animation it belongs to
---@param timers table animation timers
---@param cancel_new boolean whether to cancel the new animation if context already has animation
function M.add_animation(ctx, timers, cancel_new)
	for _, ani in ipairs(animations) do
		if context_manager.is_same_context(ani.ctx, ctx) then
			-- animation with this context is already running
			-- either running animation and start new
			-- or cancel new animation

			return
		end
	end
	table.insert(animations, { ctx = ctx, timers = timers })
end

--- remove a running animation from animations table
--- and essentially stop the animation
function M.remove_animation(ctx)
	for i, ani in ipairs(animations) do
		if context_manager.is_same_context(ani.ctx, ctx) then --
			table.remove(animations, i)
		end
	end
end

return M
