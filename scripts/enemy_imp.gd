extends "res://scripts/enemy_base.gd"
# enemy_imp.gd — Small flying fire-breather. Close-range channeled breath
# attack (start -> loop x N -> end) instead of a single swing or a thrown
# projectile: ticks small damage repeatedly while the breath animation loops,
# cutting short early if the target dies or flies out of range mid-channel.

@export var tick_damage  : int   = 2
@export var loop_ticks   : int   = 3
@export var attack_rate  : float = 3.0
@export var engage_range : float = 70.0

# Burning lingers a couple seconds after the breath itself stops, and gets
# refreshed (not stacked) each loop tick while still in the fire — see
# apply_burning's comment in enemy_base.gd/unit_base.gd.
@export var burn_damage_per_tick : int   = 1
@export var burn_tick_interval   : float = 0.5
@export var burn_duration        : float = 2.5

func _ready() -> void:
	max_hp     = 15
	move_speed = 90.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first breath right away instead of waiting a full attack_rate,
	# through the normal _do_attack_hit() cycle (see enemy_bear.gd for why
	# playing an animation directly here instead would create a phantom
	# swing that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	pass

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_battle_state() -> void:
	if _sprite.sprite_frames.has_animation("move"):
		_sprite.play("move")

# =========================================================================== #
#  Breath attack
# =========================================================================== #

func _do_attack_hit() -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return

	if _sprite.sprite_frames.has_animation("attack_start"):
		_sprite.play("attack_start")
		await _sprite.animation_finished
		if not is_instance_valid(self) or not is_instance_valid(_sprite):
			return

	for _i in loop_ticks:
		if not is_instance_valid(_target) or _target.hp <= 0:
			break
		if position.distance_to(_target.position) > engage_range * 1.3:
			break
		if _sprite.sprite_frames.has_animation("attack_loop"):
			_sprite.play("attack_loop")
			await _sprite.animation_finished
			if not is_instance_valid(self) or not is_instance_valid(_sprite):
				return
		if is_instance_valid(_target) and _target.hp > 0:
			CombatAudio.play(_get_attack_sound())
			_target.take_damage(tick_damage, self)
			if _target.has_method("apply_burning"):
				_target.apply_burning(burn_damage_per_tick, burn_tick_interval, burn_duration, self)

	if _sprite.sprite_frames.has_animation("attack_end"):
		_sprite.play("attack_end")
		await _sprite.animation_finished
		if not is_instance_valid(self) or not is_instance_valid(_sprite):
			return

	if _state != State.DEAD:
		_sprite.play("idle")
