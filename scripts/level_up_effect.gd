# level_up_effect.gd
extends Node2D

func play(world_pos: Vector2) -> void:
	global_position = world_pos
	_spawn_burst()
	await get_tree().create_timer(1.2).timeout
	queue_free()

func _spawn_burst() -> void:
	var burst               := CPUParticles2D.new()
	burst.emitting           = true
	burst.one_shot           = true
	burst.explosiveness      = 0.95
	burst.amount             = 24
	burst.lifetime           = 0.8
	burst.direction          = Vector2.UP
	burst.spread             = 180.0
	burst.gravity            = Vector2(0, -30)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 120.0
	burst.scale_amount_min   = 3.0
	burst.scale_amount_max   = 7.0
	burst.color              = Color(1.0, 0.85, 0.2, 1.0)
	var grad                := Gradient.new()
	grad.colors              = PackedColorArray([Color(1.0, 0.95, 0.4, 1.0), Color(1.0, 0.7, 0.1, 0.0)])
	grad.offsets             = PackedFloat32Array([0.0, 1.0])
	burst.color_ramp         = grad
	add_child(burst)

	var sparkles               := CPUParticles2D.new()
	sparkles.emitting           = true
	sparkles.one_shot           = true
	sparkles.explosiveness      = 0.6
	sparkles.amount             = 12
	sparkles.lifetime           = 1.0
	sparkles.direction          = Vector2.UP
	sparkles.spread             = 30.0
	sparkles.gravity            = Vector2(0, -60)
	sparkles.initial_velocity_min = 20.0
	sparkles.initial_velocity_max = 80.0
	sparkles.scale_amount_min   = 2.0
	sparkles.scale_amount_max   = 4.0
	sparkles.color              = Color(1.0, 1.0, 0.6, 1.0)
	var grad2                  := Gradient.new()
	grad2.colors                = PackedColorArray([Color(1.0, 1.0, 0.7, 1.0), Color(1.0, 0.9, 0.3, 0.0)])
	grad2.offsets               = PackedFloat32Array([0.0, 1.0])
	sparkles.color_ramp         = grad2
	add_child(sparkles)
