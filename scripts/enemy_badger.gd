extends "res://scripts/enemy_base.gd"
# enemy_badger.gd — Ranged magical enemy.
# Stands at engage_range and fires green orbs. Backs up if shoved too close.

@export var attack_damage : int   = 1
@export var attack_rate   : float = 2
@export var engage_range  : float = 1000
@export var min_range     : float = 80.0

const ORB_SCENE := preload("res://scenes/badger_orb.tscn")

var _attack_anim_flip : bool = false

func _ready() -> void:
	max_hp     = 22
	move_speed = 50.0
	super._ready()

# =========================================================================== #
#  Virtuals
# =========================================================================== #

func _get_engage_range() -> float:
	return engage_range

func _get_disengage_range() -> float:
	return engage_range * 10.0

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	pass   # damage via orb only

func _do_attacking_move(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var dist := position.distance_to(_target.position)
	if dist < min_range:
		var away : Vector2 = (position - _target.position).normalized()
		_sprite.flip_h = away.x < 0
		move_and_collide(away * move_speed * delta)

func _on_enter_idle_state() -> void:
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_sprite.play("run")

func _on_enter_attacking_state() -> void:
	_play_attack_anim_and_fire()

# =========================================================================== #
#  Attack
# =========================================================================== #

func _do_attack_tick(_delta: float) -> void:
	_play_attack_anim_and_fire()

func _play_attack_anim_and_fire() -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return

	_sprite.flip_h    = _target.global_position.x < global_position.x
	_attack_anim_flip = not _attack_anim_flip
	var anim          := "attack1" if _attack_anim_flip else "attack2"
	if not _sprite.sprite_frames.has_animation(anim):
		anim = "attack1"

	_sprite.play(anim)
	_fire_after_anim()

func _fire_after_anim() -> void:
	await _sprite.animation_finished
	if _state == State.DEAD:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		_sprite.play("idle")
		return
	_launch_orb()
	_sprite.play("idle")

# =========================================================================== #
#  Orb
# =========================================================================== #

func _launch_orb() -> void:
	if not is_instance_valid(_target):
		return
	var orb : Area2D = ORB_SCENE.instantiate()
	var offset       : Vector2 = (_target.global_position - global_position).normalized() * 24.0
	get_tree().current_scene.add_child(orb)
	orb.init(_target, attack_damage, global_position + offset)
