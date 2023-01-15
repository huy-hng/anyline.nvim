local M = {}

-- TODO: when text changed, only update change area
-- TODO: implement debounce logic. see /home/huy/.local/share/nvim/lazy/nvim-ufo/lua/ufo/lib/debounce.lua
-- for reference

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
	priority = 19,
	priority_context = 20,
}

local namespace = vim.api.nvim_create_namespace('IndentLine')
local namespace_context = vim.api.nvim_create_namespace('IndentLineContext')

---@alias line number
---@alias column number

---@alias line_cache table<line, column[]>
---@alias range_cache table<column, number[]> { column: { start, end } }

---@alias bufnr number

---@type table<bufnr, { lines: line_cache, line_ranges: range_cache }>
local buffer_caches = {}

function M.setup(user_opts)
	opts = vim.tbl_extend('force', opts, user_opts or {})
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	M.start()
end

--- start indentline autocmds
function M.start()
	Augroup('IndentLine', {
		Autocmd({ 'CursorMoved', 'CursorMovedI' }, M.set_context),
		Autocmd({
			'CursorHold',
			'CursorHoldI',
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			'VimEnter',
			'SessionLoadPost',
		}, M.detect_changes),
	})
end

-- stop autocmds
function M.stop() DeleteAugroup('IndentLine') end

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

local function get_indent_width(bufnr)
	local shiftwidth = vim.bo[bufnr].shiftwidth
	local tabstop = vim.bo[bufnr].tabstop
	local expandtab = vim.bo[bufnr].expandtab

	local tabs = shiftwidth == 0 or not expandtab
	local indent_width = tabs and tabstop or shiftwidth
	return indent_width
end

local function convert_cache_format(cached_lines)
	---@type table<column, line[]>
	local converted = {}
	for line, columns in pairs(cached_lines) do
		for _, column in ipairs(columns) do
			if not converted[column] then converted[column] = {} end
			table.insert(converted[column], line)
		end
	end

	---@type range_cache
	local ranges = {}
	for column, lines in pairs(converted) do
		local start
		ranges[column] = {}

		local last_line = -1
		for i, line in ipairs(lines) do
			if i == 1 then
				start = line
				goto continue
			end

			if line ~= last_line + 1 then
				table.insert(ranges[column], { start, last_line })
				start = line
			end

			::continue::
			last_line = line
		end
		table.insert(ranges[column], { start, last_line })
	end

	return ranges
end

local function cache_lines(ts_indent, indent_width, lines)
	local cached_lines = {}
	-- loop through lines
	for linenr, line_text in ipairs(lines) do
		cached_lines[linenr] = {}

		-- if indent in line is 0, skip line
		local total_indent = ts_indent.get_indent(linenr)
		if total_indent == 0 then
			goto continue
		end

		local indents = total_indent / indent_width

		-- loop through indentation columns
		for i = 0, indents - 1 do
			local line_column = i * indent_width

			if should_set_line(line_text, line_column + 1) then
				table.insert(cached_lines[linenr - 1], line_column)
			end
		end

		::continue::
	end

	return cached_lines
end

local function update_cache(bufnr, start, stop)
	local _, ts_indent = get_treesitter(bufnr)
	local indent_width = get_indent_width(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start or 0, stop or -1, false)

	local cached_lines = cache_lines(ts_indent, indent_width, lines)

	local converted = convert_cache_format(cached_lines)
	buffer_caches[bufnr] = {
		lines = cached_lines,
		line_ranges = converted,
	}
end

local function set_lines(bufnr)
	local lines = buffer_caches[bufnr].lines
	for line, columns in pairs(lines) do
		for _, column in ipairs(columns) do
			set_mark(namespace, bufnr, line, column, 'IndentLine', opts.priority)
		end
	end
end

local function clear_lines(bufnr, ns) --
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

function M.detect_changes(data)
	local bufnr = data.buf
	clear_lines(bufnr, namespace)

	update_cache(bufnr)

	M.set_context(data)
	set_lines(bufnr)
end

local function get_indentation(bufnr, line)
	local indents = buffer_caches[bufnr].lines[line]
	local column = npcall(table.slice, indents, -1)
	return column or -1
end

local function get_current_context(bufnr)
	local cursor_pos = vim.fn.getcurpos(0)
	local cursor_line = cursor_pos[2] - 1

	local column = get_indentation(bufnr, cursor_line)
	local next = get_indentation(bufnr, cursor_line + 1)

	if not column and not next then return end
	
	-- include context when cursor is on start of context (not inside indentation yet)
	if next > column then
		column = next
		cursor_line = cursor_line + 1
	end

	local lines = buffer_caches[bufnr].line_ranges[column]
	if not lines then return end

	for _, line_pair in ipairs(lines) do
		local start = line_pair[1]
		local stop = line_pair[2]

		if cursor_line >= start and cursor_line <= stop then --
			return start, stop, column
		end
	end
end

local function set_line(bufnr, start, stop, column)
	for line = start, stop do
		set_mark(namespace_context, bufnr, line, column, 'IndentLineContext', opts.priority_context)
	end
end

function M.set_context(data)
	local bufnr = data.buf or vim.api.nvim_get_current_buf()

	if not buffer_caches[bufnr] then M.detect_changes(data) end

	local start, stop, column = get_current_context(bufnr)

	clear_lines(bufnr, namespace_context)
	if not column then return end

	set_line(bufnr, start, stop, column)
end

M.setup()
-- M.stop()

return M
