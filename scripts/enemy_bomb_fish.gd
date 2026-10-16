extends "res://scripts/enemy_base.gd"
# Ranged bomber that blasts the target and nearby units.

@export var attack_damage : int = 7
@export var splash_damage : int = 4
@export var splash_radius : float = 76.0
@export var attack_rate : float = 2.2
@export var engage_range : float = 260.0
@export var min_range : float = 90.0
const BOMB_SCENE : PackedScene = preload("res://scenes/bomb_fish_bomb.tscn")
var _retreating : bool = false

func _ready() -> void:
	max_hp = 24
	move_speed = 52.0
	super._ready()

func _get_engage_range() -> float:
	return engage_range

func _get_disengage_range() -> float:
	return engage_range * 3.0

func _get_attack_rate() -> float:
	return attack_rate

func _do_attacking_move(delta: float) -> void:
	if not is_instance_valid(_target):
		_retreating = false
		return
	if position.distance_to(_target.position) < min_range:
		_retreating = true
		if _sprite.animation != "run":
			_sprite.play("run")
		var away : Vector2 = (position - _target.position).normalized()
		_sprite.flip_h = away.x < 0
		move_and_collide(away * move_speed * _status_speed_mult * delta)
	else:
		_retreating = false
		if _sprite.animation == "run":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	_retreating = false
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_retreating = false
	_sprite.play("run")

func _on_enter_attacking_state() -> void:
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _retreating or not is_instance_valid(_target) or _target.hp <= 0:
		return
	_sprite.flip_h = _target.global_position.x < global_position.x
	_sprite.play("shoot")

func _do_attack_hit() -> void:
	if _retreating or not is_instance_valid(_target):
		return
	if _sprite.animation == "shoot":
		var frame_count := _sprite.sprite_frames.get_frame_count("shoot")
		var fps := _sprite.sprite_frames.get_animation_speed("shoot")
		await get_tree().create_timer(float(frame_count) / fps * 0.75).timeout
	if not is_instance_valid(self) or _state == State.DEAD or not is_instance_valid(_target) or _target.hp <= 0:
		return
	CombatAudio.play(_get_attack_sound())
	var bomb : Area2D = BOMB_SCENE.instantiate()
	get_tree().current_scene.add_child(bomb)
	bomb.init(_target, attack_damage, splash_damage, splash_radius, global_position, hired, self)
	if is_instance_valid(_sprite) and _sprite.animation == "shoot":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "shoot":
			_sprite.play("idle")
