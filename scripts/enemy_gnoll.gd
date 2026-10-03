extends "res://scripts/enemy_base.gd"
# enemy_gnoll.gd — Ranged bone-thrower.
# Same shape as enemy_badger.gd: holds at engage_range and throws, backs off
# if shoved too close. Animation names differ (walk, not run) to match this
# pack's own asset naming.

@export var attack_damage : int   = 4
@export var attack_rate   : float = 1.8
@export var engage_range  : float = 260.0
@export var min_range     : float = 90.0

const BONE_SCENE := preload("res://scenes/gnoll_bone.tscn")

var _attack_anim_flip : bool = false
var _retreating : bool = false

func _ready() -> void:
	max_hp     = 20
	move_speed = 55.0
	super._ready()

# =========================================================================== #
#  Virtuals
# =========================================================================== #

func _get_engage_range() -> float:
	return engage_range

func _get_disengage_range() -> float:
	return engage_range * 3.0

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	pass

func _do_attacking_move(delta: float) -> void:
	if not is_instance_valid(_target):
		_retreating = false
		return

	var dist := position.distance_to(_target.position)

	if dist < min_range:
		if not _retreating:
			_retreating = true
			_sprite.play("walk")
		var away : Vector2 = (position - _target.position).normalized()
		_sprite.flip_h = away.x < 0
		move_and_collide(away * move_speed * delta)
	else:
		if _retreating:
			_retreating = false
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	_retreating = false
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_retreating = false
	_sprite.play("walk")

func _on_enter_attacking_state() -> void:
	_play_attack_anim_and_fire()

# =========================================================================== #
#  Attack
# =========================================================================== #

func _do_attack_tick(_delta: float) -> void:
	if _retreating:
		return
	_play_attack_anim_and_fire()

func _play_attack_anim_and_fire() -> void:
	if _retreating:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		return

	_sprite.flip_h = _target.global_position.x < global_position.x
	if _sprite.sprite_frames.has_animation("throw"):
		_sprite.play("throw")
	_fire_after_anim()

func _fire_after_anim() -> void:
	await _sprite.animation_finished
	if _state == State.DEAD:
		return
	if _retreating:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		_sprite.play("idle")
		return
	_throw_bone()
	_sprite.play("idle")

# =========================================================================== #
#  Bone
# =========================================================================== #

func _throw_bone() -> void:
	if not is_instance_valid(_target):
		return
	var bone   : Area2D  = BONE_SCENE.instantiate()
	var offset : Vector2 = (_target.global_position - global_position).normalized() * 24.0
	get_tree().current_scene.add_child(bone)
	bone.init(_target, attack_damage, global_position + offset, hired)
