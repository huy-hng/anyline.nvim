
return {
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

	-- animation
	debounce_time = 30, -- in ms
	fps = 30,
	fade_duration = 0, -- only used when lines_per_second is 0
	length_acceleration = 0.05,

	lines_per_second = 50,
	trail_length = 10,
}
