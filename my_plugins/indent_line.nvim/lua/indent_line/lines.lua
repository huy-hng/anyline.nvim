local M = {}
local cache = require('indent_line.cache')

function M.get_scroll_offset()
	local win = vim.fn.winsaveview()
	local leftcol = win.leftcol

	local topline = win.topline
	local col = win.col
	local lnum = win.lnum
	return leftcol
end

function M.mark_factory(namespace, char, hl, priority)
	return function(bufnr, row, col)
		if col < 0 then return end

		vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
			virt_text_hide = false,
			virt_text_win_col = col,
			virt_text = { { char, hl } },
			virt_text_pos = 'overlay',
			hl_mode = 'combine',
			-- hl_eol = true,
			priority = priority or 1,
			right_gravity = true,
			end_right_gravity = false,
			end_col = col + 1,
			strict = false,
		})
	end
end

function M.clear_lines(bufnr, ns) --
	vim.api.nvim_buf_clear_namespace(bufnr or 0, ns, 0, -1)
end

function M.set_lines(bufnr, mark_fn)
	local buf_cache = cache.buffer_caches[bufnr]
	if not buf_cache then return end
	local lines = buf_cache.lines
	

	for line, columns in pairs(lines) do
		for _, column in ipairs(columns) do
			column = column - M.get_scroll_offset()
			mark_fn(bufnr, line, column)
		end
	end
end

return M
