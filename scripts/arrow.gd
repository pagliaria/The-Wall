# arrow.gd
extends Area2D

const ARC_HEIGHT  = 50.0
const FLIGHT_TIME = 0.55

var damage     : int     = 8
var _target    : Node    = null
var _attacker  : Node    = null   # archer who fired — receives XP on hit
var _start_pos : Vector2 = Vector2.ZERO
var _end_pos   : Vector2 = Vector2.ZERO
var _t         : float   = 0.0
var _duration  : float   = FLIGHT_TIME

@onready var _sprite : Sprite2D = $Sprite2D
@onready var _shadow : Node2D   = $Shadow

func init(target: Node, dmg: int, attacker: Node = null) -> void:
	_target   = target
	damage    = dmg
	_attacker = attacker
	_start_pos = global_position
	_end_pos   = target.global_position if is_instance_valid(target) else global_position + Vector2(100, 0)
	CombatAudio.play("arrow")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_pos = global_position
	var dir := (_end_pos - _start_pos).normalized()
	rotation   = dir.angle()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_target) and _target.get("hp") != null and _target.hp > 0:
		_end_pos = _target.global_position

	_t = minf(_t + delta / _duration, 1.0)

	var flat_pos        := _start_pos.lerp(_end_pos, _t)
	global_position      = flat_pos

	var arc_y           := 4.0 * ARC_HEIGHT * _t * (1.0 - _t)
	_sprite.position     = Vector2(0.0, -arc_y)

	var flat_vel        := (_end_pos - _start_pos).normalized()
	var arc_vel_y       := 4.0 * ARC_HEIGHT * (1.0 - 2.0 * _t) / _duration
	var flat_speed      := (_end_pos - _start_pos).length() / _duration
	var sprite_vel      := Vector2(flat_speed, -arc_vel_y)
	_sprite.rotation     = sprite_vel.angle() - rotation

	var height_ratio    := arc_y / ARC_HEIGHT
	_shadow.scale        = Vector2(1.0 - height_ratio * 0.5, 1.0 - height_ratio * 0.5)
	_shadow.modulate.a   = 1.0 - height_ratio * 0.6

	rotation = flat_vel.angle()

	if _t >= 1.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		CombatAudio.play("arrow_hit")
		body.take_damage(damage, _attacker)
		queue_free()
