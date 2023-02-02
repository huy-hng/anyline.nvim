local M = {}

local utils = R('indent_line.animation.utils')

local function get_hl_color(name)
    -- from https://github.com/kevinhwang91/nvim-ufo/blob/57f76ff044157010dc1e8c34b05d60906220d6b6/lua/ufo/highlight.lua#L35
    -- local ok, hl = pcall(api.nvim_get_hl_by_name, 'Folded', termguicolors)

	local hl_id = vim.fn.hlID(name)
	hl_id = vim.fn.synIDtrans(hl_id)

	local color = vim.fn.synIDattr(hl_id, 'fg')
	return color:sub(2, #color)
end

---@param color1 string
---@param color2 string
---@param ratio number
local function interpolate_colors(color1, color2, ratio)
	local function interpol_channel(channel1, channel2)
		channel1 = tonumber(channel1, 16)
		channel2 = tonumber(channel2, 16)

		local interpolated = channel1 + ((channel2 - channel1) * ratio)
		return string.format('%x', interpolated)
	end

	local r = interpol_channel(color1:sub(1, 2), color2:sub(1, 2))
	local g = interpol_channel(color1:sub(3, 4), color2:sub(3, 4))
	local b = interpol_channel(color1:sub(5, 6), color2:sub(5, 6))
	return r .. g .. b
end

local function create_colors(steps)
	local col1 = get_hl_color('IndentLineContext')
	local col2 = get_hl_color('IndentLine')
	-- local col2 = get_hl_color('WarningMsg')
	-- local col1 = get_hl_color('Error')
	local hl_names = {}

	local step_size = 1 / steps
	for i = step_size, 1, step_size do
		local between = interpolate_colors(col1, col2, i)
		local name = 'IndentLineFadeColor' .. tostring(i)
		table.insert(hl_names, name)
		Highlight(0, name, { fg = '#' .. between })
	end

	return hl_names
end

local function fade_color(mark, ns, bufnr, highlights)
	local delay = 30

	-- local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, markid, { details = true })
	local id, row, col, opts = unpack(mark)
	for i, hl in ipairs(highlights) do
		nvim.defer((i - 1) * delay, function()
			opts.id = id
			opts.virt_text_pos = 'overlay'
			opts.virt_text = { { '▏', hl } }
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
			if i == #highlights then
				nvim.defer(i * delay, vim.api.nvim_buf_del_extmark, bufnr, ns, id)
			end
		end)
	end
end

local function fade_color(mark, ns, bufnr, highlights)
	local delay = 30

	-- local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, markid, { details = true })
	local id, row, col, opts = unpack(mark)
	for i, hl in ipairs(highlights) do
		nvim.defer((i - 1) * delay, function()
			opts.id = id
			opts.virt_text_pos = 'overlay'
			opts.virt_text = { { '▏', hl } }
			vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
			if i == #highlights then
				nvim.defer(i * delay, vim.api.nvim_buf_del_extmark, bufnr, ns, id)
			end
		end)
	end
end

function M.fade_out(ns, bufnr)
	local highlights = create_colors(10)
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
	utils.mark_map(marks, 0, fade_color, ns, bufnr, highlights)
end

return M
