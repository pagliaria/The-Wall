# combat_numbers.gd
# Autoload singleton. Call show() from take_damage / receive_heal.
# Spawns a floating label in world space that rises and fades out.
extends Node

# Set false to suppress all combat numbers (toggled by settings)
var enabled : bool = true

# Canvas layer so numbers always draw on top regardless of camera zoom
var _canvas : CanvasLayer = null

# ── colours ──────────────────────────────────────────────────────────────────
const COL_DAMAGE_LARGE : Color = Color(1.00, 0.22, 0.18, 1.0)  # red   (big hit)
const COL_DAMAGE_SMALL : Color = Color(1.00, 0.62, 0.18, 1.0)  # orange (small hit)
const COL_HEAL         : Color = Color(0.30, 0.95, 0.42, 1.0)  # green

# ── tuning ───────────────────────────────────────────────────────────────────
const RISE_DIST   : float = 64.0   # px upward travel in world coords
const DURATION    : float = 0.85   # seconds to fully fade
const LARGE_THRESH: int   = 8      # damage >= this uses larger font

func _ready() -> void:
	_canvas        = CanvasLayer.new()
	_canvas.layer  = 128          # very high — above HUD elements
	add_child(_canvas)

# ── public API ────────────────────────────────────────────────────────────────

# world_pos : position of the unit in world space
# amount    : damage or heal value (always positive)
# is_heal   : true → green "+N", false → red/orange "-N"
func show_number(world_pos: Vector2, amount: int, is_heal: bool = false) -> void:
	if not enabled:
		return

	# Convert world → screen via the main camera
	var camera := _find_camera()
	if camera == null:
		return
	var screen_pos := _world_to_screen(world_pos, camera)

	# Label
	var lbl               := Label.new()
	lbl.text               = "+%d" % amount if is_heal else "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 30 if (is_heal or amount >= LARGE_THRESH) else 20)
	var col : Color        = COL_HEAL if is_heal else \
							 (COL_DAMAGE_LARGE if amount >= LARGE_THRESH else COL_DAMAGE_SMALL)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position          = screen_pos + Vector2(_rand_offset(), 0)
	lbl.z_index           = 10
	_canvas.add_child(lbl)

	# Tween: rise + fade
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -RISE_DIST), DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free).set_delay(DURATION)

# ── helpers ───────────────────────────────────────────────────────────────────

func _find_camera() -> Camera2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Camera2D") as Camera2D

func _world_to_screen(world_pos: Vector2, camera: Camera2D) -> Vector2:
	# Account for camera position, zoom, and viewport centre
	var viewport_size := get_tree().root.get_visible_rect().size
	var offset        := (world_pos - camera.global_position) * camera.zoom
	return viewport_size * 0.5 + offset

func _rand_offset() -> float:
	return randf_range(-14.0, 14.0)
