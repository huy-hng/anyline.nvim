local M = {}
local cache = require('indent_line.cache')
local line_manager = require('indent_line.line_manager')
local ctx_man = require('indent_line.context_manager')
local Debounce = require('indent_line.debounce')

-- R('indent_line.line')
-- R('indent_line.anime')
-- R('indent_line.utils')
-- R('indent_line.context_manager')
-- R('indent_line.line_manager')
-- R('indent_line.animation.colors')

-- TODO: when text changed, only update change area

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

function M.setup(user_opts)
	opts = vim.tbl_extend('force', opts, user_opts or {})
	cache.buffer_caches = {}
	line_manager.buffer_lines = {}

	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	vim.api.nvim_create_namespace('IndentLine')
	-- M.create_autocmds()
end

-- stop autocmds
function M.delete_autocmds() DeleteAugroup('IndentLine') end

--- start indentline autocmds
function M.create_autocmds()
	local debounce_time = 40
	local update_context = Debounce(ctx_man.update_buffer, debounce_time)
	local update_lines = Debounce(M.update_lines, debounce_time)
	local force_reload = Debounce(M.force_reload, debounce_time)

	Augroup('IndentLine', {
		Autocmd('WinLeave', ctx_man.remove_current_context),
		Autocmd({ 'CursorMoved', 'CursorMovedI' }, update_context),
		Autocmd('WinScrolled', update_lines),
		-- Autocmd({ 'CursorHold', 'CursorHoldI' }, update_lines),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			'WinEnter',
			'BufWritePost',
			'SessionLoadPost',
		}, force_reload),
	})
end

---------------------------------------------Functions----------------------------------------------

function M.update_lines(data)
	local bufnr = data.buf
	line_manager.clear_buffer(bufnr)

	line_manager.set_buffer_lines(bufnr)
end

function M.force_reload(data)
	local bufnr = data.buf
	cache.update_cache(data.buf)
	M.update_lines(data)
	nvim.schedule(function()
		ctx_man.update_buffer(data)
		local line = ctx_man.get_current_context_line(bufnr)
		if line then line:add_extmarks(nil, 'IndentLineContext') end
	end)
end

-- :vertical new | set bt=nofile | read ++edit # | 0 delete _ | diffthis | wincmd p | diffthis
-- if !exists(":DiffOrig")
--     command DiffOrig vert new | set bt=nofile | r # | 0d_ | diffthis | wincmd p | diffthis
-- endif

-- M.setup()
-- M.delete_autocmds()

return M
