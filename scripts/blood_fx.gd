# blood_fx.gd
# Autoload — spawns smooth anti-aliased blood droplets at world positions.
# Also leaves persistent ground splats that last until clear_splats() is called.

extends Node

enum BloodLevel { NONE, LIGHT, NORMAL, HEAVY, INSANE }

const DROP_COUNTS : Dictionary = {
	BloodLevel.NONE:   [0,  0 ],
	BloodLevel.LIGHT:  [2,  4 ],
	BloodLevel.NORMAL: [4,  8 ],
	BloodLevel.HEAVY:  [8,  16],
	BloodLevel.INSANE: [16, 32],
}

const SPLAT_SIZES : Dictionary = {
	BloodLevel.NONE:   [0.0,  0.0 ],
	BloodLevel.LIGHT:  [4.0,  8.0 ],
	BloodLevel.NORMAL: [8.0,  18.0],
	BloodLevel.HEAVY:  [14.0, 28.0],
	BloodLevel.INSANE: [20.0, 40.0],
}

const LARGE_THRESH : int   = 8
const COLOR_BRIGHT : Color = Color(0.92, 0.08, 0.08, 1.0)
const COLOR_DARK   : Color = Color(0.55, 0.03, 0.03, 1.0)
const COLOR_SPLAT  : Color = Color(0.45, 0.02, 0.02, 0.85)

var level   : BloodLevel = BloodLevel.NORMAL
var enabled : bool       = true
var _splats : Array      = []

# =========================================================================== #
#  Public API
# =========================================================================== #

func show_blood(world_pos: Vector2, amount: int = 1) -> void:
	if not enabled or level == BloodLevel.NONE:
		return
	var counts : Array = DROP_COUNTS[level]
	var count  : int   = counts[1] if amount >= LARGE_THRESH else counts[0]
	for i in count:
		_spawn_drop(world_pos, amount)
	_spawn_splat(world_pos, amount)

func clear_splats() -> void:
	for splat in _splats:
		if is_instance_valid(splat):
			var tw : Tween = splat.create_tween()
			tw.tween_property(splat, "modulate:a", 0.0, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(splat.queue_free)
	_splats.clear()

# =========================================================================== #
#  Droplets — fly outward and disappear
# =========================================================================== #

func _spawn_drop(origin: Vector2, amount: int) -> void:
	var drop := _BloodDrop.new()
	drop.origin = origin
	drop.radius = randf_range(2.5, 5.5) if amount >= LARGE_THRESH else randf_range(1.5, 3.5)
	drop.color  = COLOR_BRIGHT.lerp(COLOR_DARK, randf())
	get_tree().current_scene.add_child(drop)
	drop.launch()

# =========================================================================== #
#  Splats — flat ellipses that stay on the ground
# =========================================================================== #

func _spawn_splat(origin: Vector2, amount: int) -> void:
	var sizes  : Array = SPLAT_SIZES[level]
	if sizes[1] <= 0.0:
		return
	var splat := _BloodSplat.new()
	splat.origin  = origin
	splat.radius  = randf_range(sizes[0], sizes[1])
	splat.color   = COLOR_SPLAT
	splat.z_index = 2
	get_tree().current_scene.add_child(splat)
	_splats.append(splat)
	splat.appear()

# =========================================================================== #
#  Inner class — flying droplet
# =========================================================================== #

class _BloodDrop extends Node2D:
	var origin : Vector2 = Vector2.ZERO
	var radius : float   = 3.0
	var color  : Color   = Color(0.9, 0.05, 0.05, 1.0)
	var _alpha : float   = 1.0

	func launch() -> void:
		position = origin
		z_index  = 15
		var angle : float   = randf() * TAU
		var speed : float   = randf_range(40.0, 120.0)
		var dest  : Vector2 = position + Vector2(cos(angle), sin(angle)) * speed * randf_range(0.3, 1.0)
		var dur   : float   = randf_range(0.25, 0.5)
		var tw    := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position", dest, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_alpha, 1.0, 0.0, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(queue_free)

	func _set_alpha(a: float) -> void:
		_alpha = a
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, _alpha))
		draw_circle(Vector2.ZERO, radius * 0.55, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, _alpha * 0.8))

# =========================================================================== #
#  Inner class — persistent ground splat
# =========================================================================== #

class _BloodSplat extends Node2D:
	var origin : Vector2 = Vector2.ZERO
	var radius : float   = 10.0
	var color  : Color   = Color(0.45, 0.02, 0.02, 0.85)
	var _alpha : float   = 0.0
	var _squash : float  = randf_range(0.25, 0.4)  # flat ellipse Y scale

	func appear() -> void:
		position = origin + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
		var tw := create_tween()
		tw.tween_method(_set_alpha, 0.0, color.a, 0.15)
		tw.tween_callback(queue_redraw)

	func _set_alpha(a: float) -> void:
		_alpha = a
		queue_redraw()

	func _draw() -> void:
		# Flat ellipse — same trick as selection_circle.gd
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, _squash))
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, _alpha))
		# Slightly darker blob on top
		draw_circle(Vector2.ZERO, radius * 0.5, Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, _alpha * 0.9))
		draw_set_transform(Vector2.ZERO)
