local M = {}

-- local require('anyline.context').is_same_context = require('anyline.context')..is_same_context
local utils = require('anyline.utils')

-- TODO: idea: animate as an object that has the methods start() and cancel()
-- which makes managing them a little easier

---@alias animation { ctx: context, timers: table }
---@type animation[]
local animations = {}

---@param ctx context
local function remove_on_done(ctx, timers)
	utils.add_timer_callback(timers, function() M.remove_animation(ctx) end)
end

--- add a running animation to animations table
---@param ctx context context to identify which animation it belongs to
---@param timers table animation timers
---@param cancel_new boolean | nil whether to cancel the new animation if context already has animation
function M.add_animation(ctx, timers, cancel_new)
	if not ctx or not timers then return end
	if M.is_running(ctx) then
		-- either stop running animation and start new
		-- or cancel new animation
		-- if cancel_new then return end
		-- M.cancel_animation(ctx)
	end
	remove_on_done(ctx, timers)

	table.insert(animations, { ctx = ctx, timers = timers })
end

--- remove a running animation from animations table
---@param ctx context
function M.remove_animation(ctx)
	local i = M.get_index(ctx)
	if not i then return end

	table.remove(animations, i)
end

--- cancels a running animation of context ctx
--- if animation is not running, return
---@param ctx context
function M.cancel_animation(ctx)
	local i, ani = M.get_animation(ctx)
	if not ani then return end

	utils.cancel_timers(ani.timers)
	table.remove(animations, i)
end

--- given context ctx, returns animation and its index in animations table
---@param ctx context
---@return number | nil
function M.get_index(ctx)
	for i, ani in ipairs(animations) do
		if require('anyline.context').is_same_context(ani.ctx, ctx) then --
			return i
		end
	end
end

--- given context ctx, returns timers
---@param ctx context
---@return table | nil
function M.get_timers(ctx)
	for _, ani in ipairs(animations) do
		if require('anyline.context').is_same_context(ani.ctx, ctx) then --
			return ani.timers
		end
	end
end

--- given context ctx, returns index and animation
---@param ctx context
---@return number | nil
---@return animation | nil
function M.get_animation(ctx)
	for i, ani in ipairs(animations) do
		if require('anyline.context').is_same_context(ani.ctx, ctx) then --
			return i, ani
		end
	end
end

--- given context ctx, check wether its running or not
---@param ctx context
---@return boolean
function M.is_running(ctx)
	for _, ani in ipairs(animations) do
		if require('anyline.context').is_same_context(ani.ctx, ctx) then --
			return true
		end
	end
	return false
end

return M
