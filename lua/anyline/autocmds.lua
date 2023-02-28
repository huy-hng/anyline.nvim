local M = {}
local cache = require('anyline.cache')
local setter = require('anyline.setter')
local context = require('anyline.context')
local animate = require('anyline.animate')
local opts = require('anyline.opts').opts
local markager = require('anyline.markager')
local Debounce = require('anyline.debounce')

local autocmd = vim.api.nvim_create_autocmd

local function skip_buffer(bufnr)
	-- TODO: include window types and other filters
	local filetypes = { 'sql', 'vimwiki' }
	local ft = vim.bo[bufnr].filetype
	if not vim.tbl_contains(filetypes, ft) then return true end
end

local function hard_refresh(data)
	local bufnr = data.buf

	cache.update_cache(bufnr)

	markager.remove_all_marks(bufnr)
	setter.set_marks(bufnr)

	context.show_context(bufnr)
end

local function update(data)
	local bufnr = data.buf
	cache.update_cache(bufnr)
	setter.update_marks(bufnr)

	context.show_context(bufnr)
end

function M.delete() vim.api.nvim_del_augroup_by_name('AnyLine') end

function M.create()
	local function update_context(data)
		context.update_context(data.buf, animate.show_animation, animate.hide_animation)
	end
	local updater = Debounce(update_context, opts.debounce_time)
	local group = vim.api.nvim_create_augroup('AnyLine', { clear = true })

	autocmd('WinLeave', {
		group = group,
		callback = function(data)
			local ctx = context.get_context_info(data.buf)
			if not ctx then return end
			animate.hide_animation(data.buf, ctx)
		end,
	})

	autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = group,
		callback = update,
	})

	autocmd('CursorMoved', {
		group = group,
		callback = function(data) updater(data) end,
	})

	autocmd({
		'FileChangedShellPost',
		'TextChanged',
		'TextChangedI',
		'WinScrolled',
		'CompleteChanged',
		'BufWinEnter',
		'BufWritePost',
		'SessionLoadPost',
	}, {
		group = group,
		callback = hard_refresh,
	})
end

return M
