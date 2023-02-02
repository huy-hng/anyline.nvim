local colors = R('indent_line.animation.colors')
local move_line = R('indent_line.animation.move_line')
local utils = R('indent_line.animation.utils')

return {
	fade_out = colors.fade_out,
	show_to_cursor = move_line.show_to_cursor,
	show_from_cursor = move_line.show_from_cursor,
	cancel_last_animation = utils.cancel_last_animation,
	move_away = move_line.move_away,
	move_marks = move_line.move_marks,
}
