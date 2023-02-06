---@diagnostic disable: undefined-field

local opts = R('indent_line.default_opts')
local cache = R('indent_line.cache')
local manager = require('indent_line.line_manager')

---@module "my_plugins.indent_line.nvim.lua.indent_line.animation"
local animation = R('indent_line.animation')

local context_creator = R('indent_line.context')

local function current_indentation(bufnr, line)
	local indents = cache.get_cache(bufnr).lines[line]
	local column = npcall(table.slice, indents, -1)
	return column or -1
end

---@return { start: number, stop: number, column: number } | nil
local function get_current_context(bufnr)
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

---@class ContextManager
---@field bufnr number
---@field ns number
---@field current_context Context
---@field cancelled_animation Context[]
---@field context_opts { hl: string, char: string , prio: number}
local ContextManager = {}

function ContextManager:new(bufnr, context_opts)
	local new = setmetatable({}, self)

	new.ns = vim.api.nvim_create_namespace('IndentLineContext')

	new.current_context = nil
	new.cancelled_animation = {}
	new.current_marks = {}
	new.context_opts = context_opts or {
		char = '▏',
		hl = 'ModeMsg',
		prio = 20,
	}

	Augroup('IndentLine', {
		Autocmd({
			'CursorHold',
			'CursorHoldI',
		}, function() new.context_opts.prio = 20 end),
	})

	return new
end

function ContextManager:call(...) print('from call') end

function ContextManager:update_buffer(data)
	-- local bufnr = data.buf or vim.api.nvim_get_current_buf()
	local bufnr = data.buf

	if not cache.buffer_caches[bufnr] then cache.update_cache(bufnr) end

	local context_data = get_current_context(bufnr)
	if not context_data then
		self:remove_current_context()
		self.current_context = nil
		return
	end

	if not self:changed_context(context_data) then return end
	self:remove_current_context()

	context_data.column = context_data.column - manager.get_scroll_offset()
	if context_data.column < 0 then return end

	self:new_context(bufnr, context_data)
end

function ContextManager:update_wrap()
	-- return ContextManager:wrap(self.update)
	return function(data) self:update(data) end
end

function ContextManager:wrap(fn)
	return function(...) fn(self, ...) end
end

function ContextManager:changed_context(new_context)
	local c = self.current_context

	if not c or not new_context then return true end

	local start = c.startln ~= new_context.startln
	local endln = c.endln ~= new_context.endln
	local column = c.column ~= new_context.column

	if start and endln and column then return true end
end

function ContextManager:new_context(bufnr, context_data)
	self.context_opts.prio = self.context_opts.prio + 1
	local context = context_creator(self.ns, bufnr, context_data, self.context_opts)
	if not context then return end
	context:show()
	self.current_context = context

	-- vim.schedule(function() self.current_context = context end)
end

function ContextManager:remove_current_context()
	if self.current_context then --
		local timers = self.current_context:remove()

		-- local start = self.current_context.start
		-- local stop = self.current_context.stop
		-- local column = self.current_context.column

		-- utils.add_timer_callback(timers, function() --
		-- 	self:cleanup_leftover_marks(start, stop, column)
		-- end)

		self.current_context = nil
	end
end

function ContextManager:force_delete_all()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
end

function ContextManager:cleanup_leftover_marks(start, stop, column)
	local bufnr = vim.api.nvim_get_current_buf()
	if not self.current_context then return end

	local same_start = start == self.current_context.start
	local same_stop = stop == self.current_context.stop
	local same_column = column == self.current_context.column
	if same_start and same_column and same_stop then return end

	local marks = vim.api.nvim_buf_get_extmarks(bufnr, self.ns, 0, -1, { details = true })
	for _, mark in ipairs(marks) do
		local id, line, _, mark_opts = unpack(mark)
		local same_col = mark_opts.virt_text_win_col == column

		local correct_line_range = start <= line and line <= stop

		if same_col and correct_line_range then
			vim.api.nvim_buf_del_extmark(bufnr, self.ns, id)
			P(mark)
		end
	end
end

ContextManager.__index = ContextManager
ContextManager.__call = ContextManager.call
setmetatable(ContextManager, {
	__call = ContextManager.new,
})

return ContextManager
