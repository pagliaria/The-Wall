extends Node2D
# poison_icon_fx.gd — small bobbing poison indicator shown above a unit while
# the Poison status (unit_base.gd / enemy_base.gd apply_poison) is active.
# Purely visual, no gameplay logic of its own. Mirrors wet_droplet_fx.gd's
# shape/bob so the two status icons read as part of the same family, with a
# different silhouette (skull) and offset so both can show at once without
# overlapping.

var _t : float = 0.0

const BOB_HEIGHT  : float   = 3.0
var _icon_offset : Vector2 = Vector2(-12, -48)
const SKULL_COLOR : Color   = Color(0.45, 0.85, 0.25, 0.95)
const EYE_COLOR   : Color   = Color(0.1, 0.2, 0.05, 0.9)

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_t += delta
	position = _icon_offset + Vector2(0, sin(_t * 4.0 + PI) * BOB_HEIGHT)
	queue_redraw()

func set_icon_offset(offset: Vector2) -> void:
	_icon_offset = offset

func _draw() -> void:
	# Simple skull: round cranium, small jaw, two eye dots.
	draw_circle(Vector2(0, -1), 5.0, SKULL_COLOR)
	var jaw := PackedVector2Array([Vector2(-3, 2), Vector2(3, 2), Vector2(2, 5), Vector2(-2, 5)])
	draw_colored_polygon(jaw, SKULL_COLOR)
	draw_circle(Vector2(-2, -1.5), 1.1, EYE_COLOR)
	draw_circle(Vector2(2, -1.5), 1.1, EYE_COLOR)
