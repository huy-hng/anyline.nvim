local M = {}

local cache = require('indent_line.cache')
local def = require('indent_line.default_opts')
local markager = require('indent_line.markager')
-- local colors = require('indent_line.colors')

function M.set_marks(bufnr)
	local marks = cache.buffer_caches[bufnr]
	for linenr, columns in ipairs(marks.lines) do
		for _, col in ipairs(columns) do
			local opts = markager.build_mark_opts(bufnr, linenr, col)
			markager.set_extmark(opts)
		end
	end
end

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	if not indents then return -1 end
	local column = indents[#indents]
	return column or -1
end

---@return { startln: number, endln: number, column: number } | nil
local function get_context_info(bufnr)
	local cursor_pos = vim.fn.getcurpos(0)
	local cursor_line = cursor_pos[2] - 1

	local column = current_indentation(bufnr, cursor_line)
	local next = current_indentation(bufnr, cursor_line + 1)

	if not column and not next then return end

	-- include context when cursor is on start of context (not inside indentation yet)
	if next > column then
		column = next
		cursor_line = cursor_line + 1
	end

	local ranges = cache.buffer_caches[bufnr].line_ranges[column]

	if not ranges then return end

	for _, line_pair in ipairs(ranges) do
		local startln = line_pair[1]
		local endln = line_pair[2]

		if cursor_line >= startln and cursor_line <= endln then --
			return { startln = startln, endln = endln, column = column }
		end
	end
end

local function same_context(new_context)
	if not M.prev_context or not new_context then return end

	local column = M.prev_context.column == new_context.column
	local startln = M.prev_context.startln == new_context.startln
	local endln = M.prev_context.endln == new_context.endln
	-- M.prev_context = new_context
	if column and startln and endln then return true end
end

local function set_context(bufnr, context, hl, char)
	if not context then return end
	local marks = markager.context_range(
		bufnr,
		context.startln,
		context.endln,
		context.column
	)
	for _, mark in ipairs(marks) do
		local mark_id = mark.id
		mark = markager.build_mark_opts(
			bufnr,
			mark.row,
			mark.column,
			char,
			hl,
			{ priority = mark.opts.priority + 1, id = mark.id }
		)
		markager.set_extmark(mark, mark_id)
	end
end

function M.context(data)
	local bufnr = data.buf

	local context = get_context_info(bufnr)

	if M.prev_context and not same_context(context) then
		set_context(bufnr, M.prev_context, 'IndentLine')
	end

	if context then
		if same_context(context) then
			return
		end
		nvim.schedule(set_context,bufnr, context, 'IndentLineContext')
	end

	local move_into_context = not M.prev_context and context
	M.prev_context = context
end

function M.old_context(data)
	local bufnr = data.buf

	local context = get_context_info(bufnr)
	if not context then return end

	-- if same_context(context) then return end

	-- local marks = markager.get_mark_range(bufnr, context.startln, context.endln, context.column)
	local ns = vim.api.nvim_create_namespace('IndentLine')

	-- vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	-- local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, 40, { details = false })
	local marks = vim.api.nvim_buf_get_extmarks(
		bufnr,
		ns,
		{ context.startln - 1, 0 },
		{ context.endln, 0 },
		{ details = true }
	)

	markager.context_range(bufnr, context.startln, context.endln, context.column)
	-- P(marks)
	-- markager.remove_all_marks(bufnr)
	print(bufnr, ns, context.startln, context.endln)

	for _, mark in ipairs(marks) do
		local mark_id = mark[1]
		local row = mark[2]
		-- local col = mark[3]
		local opts = mark[4]
		opts.id = mark_id
		P(mark)

		local col = opts.virt_text_win_col
		if col ~= context.column then goto continue end

		opts.virt_text[1][2] = 'IndentLineContext'
		opts.virt_text_pos = 'overlay'

		-- opts =
		-- 	markager.build_mark_opts(bufnr, row, col, nil, 'IndentLineContext', { priority = 20 })

		-- print(mark_id)
		local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, opts)
		-- markager.set_extmark(opts, mark_id)
		-- local id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, opts.mark)
		::continue::
	end
end


return M
