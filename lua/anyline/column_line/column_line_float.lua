local popup_config = {
	row = 0,
	col = 101,

	width = 1,
	height = vim.api.nvim_win_get_height(0),

	relative = 'win',

	-- border = 'none', -- none | single | double | rounded | solid | shadow
	style = 'minimal',
	-- focusable = false,
}

local function does_column_line_exist()
	for _, bufnr in ipairs(buffers) do
		local path = api.nvim_buf_get_name(bufnr)
		local split_path = vim.fn.split(path, '/')

		if next(split_path) == nil then
			goto continue
		end

		local name = split_path[#split_path]
		if name == 'Column Line' then return bufnr end
		-- print(path)
		::continue::
	end
	return -1
end

-- local bufnr = does_column_line_exist()

local function main()
	local api = vim.api
	local buffers = api.nvim_list_bufs()
	local bufnr = -1
	if bufnr < 0 then
		bufnr = api.nvim_create_buf(false, true)
		-- api.nvim_buf_set_name(bufnr, 'Column Line')
	end

	api.nvim_buf_set_lines(bufnr, 0, -1, false, nvim.Repeat({ '▏' }, popup_config.height))
	local winid = api.nvim_open_win(bufnr, true, popup_config)

	api.nvim_win_set_option(winid, 'winblend', 100)
end
