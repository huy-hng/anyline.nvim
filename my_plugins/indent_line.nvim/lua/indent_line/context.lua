local M = {}

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

local cache = require('indent_line.cache')
local lines = require('indent_line.lines')
local animate = R('indent_line.animate')

local ns_context = vim.api.nvim_create_namespace('IndentLineContext')
local mark_fn =
	lines.mark_factory(ns_context, opts.indent_char, 'IndentLineContext', opts.priority_context)

-----------------------------------------------helpers----------------------------------------------

local function get_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
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

	local ranges = cache.buffer_caches[bufnr].line_ranges[column]
	if not ranges then return end

	for _, line_pair in ipairs(ranges) do
		local start = line_pair[1]
		local stop = line_pair[2]

		if cursor_line >= start and cursor_line <= stop then --
			return start, stop, column
		end
	end
end

M.current_context = {}
function M.update_context(data)
	local bufnr = data.buf or vim.api.nvim_get_current_buf()

	if not cache.buffer_caches[bufnr] then cache.update_cache(bufnr) end
	local start, stop, column = get_current_context(bufnr)

	column = column and column - lines.get_scroll_offset()
	local new_context = { bufnr, start, stop, column, ns_context }

	if not column or column < 0 then
		-- P(data)
		animate.remove(ns_context, bufnr)
		M.current_context = {}
		return
	end

	if table.concat(new_context) ~= table.concat(M.current_context) then
		-- P(data)
		animate.remove(ns_context, bufnr)
		M.current_context = new_context
		animate.show(mark_fn, new_context)
	end
end

function M.unset_context(data)
	animate.remove(ns_context, data.buf)
end

return M
