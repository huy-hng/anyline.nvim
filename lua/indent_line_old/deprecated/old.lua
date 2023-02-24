local M = {}

----------------------------------------------Config------------------------------------------------
local opts = {
	indent_char = '▏',
	ft_ignore = {
		'NvimTree',
		'TelescopePrompt',
		'alpha',
	},
	highlight = 'Comment',
	context_highlight = 'ModeMsg',
}

local namespace = vim.api.nvim_create_namespace('IndentLine')
local namespace_context = vim.api.nvim_create_namespace('IndentLineContext')

local patterns = {
	'class',
	'^func',
	'method',
	'^if',
	'while',
	'for',
	'with',
	'try',
	'except',
	'arguments',
	'argument_list',
	'object',
	'dictionary',
	'element',
	'table',
	'tuple',
	'do_block',
}

local use_ts_scope = false

local current_context

function M.setup(user_opts)
	opts = vim.tbl_extend('force', opts, user_opts or {})
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	M.start()
end

function M.start()
	Augroup('IndentLine', {
		Autocmd({ 'CursorMoved', 'CursorMovedI' }, function(data) M.refresh(data, true) end),
		Autocmd({ 'CursorHold', 'CursorHoldI' }, function(data) M.refresh(data, true) end),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			'VimEnter',
			'SessionLoadPost',
		}, M.refresh),
		Autocmd('OptionSet', {
			'list',
			'listchars',
			'shiftwidth',
			'tabstop',
			'expandtab',
		}, M.refresh),
	})
end

function M.stop() DeleteAugroup('IndentLine') end

----------------------------------------------Deprecated--------------------------------------------

local function set_line(bufnr, column)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for linenr, line_text in ipairs(lines) do
		local width = vim.fn.strdisplaywidth(line_text)
		if width == 0 then
			goto continue
		end

		::continue::
	end
end

local function get_treesitter(bufnr)
	local has_ts_query, ts_query = pcall(require, 'nvim-treesitter.query')
	local has_ts_indent, ts_indent = pcall(require, 'nvim-treesitter.indent')
	local use_ts_indent = has_ts_query
		and has_ts_indent
		and ts_query.has_indents(vim.bo[bufnr].filetype)
	return use_ts_indent, ts_indent
end

---------------------------------------------Functions----------------------------------------------

local function set_mark(ns, bufnr, row, col, hl, prio)
	-- local spaces = Repeat(' ', col)
	local spaces = ''
	vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
		virt_text_hide = false,
		virt_text_win_col = col,
		virt_text = { { spaces .. opts.indent_char, hl } },
		virt_text_pos = 'overlay',
		hl_mode = 'combine',
		-- hl_eol = true,
		priority = prio or 1,
		right_gravity = true,
		end_right_gravity = true,
		end_col = col + 1,
		strict = false,
	})
end

local function should_set_line(line_text, col)
	local spaces = vim.opt.tabstop:get() -- use vim.api.nvim_buf_get_option(bufnr, name) instead?

	line_text = line_text:gsub('\t', string.rep(' ', spaces))
	local char = string.sub(line_text, col, col)
	if char == ' ' or char == '' then return true end
	return false
end

---@type table<number, table<number>>
local cached_lines = {} -- TODO
local function cache_lines(line, column) table.insert(cached_lines[line], column) end

local function get_indent_width(bufnr)
	local shiftwidth = vim.bo[bufnr].shiftwidth
	local tabstop = vim.bo[bufnr].tabstop
	local expandtab = vim.bo[bufnr].expandtab

	local tabs = shiftwidth == 0 or not expandtab
	local indent_width = tabs and tabstop or shiftwidth
	return indent_width
end

local function set_lines(bufnr)
	local _, ts_indent = get_treesitter(bufnr)
	local indent_width = get_indent_width(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for linenr, line_text in ipairs(lines) do
		local total_indent = ts_indent.get_indent(linenr)
		if total_indent == 0 then
			goto continue
		end

		local indent_depth = total_indent / indent_width

		for i = 0, indent_depth - 1 do
			local line_column = i * indent_width
			if should_set_line(line_text, line_column + 1) then
				set_mark(namespace, bufnr, linenr - 1, line_column, 'IndentLine')
			end
		end

		::continue::
	end
end

local function clear_lines(bufnr, ns) --
	pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
end

-----------------------------------------------Context----------------------------------------------

local function get_current_context(type_patterns, use_treesitter_scope)
	local invalid = { false, 0, 0, nil }
	local has_ts, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
	if not has_ts then return unpack(invalid) end

	local locals = require('nvim-treesitter.locals')
	local cursor_node = ts_utils.get_node_at_cursor()

	if use_treesitter_scope then
		local current_scope = locals.containing_scope(cursor_node, 0)
		if not current_scope then return unpack(invalid) end

		local node_start, _, node_end, _ = current_scope:range()

		if node_start == node_end then return unpack(invalid) end

		return true, node_start + 1, node_end + 1, current_scope:type()
	end

	while cursor_node do
		local node_type = cursor_node:type()
		for _, rgx in ipairs(type_patterns) do
			if node_type:find(rgx) then
				local node_start, _, node_end, _ = cursor_node:range()
				if node_start ~= node_end then --
					return true, node_start + 1, node_end + 1, rgx
				end
			end
		end
		cursor_node = cursor_node:parent()
	end

	return unpack(invalid)
end

local last_indent
local last_pos

local function should_update_context()
	if not current_context then
		-- vim.notify('no context')
		return true
	end

	local cursor_pos = vim.fn.getcurpos(0)

	if not last_pos then
		-- vim.notify('no last pos')
		last_pos = cursor_pos
		return true
	end

	-- cursor moved horizontally
	if cursor_pos[2] == last_pos[2] then
		last_pos = cursor_pos
		-- print('moving horizontally')
		return
	end

	local pos = cursor_pos[2]
	if pos < current_context[1] or pos > current_context[2] then
		-- P(pos, current_context)
		-- vim.notify('cursor outside of current context')
		return true
	end

	last_pos = cursor_pos

	local _, ts_indent = get_treesitter(0)
	local total_indent = ts_indent.get_indent(cursor_pos[2])
	-- P(total_indent, pos, current_context)
	if not last_indent or total_indent ~= last_indent then
		last_indent = total_indent
		-- vim.notify('different indent')
		return true
	end
	last_indent = total_indent
end

local function get_context(bufnr)
	local status, start, stop, pattern = get_current_context(patterns, use_ts_scope)

	local _, ts_indent = get_treesitter(bufnr)
	local total_indent = ts_indent.get_indent(start)

	current_context = { start, stop, total_indent }
end

local function set_context(bufnr)
	local should_update = should_update_context()
	-- if should_update then vim.notify(tostring(should_update)) end
	-- vim.notify(tostring(should_update))
	if not should_update then --
		return
	end

	clear_lines(bufnr, namespace_context)
	get_context(bufnr)

	-- local indent_width = get_indent_width(bufnr)
	local total_indent = current_context[3]

	-- local indent_depth = total_indent / indent_width
	-- local indent_col = total_indent / indent_width

	for linenr = current_context[1], current_context[2] - 2 do
		set_mark(namespace_context, bufnr, linenr, total_indent, 'IndentLineContext', 20)
	end
end

local function should_set_lines(bufnr)
	if not vim.tbl_contains(opts.ft_ignore, vim.bo[bufnr].filetype) then return true end
end

function M.refresh(data, context)
	local bufnr = data.buf or 0

	if context then
		nvim.schedule(set_context, bufnr)
		return
	end

	clear_lines(bufnr, namespace)

	set_lines(bufnr)
end

-- M.start()
-- M.stop()
return M
