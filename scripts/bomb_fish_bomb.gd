extends Area2D
# Bomb Fish projectile: spins through the air, lights its fuse on arrival or
# impact, then explodes and damages eligible units in its blast radius.

@export var speed : float = 280.0
@export var fuse_time : float = 0.55

var damage : int = 7
var splash_damage : int = 4
var blast_radius : float = 76.0
var _aim_point : Vector2 = Vector2.ZERO
var _direct_target : Node = null
var _owner : Node = null
var _hired : bool = false
var _launched : bool = false
var _fusing : bool = false
var _detonated : bool = false

@onready var _sprite : AnimatedSprite2D = $Sprite

func init(target: Node, direct_damage: int, nearby_damage: int, radius: float, start_pos: Vector2, fired_by_hired: bool = false, owner: Node = null) -> void:
	global_position = start_pos
	_direct_target = target
	if is_instance_valid(target):
		_aim_point = target.global_position
	else:
		_aim_point = start_pos + Vector2.RIGHT * 100.0
	damage = direct_damage
	splash_damage = nearby_damage
	blast_radius = radius
	_hired = fired_by_hired
	_owner = owner
	_launched = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	z_index = 10
	if _sprite.sprite_frames.has_animation("spin"):
		_sprite.play("spin")

func _physics_process(delta: float) -> void:
	if _detonated or _fusing or not _launched:
		return
	var remaining := global_position.distance_to(_aim_point)
	if remaining <= speed * delta:
		global_position = _aim_point
		_light_fuse()
	else:
		global_position += global_position.direction_to(_aim_point) * speed * delta

func _on_body_entered(body: Node) -> void:
	if _detonated or _fusing or not _is_valid_target(body):
		return
	_direct_target = body
	_light_fuse()

func _is_valid_target(body: Node) -> bool:
	if not is_instance_valid(body) or not body.has_method("take_damage"):
		return false
	var body_faction : String = str(body.get("faction"))
	var body_hired : bool = body.get("hired") == true
	if _hired:
		return body_faction == "enemy" and not body_hired
	return body_faction != "enemy" or body_hired

func _light_fuse() -> void:
	if _fusing or _detonated:
		return
	_fusing = true
	if _sprite.sprite_frames.has_animation("fuse"):
		_sprite.play("fuse")
	await get_tree().create_timer(fuse_time).timeout
	if is_instance_valid(self):
		_detonate()

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	var center := global_position
	var attacker : Node = _owner if is_instance_valid(_owner) else null
	for body in _get_possible_targets():
		if not _is_valid_target(body) or center.distance_to(body.global_position) > blast_radius:
			continue
		var hit_damage := splash_damage
		if body == _direct_target:
			hit_damage = damage
		body.take_damage(hit_damage, attacker)
	collision_mask = 0
	if _sprite.sprite_frames.has_animation("explode"):
		_sprite.play("explode")
		await _sprite.animation_finished
	queue_free()

func _get_possible_targets() -> Array:
	var targets : Array = []
	targets.append_array(get_tree().get_nodes_in_group("player_units"))
	targets.append_array(get_tree().get_nodes_in_group("hired_units"))
	var wave_manager := get_tree().current_scene.get_node_or_null("WaveManager")
	if wave_manager != null and wave_manager.has_method("get_enemies"):
		targets.append_array(wave_manager.get_enemies())
	return targets

func _on_lifetime_timeout() -> void:
	if not _detonated:
		queue_free()
