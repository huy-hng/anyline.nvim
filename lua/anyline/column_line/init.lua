local M = {}

----------------------------------------------Config------------------------------------------------

-- vim.g.column_lines = { 80, 100 }
local default_opts = {
	columns = { 100 },
	column_char = '▏',
	wintype_whitelist = { '' },
	buftype_whitelist = { '' },
	filetype_blacklist = {
		'buffer_manager',
		'harpoon',
		'TelescopePrompt',
	},
}

M.opts = default_opts
function M.setup(opts)
	M.remove_colorcolumn_values()

	M.opts = vim.tbl_extend('force', M.opts, opts or {})
	M.namespace = vim.api.nvim_create_namespace('ColumnLine')
	-- Highlight(M.namespace, 'ColumnLine', {})

	Highlight(0, 'ColorColumn', {})
	Highlight(0, 'ColumnLine', {
		link = 'Comment',
		-- fg = '#45475a',
	})
	M.start()
end

function M.start()
	Augroup('ColumnLine', {
		Autocmd('OptionSet', 'colorcolumn', M.refresh),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'VimEnter',
			'SessionLoadPost',
			'BufWinEnter',
			'WinEnter',
			'WinScrolled'
		}, M.refresh),
		Autocmd('WinScrolled', function() 
			-- M.get_scroll_offset()
		end),
	})
end

function M.stop() DeleteAugroup('ColumnLine') end

---------------------------------------------Functions----------------------------------------------

function M.get_scroll_offset()
	local win = vim.fn.winsaveview()
	local leftcol = win.leftcol

	local topline = win.topline
	local col = win.col
	local lnum = win.lnum
	return leftcol
end

function M.remove_colorcolumn_values()
	for _, column in ipairs(vim.opt.colorcolumn:get()) do
		column = tonumber(column)
		if not vim.tbl_contains(M.opts.columns, column) then
			table.insert(M.opts.columns, column)
			table.insert(M.opts.columns, 'alskdj')
		end
	end

	vim.o.colorcolumn = ''
end

local function should_set(line_text, column)
	column = column + 1
	local width = vim.fn.strdisplaywidth(line_text)
	if width < column then return true end

	line_text = line_text:gsub('\t', string.rep(' ', vim.opt.tabstop:get()))
	local char = string.sub(line_text, column, column)
	if char == ' ' or char == '' then return true end
end

local function set_line(bufnr, column)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for linenr, line_text in ipairs(lines) do
		if not should_set(line_text, column) then
			goto continue
		end

		local offset = M.get_scroll_offset()
		vim.api.nvim_buf_set_extmark(bufnr, M.namespace, linenr - 1, 0, {
			virt_text = { { M.opts.column_char, 'ColumnLine' } },
			virt_text_pos = 'overlay',
			hl_mode = 'combine',
			virt_text_win_col = column - offset,
			priority = 1,
			-- hl_group = 'NormalFloat',
			-- end_col = 100,
			-- hl_eol = true,
			-- virt_lines = { { { column_char, 'ColumnLine' } } },
			-- line_hl_group = 'Search',
			-- cursorline_hl_group = 'Visual',
			-- conceal = 'a',
			-- sign_text = 'si'
			-- strict = false,
		})
		::continue::
	end
end

function M.refresh(data)
	local bufnr = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_loaded(bufnr) then return end

	local modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
	local wrong_filetype = vim.tbl_contains(M.opts.filetype_blacklist, vim.bo[bufnr].filetype) -- local wrong_filetype = vim.tbl_contains(M.opts.filetype_blacklist, vim.bo[bufnr].filetype)
	local right_buftype = vim.tbl_contains(M.opts.buftype_whitelist, vim.bo[bufnr].buftype)
	local right_wintype = vim.tbl_contains(M.opts.wintype_whitelist, Util.win_type())

	if wrong_filetype or not right_buftype or not right_wintype or not modifiable then
		vim.api.nvim_win_set_hl_ns(0, M.namespace)
		return
	end

	vim.api.nvim_win_set_hl_ns(0, 0)

	if M.namespace then vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1) end

	for _, column in ipairs(M.opts.columns) do
		set_line(bufnr, tonumber(column))
	end
end

M.setup()

return M
