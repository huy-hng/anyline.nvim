local M = {}

local cache = require('indent_line.cache')
local context = R('indent_line.context')
local manager = require('indent_line.line_manager')
local ContextManager = R('indent_line.context_manager')
R('indent_line.animation.move_line')

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

function M.setup(user_opts)
	opts = vim.tbl_extend('force', opts, user_opts or {})
	Highlight(0, 'IndentLine', { link = opts.highlight })
	Highlight(0, 'IndentLineContext', { link = opts.context_highlight })
	M.set_autocmds()
end

--- start indentline autocmds
function M.set_autocmds()
	local context_manager = ContextManager()
	Augroup('IndentLine', {
		-- Autocmd({ 'CursorMoved', 'CursorMovedI' }, context.update_context),
		Autocmd(
			{ 'CursorMoved', 'CursorMovedI' },
			context_manager:wrap(context_manager.update_buffer)
		),
		Autocmd('WinScrolled', M.update_lines),
		Autocmd('WinLeave', function() context_manager:remove_current_context() end),
		Autocmd({
			'FileChangedShellPost',
			'TextChanged',
			'TextChangedI',
			'CompleteChanged',
			'BufWinEnter',
			-- 'VimEnter',
			'SessionLoadPost',
		}, M.force_reload),
		-- }, M.update_lines),
	})
end

-- stop autocmds
function M.delete_autocmds() DeleteAugroup('IndentLine') end

---------------------------------------------Functions----------------------------------------------

function M.update_lines(data)
	local bufnr = data.buf
	manager.clear_buffer(bufnr)
	manager.set_buffer_lines(bufnr)
end

function M.force_reload(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	M.update_lines(data)
end

function M.update_wrap(update_cache)
	if type(update_cache) == 'table' then
		local data = update_cache
		M.update(data, false)
	end

	return function(data) --
		M.update(data, update_cache)
	end
end

M.setup()

return M
