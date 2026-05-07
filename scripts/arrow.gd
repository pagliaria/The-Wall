# arrow.gd
# Projectile fired by the Archer.
#
# Collision (Area2D) travels in a straight line to the target — reliable hits.
# The arrow Sprite2D has a parabolic Y offset applied each frame to fake the arc.
# Rotation tracks both horizontal direction and arc velocity so it noses up
# then dips down naturally. A shadow sprite stays at ground level and shrinks
# as the arrow rises.
extends Area2D

# =========================================================================== #
#  Tuning
# =========================================================================== #

const ARC_HEIGHT  = 50.0   # pixels above ground at peak
const FLIGHT_TIME = 0.55   # seconds to reach the target

# =========================================================================== #
#  State
# =========================================================================== #

var damage     : int    = 8
var _target    : Node   = null
var _start_pos : Vector2 = Vector2.ZERO
var _end_pos   : Vector2 = Vector2.ZERO
var _t         : float  = 0.0          # 0..1 flight progress
var _duration  : float  = FLIGHT_TIME

# =========================================================================== #
#  Node refs (set in _ready after scene is built)
# =========================================================================== #

@onready var _sprite : Sprite2D = $Sprite2D
@onready var _shadow : Node2D   = $Shadow

# =========================================================================== #
#  Public init — called by archer.gd right after instantiate()
# =========================================================================== #

func init(target: Node, dmg: int) -> void:
	_target    = target
	damage     = dmg
	_start_pos = global_position
	# Aim at where the target is now; straight-line collision tracks them
	_end_pos   = target.global_position if is_instance_valid(target) else global_position + Vector2(100, 0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_pos = global_position
	# Horizontal direction for the collision body
	var dir := (_end_pos - _start_pos).normalized()
	rotation  = dir.angle()

# =========================================================================== #
#  Per-frame update
# =========================================================================== #

func _physics_process(delta: float) -> void:
	# Keep end_pos fresh while target is alive so we actually hit a moving enemy
	if is_instance_valid(_target) and _target.get("hp") != null and _target.hp > 0:
		_end_pos = _target.global_position

	_t = minf(_t + delta / _duration, 1.0)

	# --- Collision body: straight line to target ---
	var flat_pos := _start_pos.lerp(_end_pos, _t)
	global_position = flat_pos

	# --- Visual arc: parabolic height offset on the sprite ---
	# h(t) = 4 * ARC_HEIGHT * t * (1 - t)  — zero at 0 and 1, peak at 0.5
	var arc_y      := 4.0 * ARC_HEIGHT * _t * (1.0 - _t)
	_sprite.position = Vector2(0.0, -arc_y)

	# --- Rotation: face the combined flat + arc velocity direction ---
	# Flat velocity direction
	var flat_vel   := (_end_pos - _start_pos).normalized()
	# Arc vertical velocity: derivative of h(t) w.r.t. time, mapped to screen Y
	var arc_vel_y  := 4.0 * ARC_HEIGHT * (1.0 - 2.0 * _t) / _duration
	# Combine into a 3D-ish angle: flat direction with arc tilting it
	var flat_speed := (_end_pos - _start_pos).length() / _duration
	var sprite_vel := Vector2(flat_speed, -arc_vel_y)   # screen space: up = negative Y
	_sprite.rotation = sprite_vel.angle() - rotation    # offset from body rotation

	# --- Shadow: stays at ground, shrinks and fades as arrow rises ---
	var height_ratio    := arc_y / ARC_HEIGHT            # 0..1..0
	_shadow.scale       = Vector2(1.0 - height_ratio * 0.5, 1.0 - height_ratio * 0.5)
	_shadow.modulate.a  = 1.0 - height_ratio * 0.6

	# --- Update collision body rotation to face target ---
	rotation = flat_vel.angle()

	if _t >= 1.0:
		# Reached target without a collision hit (missed or target moved away)
		queue_free()

# =========================================================================== #
#  Hit
# =========================================================================== #

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
