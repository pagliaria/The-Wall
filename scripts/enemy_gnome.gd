extends "res://scripts/enemy_base.gd"
# enemy_gnome.gd — Weak melee swarm unit.
# Simple stand-and-swing melee, same shape as enemy_bear.gd minus the splash
# and knockback — just a plain spin-punch. Meant to be cheap filler thrown in
# numbers, not a threat one-on-one.

@export var attack_damage : int   = 3
@export var attack_rate   : float = 1.3
@export var engage_range  : float = 40.0

func _ready() -> void:
	max_hp     = 10
	move_speed = 70.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first swing right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a second, separate swing that never actually deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing follows the swing animation itself, not the attack_rate cooldown
# clock — see enemy_bear.gd's _do_attack_hit for why the await matters here.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if _sprite.animation == "attack1":
		_sprite.play("idle")
	if not is_instance_valid(_target) or _target.hp <= 0:
		return
	CombatAudio.play(_get_attack_sound())
	_target.take_damage(attack_damage, self)

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
