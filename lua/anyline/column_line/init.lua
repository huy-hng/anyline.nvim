local M = {}
local utils = require('anyline.utils')
local Debounce = require('anyline.debounce')

----------------------------------------------Config------------------------------------------------

local default_opts = {
	columns = { 100 },
	column_char = '▏',
	wintype_whitelist = { '' },
	buftype_whitelist = { '' },
	buftype_blacklist = { '' },
	filetype_blacklist = {},
	max_lines = 1024,
}

M.opts = default_opts
function M.setup(opts)
	M.remove_colorcolumn_values()

	M.opts = vim.tbl_extend('force', M.opts, opts or {})
	M.namespace = vim.api.nvim_create_namespace('ColumnLine')
	-- Highlight(M.namespace, 'ColumnLine', {})

	vim.api.nvim_set_hl(0, 'ColorColumn', {})
	vim.api.nvim_set_hl(0, 'ColumnLine', { link = 'NonText' })
	M.start()
end

local autocmd = vim.api.nvim_create_autocmd

function M.start()
	local group = vim.api.nvim_create_augroup('ColumnLine', { clear = true })

	local refresh = M.refresh

	autocmd({
		'FileChangedShellPost',
		'TextChanged',
		'TextChangedI',
		'CompleteChanged',
		'VimEnter',
		'SessionLoadPost',
		'BufWinEnter',
		'WinEnter',
		'WinScrolled',
	}, {
		group = group,
		callback = function(data) refresh(data) end,
	})
end

function M.stop()
	-- DeleteAugroup('ColumnLine')
	pcall(vim.api.nvim_del_augroup_by_name, 'ColumnLine')

	local buffers = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
		end
	end
end

---------------------------------------------Functions----------------------------------------------

function M.remove_colorcolumn_values()
	for _, col in ipairs(vim.opt.colorcolumn:get()) do
		local column = tonumber(col)
		if not vim.tbl_contains(M.opts.columns, column) then
			table.insert(M.opts.columns, column)
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
		if not should_set(line_text, column) then goto continue end

		local offset = utils.get_scroll_offset()
		vim.api.nvim_buf_set_extmark(bufnr, M.namespace, linenr - 1, 0, {
			virt_text = { { M.opts.column_char, 'ColumnLine' } },
			virt_text_pos = 'overlay',
			hl_mode = 'combine',
			virt_text_win_col = column - offset,
			priority = 1,
		})
		::continue::
	end
end

function M.refresh(data)
	-- if data.event == 'WinScrolled' and utils.get_scroll_offset() == 0 then return end

	local bufnr = data.buf
	if not vim.api.nvim_buf_is_loaded(bufnr) then return end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count > M.opts.max_lines then return end

	local modifiable = vim.bo[bufnr].modifiable
	local ft = vim.bo[bufnr].filetype
	local bt = vim.bo[bufnr].buftype
	local wt = Util.win_type()

	local black_file = table.contains(M.opts.filetype_blacklist, ft)
	local white_buf = table.contains(M.opts.buftype_whitelist, bt)
	local black_buf = table.contains(M.opts.buftype_blacklist, bt)
	local white_win = table.contains(M.opts.wintype_whitelist, wt)

	if M.namespace then vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1) end

	if black_file or black_buf or not white_buf or not white_win or not modifiable then
		-- vim.api.nvim_win_set_hl_ns(0, M.namespace)
		return
	end
	-- vim.api.nvim_win_set_hl_ns(0, 0)
	for _, column in ipairs(M.opts.columns) do
		set_line(bufnr, tonumber(column))
	end
end

M.setup()

return M
