# arrow.gd
# Projectile fired by the Archer. Homes weakly on a target node.
# Deals damage and frees itself on hitting an enemy Area2D, or
# after travelling MAX_RANGE pixels.
extends Area2D

const SPEED     = 400.0
const MAX_RANGE = 600.0

var damage      : int  = 8
var _target     : Node = null
var _travelled  : float = 0.0
var _direction  : Vector2 = Vector2.RIGHT

func init(target: Node, dir: Vector2, dmg: int) -> void:
	_target   = target
	_direction = dir.normalized()
	damage    = dmg
	rotation  = _direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Gently steer toward the target if it's still alive
	if is_instance_valid(_target) and _target.get("hp") != null and _target.hp > 0:
		var to_target : Vector2 = (_target.position - position).normalized()
		_direction    = _direction.lerp(to_target, 0.08).normalized()
		rotation      = _direction.angle()

	var step := _direction * SPEED * delta
	position     += step
	_travelled   += step.length()

	if _travelled >= MAX_RANGE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Hit an enemy
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
