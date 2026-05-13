# level_badge.gd
# Small circular badge drawn above a unit showing its current level.
# Hidden at level 1. Call refresh(level) whenever level changes.
extends Node2D

const RADIUS       : float = 9.0
const BORDER_WIDTH : float = 2.0
const COL_BORDER   : Color = Color(1.0,  0.82, 0.18, 1.0)   # gold
const COL_BG       : Color = Color(0.08, 0.08, 0.12, 0.92)  # dark
const COL_TEXT     : Color = Color(1.0,  0.95, 0.6,  1.0)   # warm white

var _level : int = 1

func _ready() -> void:
	visible = false   # hidden at level 1

func refresh(new_level: int) -> void:
	_level  = new_level
	visible = new_level > 1
	queue_redraw()

func _draw() -> void:
	# Border circle
	draw_circle(Vector2.ZERO, RADIUS, COL_BORDER)
	# Background circle
	draw_circle(Vector2.ZERO, RADIUS - BORDER_WIDTH, COL_BG)
	# Level number — drawn as a string via draw_string
	var font     : Font   = ThemeDB.fallback_font
	var font_size: int    = 10
	var text     : String = str(_level)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos : Vector2 = Vector2(-text_size.x * 0.5, text_size.y * 0.25)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, COL_TEXT)
