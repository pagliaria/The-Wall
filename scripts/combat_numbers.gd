# combat_numbers.gd
extends Node

var enabled : bool = true

var _canvas : CanvasLayer = null

const COL_DAMAGE_LARGE : Color = Color(1.00, 0.22, 0.18, 1.0)
const COL_DAMAGE_SMALL : Color = Color(1.00, 0.62, 0.18, 1.0)
const COL_HEAL         : Color = Color(0.30, 0.95, 0.42, 1.0)
const COL_LEVEL_UP     : Color = Color(1.00, 0.88, 0.20, 1.0)

const RISE_DIST    : float = 64.0
const DURATION     : float = 0.85
const LARGE_THRESH : int   = 8

func _ready() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)

# is_level_up: shows gold "Lv N!" text instead of damage/heal number
func show_number(world_pos: Vector2, amount: int, is_heal: bool = false, is_level_up: bool = false) -> void:
	if not enabled:
		return
	var camera := _find_camera()
	if camera == null:
		return
	var screen_pos := _world_to_screen(world_pos, camera)

	var lbl               := Label.new()
	var font_size         : int
	var col               : Color

	if is_level_up:
		lbl.text   = "Lv %d!" % amount
		font_size  = 22
		col        = COL_LEVEL_UP
	elif is_heal:
		lbl.text   = "+%d" % amount
		font_size  = 22
		col        = COL_HEAL
	else:
		lbl.text   = "-%d" % amount
		font_size  = 22 if amount >= LARGE_THRESH else 16
		col        = COL_DAMAGE_LARGE if amount >= LARGE_THRESH else COL_DAMAGE_SMALL

	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = screen_pos + Vector2(_rand_offset(), 0)
	lbl.z_index  = 10
	_canvas.add_child(lbl)

	var rise  := RISE_DIST * (1.4 if is_level_up else 1.0)
	var dur   := DURATION  * (1.4 if is_level_up else 1.0)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -rise), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free).set_delay(dur)

func _find_camera() -> Camera2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Camera2D") as Camera2D

func _world_to_screen(world_pos: Vector2, camera: Camera2D) -> Vector2:
	var viewport_size := get_tree().root.get_visible_rect().size
	var offset        := (world_pos - camera.global_position) * camera.zoom
	return viewport_size * 0.5 + offset

func _rand_offset() -> float:
	return randf_range(-14.0, 14.0)
