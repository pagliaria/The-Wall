extends Node2D
# wet_droplet_fx.gd — small bobbing water-droplet indicator shown above a unit
# while the Wet status (unit_base.gd / enemy_base.gd apply_wet) is active.
# Purely visual, no gameplay logic of its own.

var _t : float = 0.0

const BOB_HEIGHT  : float   = 3.0
const BASE_OFFSET : Vector2 = Vector2(12, -48)
const DROP_COLOR  : Color   = Color(0.35, 0.65, 1.0, 0.9)
const HIGHLIGHT    : Color  = Color(1.0, 1.0, 1.0, 0.65)

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_t += delta
	position = BASE_OFFSET + Vector2(0, sin(_t * 4.0) * BOB_HEIGHT)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 2), 5.0, DROP_COLOR)
	var pts := PackedVector2Array([Vector2(-3, 2), Vector2(3, 2), Vector2(0, -7)])
	draw_colored_polygon(pts, DROP_COLOR)
	draw_circle(Vector2(-1.5, 0.5), 1.4, HIGHLIGHT)
