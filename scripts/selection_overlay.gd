extends Node2D

# Draws the drag-selection rectangle in screen space.
# Parent must be a CanvasLayer so it renders on top of everything.

func _draw() -> void:
	var sel : Node = get_parent().get_parent()   # Draw → Overlay → UnitSelection
	if not sel._pressing or not sel._drag_active:
		return

	var rect := Rect2(sel._press_screen, sel._drag_end - sel._press_screen).abs()

	draw_rect(rect, Color(0.3, 0.85, 1.0, 0.08), true)
	draw_rect(rect, Color(0.3, 0.85, 1.0, 0.70), false, 1.5)
