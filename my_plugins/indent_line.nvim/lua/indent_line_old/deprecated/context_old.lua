---@diagnostic disable: undefined-field

local M = {}

local opts = require('indent_line.default_opts')
local cache = require('indent_line.cache')
local lines = require('indent_line.lines')
local animation = R('indent_line.animation')
local context_creator = R('indent_line.line')

local ns_context = vim.api.nvim_create_namespace('IndentLineContext')
local mark_fn =
	lines.mark_factory(ns_context, opts.indent_char, 'IndentLineContext', opts.priority_context)

-----------------------------------------------helpers----------------------------------------------

function M.update_context(data)
	local bufnr = data.buf or vim.api.nvim_get_current_buf()

	local start, stop, column = get_current_context(bufnr)

	if not cache.buffer_caches[bufnr] then cache.update_cache(bufnr) end

	column = column and column - lines.get_scroll_offset()

	-- local new_context = { bufnr, start, stop, column, ns_context }

	local new_context = context_creator(
		bufnr,
		ns_context,
		start,
		stop,
		column,
		'IndentLineContext',
		opts.indent_char,
		opts.priority_context
	)

	if not column or column < 0 then
		if not M.current_context then return end
		M.current_context:remove()
		M.current_context = nil
		return
	end

	if not M.current_context or M.current_context ~= new_context then
		if M.current_context then
			M.current_context:cancel()
			M.current_context:remove()
		end
		new_context:show()
		M.current_context = new_context
	end
end

function M.unset_context(data) --
	if not M.current_context then return end
	M.current_context:remove()
end

return M
