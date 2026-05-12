# badger_orb.gd
extends Area2D

const SPEED : float = 280.0

var damage  : int     = 6
var _target : Node    = null
var _dir    : Vector2 = Vector2.RIGHT
var _dead   : bool    = false
var _t      : float   = 0.0

func init(target: Node, dmg: int, start_pos: Vector2) -> void:
	damage          = dmg
	_target         = target
	global_position = start_pos
	if is_instance_valid(target):
		_dir     = (target.global_position - start_pos).normalized()
		rotation = _dir.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	z_index = 10

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.1, 0.9,  0.3,  0.18))
	draw_circle(Vector2.ZERO, 11.0, Color(0.15, 0.95, 0.35, 0.35))
	draw_circle(Vector2.ZERO,  8.0, Color(0.2,  1.0,  0.4,  0.9))
	draw_circle(Vector2.ZERO,  4.0, Color(0.6,  1.0,  0.7,  1.0))
	draw_circle(Vector2.ZERO,  2.0, Color(1.0,  1.0,  1.0,  1.0))

func _process(delta: float) -> void:
	_t += delta
	var pulse : float = 1.0 + 0.18 * sin(_t * 14.0)
	scale = Vector2(pulse, pulse)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dead:
		return

	if is_instance_valid(_target) and _target.get("hp") != null and _target.hp > 0:
		var to_target : Vector2 = (_target.global_position - global_position).normalized()
		_dir = _dir.lerp(to_target, 0.15).normalized()
	elif not is_instance_valid(_target):
		queue_free()
		return

	global_position += _dir * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if not body.has_method("take_damage"):
		return
	if body.get("faction") == "enemy":
		return
	_dead = true
	body.take_damage(damage)
	_spawn_impact()
	queue_free()

func _spawn_impact() -> void:
	var burst                      := CPUParticles2D.new()
	burst.emitting                  = true
	burst.one_shot                  = true
	burst.explosiveness             = 0.95
	burst.amount                    = 18
	burst.lifetime                  = 0.45
	burst.direction                 = Vector2.UP
	burst.spread                    = 180.0
	burst.gravity                   = Vector2(0, 120)
	burst.initial_velocity_min      = 60.0
	burst.initial_velocity_max      = 180.0
	burst.scale_amount_min          = 3.0
	burst.scale_amount_max          = 9.0
	burst.color                     = Color(0.3, 1.0, 0.45, 1.0)
	var grad                       := Gradient.new()
	grad.colors                     = PackedColorArray([Color(0.5, 1.0, 0.6, 1.0), Color(0.1, 0.5, 0.2, 0.0)])
	grad.offsets                    = PackedFloat32Array([0.0, 1.0])
	burst.color_ramp                = grad
	burst.global_position           = global_position
	get_tree().current_scene.add_child(burst)
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)
