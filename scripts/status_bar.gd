extends Node2D
class_name StatusBar
## Compact row of status badges anchored above a unit's health bar.
## Add new effects with set_status(id, color); unknown ids get a sparkle glyph.

const BADGE_RADIUS := 8.0
const BADGE_GAP := 20.0

var _statuses: Dictionary = {}

func set_status(status_id: StringName, color: Color) -> void:
	_statuses[status_id] = color
	queue_redraw()

func clear_status(status_id: StringName) -> void:
	if _statuses.erase(status_id):
		queue_redraw()

func has_statuses() -> bool:
	return not _statuses.is_empty()

func _draw() -> void:
	var ids := _statuses.keys()
	var row_width := maxf(0.0, float(ids.size() - 1) * BADGE_GAP)
	for index in ids.size():
		var center := Vector2(float(index) * BADGE_GAP - row_width * 0.5, 0.0)
		var color: Color = _statuses[ids[index]]
		draw_circle(center + Vector2(0.0, 1.0), BADGE_RADIUS + 1.0, Color(0.04, 0.05, 0.08, 0.9))
		draw_circle(center, BADGE_RADIUS, color.darkened(0.48))
		draw_arc(center, BADGE_RADIUS - 0.4, 0.0, TAU, 24, color.lightened(0.22), 1.5, true)
		_draw_glyph(center, StringName(ids[index]), color.lightened(0.3))

func _draw_glyph(center: Vector2, status_id: StringName, color: Color) -> void:
	match status_id:
		&"poison":
			draw_circle(center + Vector2(0.0, -1.0), 3.2, color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-2.4, 0.5), center + Vector2(2.4, 0.5),
				center + Vector2(1.8, 4.0), center + Vector2(-1.8, 4.0)
			]), color)
			draw_circle(center + Vector2(-1.2, -1.0), 0.65, Color(0.12, 0.16, 0.08))
			draw_circle(center + Vector2(1.2, -1.0), 0.65, Color(0.12, 0.16, 0.08))
		&"wet":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -5.0), center + Vector2(4.0, 0.0),
				center + Vector2(3.0, 3.0), center + Vector2(0.0, 4.5),
				center + Vector2(-3.0, 3.0), center + Vector2(-4.0, 0.0)
			]), color)
			draw_circle(center + Vector2(-1.4, 0.3), 1.0, Color(1.0, 1.0, 1.0, 0.72))
		_:
			draw_line(center + Vector2(0.0, -4.0), center + Vector2(0.0, 4.0), color, 1.8, true)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), color, 1.8, true)
			draw_line(center + Vector2(-2.8, -2.8), center + Vector2(2.8, 2.8), color, 1.2, true)
			draw_line(center + Vector2(-2.8, 2.8), center + Vector2(2.8, -2.8), color, 1.2, true)
