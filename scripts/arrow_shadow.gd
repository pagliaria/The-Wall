# arrow_shadow.gd
# Draws a simple dark ellipse at the arrow's ground position.
extends Node2D

func _draw() -> void:
	draw_ellipse(Vector2.ZERO, Vector2(10, 4), Color(0, 0, 0, 1))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color, steps: int = 24) -> void:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var angle := TAU * i / steps
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
