local M = {}

local cache = require('indent_line.cache')
local context = R('indent_line.context')
local lines = require('indent_line.lines')

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
local mark_fn = lines.mark_factory(namespace, opts.indent_char, 'IndentLine', opts.priority)

function M.setup(user_opts)
	opts = vim.tbl_extend('force', opts, user_opts or {})
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	M.start()
end

--- start indentline autocmds
function M.start()







	Augroup('IndentLine', {
		Autocmd({ 'CursorMoved', 'CursorMovedI' }, context.update_context),
		Autocmd('WinScrolled', M.refresh),
		Autocmd('WinLeave', context.unset_context),
		Autocmd({
			-- 'CursorHold',
			-- 'CursorHoldI',
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			'VimEnter',
			'SessionLoadPost',
		}, M.update_lines),
	})





end

-- stop autocmds
function M.stop() DeleteAugroup('IndentLine') end

---------------------------------------------Functions----------------------------------------------

function M.refresh(data)
	local bufnr = data.buf
	lines.clear_lines(bufnr, namespace)

	if not cache.buffer_caches[bufnr] then cache.update_cache(bufnr) end

	lines.set_lines(bufnr, mark_fn)
	context.update_context(data)
end

function M.update_lines(data)
	local bufnr = data.buf

	lines.clear_lines(bufnr, namespace)

	cache.update_cache(bufnr)

	context.update_context(data)
	lines.set_lines(bufnr, mark_fn)
end

-- cache.clear_cache()
-- M.stop()
M.setup()

return M
