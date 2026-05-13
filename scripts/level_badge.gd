# level_badge.gd
extends Node2D

const RADIUS       : float = 13.0
const BORDER_WIDTH : float = 2.5
const COL_BORDER   : Color = Color(1.0,  0.82, 0.18, 1.0)
const COL_BG       : Color = Color(0.08, 0.08, 0.12, 0.92)
const COL_TEXT     : Color = Color(1.0,  0.95, 0.6,  1.0)

var _level : int = 1

func _ready() -> void:
	visible = true

func refresh(new_level: int) -> void:
	_level  = new_level
	visible = new_level > 1
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COL_BORDER)
	draw_circle(Vector2.ZERO, RADIUS - BORDER_WIDTH, COL_BG)
	var font      : Font   = ThemeDB.fallback_font
	var font_size : int    = 13
	var text      : String = str(_level)
	var text_size : Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos  : Vector2 = Vector2(-text_size.x * 0.5, text_size.y * 0.28)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COL_TEXT)
