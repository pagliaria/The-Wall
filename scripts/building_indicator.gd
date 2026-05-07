# building_indicator.gd
# Draws a circular indicator below a spawning building showing:
#   - Outer arc ring: spawn timer progress (fills clockwise)
#   - Inner circle: background fill
#   - Center text: "live/max" unit count
#   - Meat icon pulse: shown when building can't spawn due to lack of meat
#
# Add as a child Node2D of any PlacedBuilding that has a controller.
# Call refresh() each frame from placed_building.
extends Node2D

# =========================================================================== #
#  Appearance
# =========================================================================== #

const RADIUS_OUTER  = 22.0
const RADIUS_INNER  = 16.0
const RING_WIDTH    = 6.0
const ARC_STEPS     = 48       # smoothness of the arc

const COLOR_BG        := Color(0.08, 0.08, 0.08, 0.82)
const COLOR_RING_BG   := Color(0.25, 0.25, 0.25, 0.82)
const COLOR_RING_FILL := Color(0.98, 0.78, 0.20, 1.0)   # gold
const COLOR_FULL      := Color(0.25, 0.78, 0.35, 1.0)   # green when at cap
const COLOR_TEXT      := Color(1.0,  1.0,  1.0,  1.0)
const COLOR_NO_MEAT   := Color(0.85, 0.25, 0.25, 1.0)   # red tint when starved

# Meat icon pulse
const MEAT_ICON_TEXTURE := preload("res://assets/UI Elements/UI Elements/Icons/Icon_04.png")
const PULSE_SPEED  := 1     # full cycles per second
const PULSE_OFFSET := Vector2(0, -48)  # above the indicator circle
const ICON_SCALE   := 0.4

# =========================================================================== #
#  State — set by placed_building each frame
# =========================================================================== #

var live_units   : int   = 0
var max_units    : int   = 1
var timer_ratio  : float = 0.0   # 0..1, how full the spawn timer is
var has_meat     : bool  = true  # false = ring turns red + icon pulses

# =========================================================================== #
#  Internals
# =========================================================================== #

var _font      : Font     = null
var _meat_icon : Sprite2D = null
var _pulse_t   : float    = 0.0

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 10

	_meat_icon          = Sprite2D.new()
	_meat_icon.texture  = MEAT_ICON_TEXTURE
	_meat_icon.position = PULSE_OFFSET
	_meat_icon.scale    = Vector2(ICON_SCALE, ICON_SCALE)
	_meat_icon.visible  = false
	add_child(_meat_icon)

func _process(delta: float) -> void:
	var show_icon := not has_meat and live_units < max_units
	if show_icon:
		_pulse_t += delta * PULSE_SPEED
		var s := sin(_pulse_t * TAU)         # -1..1
		var alpha    := remap(s, -1.0, 1.0, 0.3, 1.0)
		var scale_v  := remap(s, -1.0, 1.0, 0.28, 0.42)
		_meat_icon.modulate.a = alpha
		_meat_icon.scale      = Vector2(scale_v, scale_v)
		_meat_icon.visible    = true
	else:
		_meat_icon.visible = false
		_pulse_t = 0.0

# =========================================================================== #
#  Draw
# =========================================================================== #

func _draw() -> void:
	# --- Background circle ---
	draw_circle(Vector2.ZERO, RADIUS_INNER, COLOR_BG)

	# --- Ring background (full circle, dim) ---
	_draw_arc_filled(Vector2.ZERO, RADIUS_OUTER, RADIUS_INNER, 0.0, 1.0, COLOR_RING_BG)

	# --- Ring fill (timer progress) ---
	if live_units >= max_units:
		# At cap: solid green ring
		_draw_arc_filled(Vector2.ZERO, RADIUS_OUTER, RADIUS_INNER, 0.0, 1.0, COLOR_FULL)
	elif timer_ratio > 0.0:
		var fill_color := COLOR_NO_MEAT if not has_meat else COLOR_RING_FILL
		_draw_arc_filled(Vector2.ZERO, RADIUS_OUTER, RADIUS_INNER, 0.0, timer_ratio, fill_color)

	# --- Center text ---
	var label    := "%d/%d" % [live_units, max_units]
	var font_size := 11
	var size     := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var offset   := Vector2(-size.x * 0.5, size.y * 0.35)
	draw_string(_font, offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)

# Draws a filled arc (annulus sector) from ratio start_t to end_t (0..1 = full circle).
# start_t = 0 is the top (12 o'clock), fills clockwise.
func _draw_arc_filled(center: Vector2, r_outer: float, r_inner: float,
		start_t: float, end_t: float, color: Color) -> void:
	if end_t <= start_t:
		return
	var angle_start := -PI * 0.5 + start_t * TAU
	var angle_end   := -PI * 0.5 + end_t   * TAU
	var steps       : Variant = max(1, int(ARC_STEPS * (end_t - start_t)))
	var verts       := PackedVector2Array()

	for i in range(steps + 1):
		var t     := float(i) / float(steps)
		var angle : Variant = lerp(angle_start, angle_end, t)
		verts.append(center + Vector2(cos(angle), sin(angle)) * r_outer)

	for i in range(steps + 1):
		var t     := float(steps - i) / float(steps)
		var angle : Variant = lerp(angle_start, angle_end, t)
		verts.append(center + Vector2(cos(angle), sin(angle)) * r_inner)

	draw_colored_polygon(verts, color)

# =========================================================================== #
#  Public update — call whenever state changes
# =========================================================================== #

func refresh(p_live: int, p_max: int, p_ratio: float, p_has_meat: bool) -> void:
	live_units  = p_live
	max_units   = p_max
	timer_ratio = p_ratio
	has_meat    = p_has_meat
	queue_redraw()
