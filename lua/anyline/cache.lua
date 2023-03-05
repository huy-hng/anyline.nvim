local M = {}

local utils = require('anyline.utils')
local opts = require('anyline.opts').opts

---@alias line number
---@alias column number
---@alias line_cache table<line, column[]>
---@alias range_cache table<column, number[]> { column: { start, end } }
---@alias bufnr number
---@type table<bufnr, { lines: line_cache, line_ranges: range_cache }>
M.buffer_caches = {}

local function get_treesitter(bufnr)
	local ts_query = utils.nrequire('nvim-treesitter.query')
	local ts_indent = utils.nrequire('nvim-treesitter.indent')
	local use_ts_indent = ts_query and ts_indent and ts_query.has_indents(vim.bo[bufnr].filetype)
	-- print(ts_query.has_indents(vim.bo[bufnr].filetype))
	return ts_query, ts_indent
end

local function should_set_line(line_text, col)
	local spaces = vim.opt.tabstop:get() -- use vim.api.nvim_buf_get_option(bufnr, name) instead?

	line_text = line_text:gsub('\t', string.rep(' ', spaces))
	local char = string.sub(line_text, col, col)
	if char == ' ' or char == '' then return true end
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

function M.get_cache(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not M.buffer_caches[bufnr] then M.update_cache(bufnr) end
	return M.buffer_caches[bufnr]
end

function M.clear_cache(bufnr)
	M.buffer_caches = {}
	if bufnr then M.update_cache(bufnr) end
end

function M.cache_lines(ts_indent, indent_width, lines)
	local cached_lines = {}
	-- loop through lines
	for linenr, line_text in ipairs(lines) do
		cached_lines[linenr] = {}

		-- if indent in line is 0, skip line
		local total_indent = ts_indent.get_indent(linenr)
		if total_indent == 0 then goto continue end

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

function M.update_cache(bufnr, start, stop)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start or 0, stop or -1, false)
	-- print(#lines)
	-- if #lines > opts.max_lines then return end

	local _, ts_indent = get_treesitter(bufnr)
	local indent_width = get_indent_width(bufnr)
	local cached_lines = M.cache_lines(ts_indent, indent_width, lines)
	local converted = convert_cache_format(cached_lines)

	M.buffer_caches[bufnr] = { lines = cached_lines, line_ranges = converted }
end

return M
