local M = {}
local cache = require('indent_line.cache')
local line_manager = require('indent_line.line_manager')
local ctx_man = R('indent_line.context_manager')
local Debounce = require('indent_line.debounce')
local opts = require('indent_line.default_opts')
local utils = require('indent_line.utils')

-- R('indent_line.line')
-- R('indent_line.anime')
-- R('indent_line.utils')
R('indent_line.context_manager')
-- R('indent_line.line_manager')
-- R('indent_line.animation.colors')

-- TODO: when text changed, only update change area
-- TODO: going into context from below has weird animation
-- TODO: sync color and line move durations
-- (short lines feel like they fade color much fast than long ones)

----------------------------------------------Config------------------------------------------------

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
	local debounce_time = 100
	local update_context = Debounce(ctx_man.update_buffer, debounce_time)
	local update_lines = Debounce(M.update_lines, debounce_time)
	local force_reload = Debounce(M.force_reload, debounce_time)

	Augroup('IndentLine', {
		Autocmd('WinLeave', ctx_man.remove_current_context),
		Autocmd({ 'CursorMoved' }, update_context),
		-- Autocmd({ 'CursorMoved', 'CursorMovedI' }, update_context),
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

function M.redraw(bufnr)
	line_manager.clear_buffer(bufnr)
	line_manager.set_buffer_lines(bufnr)


	-- -- TODO: refactor this into a update context function with param "no animation"
	-- local line = ctx_man.get_current_context_line(bufnr)
	-- if not line then return end

	-- local lines = utils.generate_number_range(line.startln, line.endln, line.direction)

	-- utils.delay_map(lines, 0, function(linenr) --
	-- 	line:change_mark_color(linenr, 'IndentLineContext', 0)
	-- end)
end

function M.force_reload(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	-- M.update_lines(data)

	nvim.schedule(M.redraw, data.buf)
end

-- M.setup()
-- M.delete_autocmds()

return M
