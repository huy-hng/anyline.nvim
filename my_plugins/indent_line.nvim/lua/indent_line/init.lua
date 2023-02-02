local M = {}

---@module "indent_line.context_manager"
local ContextManager = R('indent_line.context_manager')

local cache = require('indent_line.cache')
local context = R('indent_line.context')
local lines = R('indent_line.lines')

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
local context_manager
function M.start()
	context_manager = ContextManager()
	Augroup('IndentLine', {
		-- Autocmd({ 'CursorMoved', 'CursorMovedI' }, context_manager:update_wrap()),
		Autocmd({ 'CursorMoved', 'CursorMovedI' }, context_manager:wrap(context_manager.update_buffer)),
		-- Autocmd({ 'CursorMoved', 'CursorMovedI' }, context.update_context),
		Autocmd('WinScrolled', M.update),
		-- Autocmd('WinLeave', context_manager:),
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
		}, M.update_wrap(true)),
	})
end

-- stop autocmds
function M.stop() DeleteAugroup('IndentLine') end

---------------------------------------------Functions----------------------------------------------

function M.update(data, update_cache)
	local bufnr = data.buf

	lines.clear_lines(bufnr, namespace)

	if update_cache or not cache.buffer_caches[bufnr] then --
		cache.update_cache(bufnr)
	end

	lines.set_lines(bufnr, mark_fn)
	context_manager:update_buffer(data)
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

-- cache.clear_cache()
-- M.stop
M.setup()

return M
