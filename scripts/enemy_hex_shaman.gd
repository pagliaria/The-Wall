extends "res://scripts/enemy_base.gd"
# enemy_hex_shaman.gd — Ranged curse-caster. Same thrower shape as
# enemy_gnoll.gd/enemy_harpoon_shark.gd (hold at range, back off if pushed
# close), but attack_damage is always 0 — this unit never deals direct
# damage. Its orb (hex_orb_projectile.gd) occasionally transforms whatever it
# hits into a harmless pig instead.

@export var attack_rate  : float = 2.2
@export var engage_range : float = 260.0
@export var min_range    : float = 100.0

const HEX_ORB_SCENE := preload("res://scenes/hex_orb_projectile.tscn")

var _retreating : bool = false

func _ready() -> void:
	max_hp     = 16
	move_speed = 48.0
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
			_sprite.play("run")
		var away : Vector2 = (position - _target.position).normalized()
		_sprite.flip_h = away.x < 0
		move_and_collide(away * move_speed * _status_speed_mult * delta)
	else:
		if _retreating:
			_retreating = false
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	_retreating = false
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_retreating = false
	_sprite.play("run")

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
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")
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
	_cast_hex()
	_sprite.play("idle")

# =========================================================================== #
#  Hex orb
# =========================================================================== #

func _cast_hex() -> void:
	if not is_instance_valid(_target):
		return
	var orb    : Area2D  = HEX_ORB_SCENE.instantiate()
	var offset : Vector2 = (_target.global_position - global_position).normalized() * 24.0
	get_tree().current_scene.add_child(orb)
	orb.init(_target, global_position + offset, hired)
