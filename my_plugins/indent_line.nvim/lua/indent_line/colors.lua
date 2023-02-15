local M = {}

local opts = require('indent_line.default_opts')
local utils = require('indent_line.utils')

local fps = opts.fps
local mspf = 1000 / fps
local length_acceleration = opts.length_acceleration

local cached_color_names = {}

local function get_hl_color(name)
	-- from https://github.com/kevinhwang91/nvim-ufo/blob/57f76ff044157010dc1e8c34b05d60906220d6b6/lua/ufo/highlight.lua#L35
	-- local ok, hl = pcall(api.nvim_get_hl_by_name, 'Folded', termguicolors)

	local hl_id = vim.fn.hlID(name)
	hl_id = vim.fn.synIDtrans(hl_id)

	local color = vim.fn.synIDattr(hl_id, 'fg')
	return color:sub(2, #color)
end

local function tohex(value)
	if type(value) == 'number' then --
		return string.format('%x', value)
	end
	return tonumber(value, 16)
end

local function separate_channels(color, to_number)
	local r = color:sub(1, 2)
	local g = color:sub(3, 4)
	local b = color:sub(5, 6)
	if to_number then
		r = tohex(r)
		g = tohex(g)
		b = tohex(b)
	end
	return { r = r, g = g, b = b }
end

---@param color1 string
---@param color2 string
---@param ratio number
local function interpolate_colors(color1, color2, ratio)
	local function interpol_channel(channel1, channel2)
		local interpolated = channel1 + ((channel2 - channel1) * ratio)
		return string.format('%x', interpolated)
	end

	local c1 = separate_channels(get_hl_color(color1), true)
	local c2 = separate_channels(get_hl_color(color2), true)

	local r = interpol_channel(c1.r, c2.r)
	local g = interpol_channel(c1.g, c2.g)
	local b = interpol_channel(c1.b, c2.b)
	return r .. g .. b
end

---@return number | nil difference number between 0 and 255 where 255 is max difference
function M.color_difference(color1, color2)
	if not color1 or not color2 then return end

	color1 = separate_channels(get_hl_color(color1), true)
	color2 = separate_channels(get_hl_color(color2), true)

	local r_diff = math.abs(color1.r - color2.r)
	local g_diff = math.abs(color1.g - color2.g)
	local b_diff = math.abs(color1.b - color2.b)

	local average = (r_diff + g_diff + g_diff) / 3
	return average
end

function M.color_step_amount(duration, c1, c2)
	-- local color_diff = M.color_difference(c1, c2)
	duration = math.max(duration, 1)
	if fps == 0 then return 1 end
	local steps = math.ceil(duration / (mspf / 2))
	-- local steps = math.ceil(duration / (1000 / 120))
	return steps
end

function M.create_colors(start_color, end_color, steps, ns)
	local hl_names = {}

	local step_size = 1 / steps
	for i = step_size, 1, step_size do
		local between = interpolate_colors(start_color, end_color, i)
		-- local name = 'IndentLineFadeColor' .. string.format('%.2f', i)
		local name = start_color .. 'To' .. end_color .. string.format('%.2f', i)

		table.insert(hl_names, name)
		Highlight(ns or 0, name, { fg = '#' .. between })
	end

	return hl_names
end

-- TODO: since start and end color can be reversed, theres no need to cache it twice
function M.get_colors(start_color, end_color, steps, ns)
	local name = start_color .. 'To' .. end_color

	for _, cached in ipairs(cached_color_names) do
		if
			cached.start_color == start_color
			and cached.end_color == end_color
			and cached.steps == steps
		then
			return cached.colors
		end
	end

	vim.notify('new colors')
	-- not found, create new
	local new_colors = M.create_colors(start_color, end_color, steps, ns)

	table.insert(cached_color_names, {
		start_color = start_color,
		end_color = end_color,
		steps = steps,
		colors = new_colors,
	})

	return new_colors
end

return M
