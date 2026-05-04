extends Node2D

# Draws a selection indicator below the unit.
# Shown/hidden by pawn.gd set_selected().
# Sits at z_index 0 relative to parent so it renders above the ground
# but the sprite (also z 0, drawn after) naturally overlaps it —
# we offset it downward so the arc peeks out from under the sprite feet.

const RADIUS     = 28.0
const COLOR_FILL = Color(0.25, 0.9, 1.0, 0.20)
const COLOR_RIM  = Color(0.25, 0.9, 1.0, 1.0)
const RIM_WIDTH  = 3.0

# Offset downward so the ellipse sits at the unit's feet, visible below the sprite
const OFFSET = Vector2(0, 36)

func _draw() -> void:
	# Draw a flat ellipse to give a grounded shadow feel
	draw_set_transform(OFFSET, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, RADIUS, COLOR_FILL)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, COLOR_RIM, RIM_WIDTH, true)
	draw_set_transform(Vector2.ZERO)
