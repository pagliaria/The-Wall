extends "res://scripts/enemy_base.gd"
# enemy_torch_goblin.gd — Torch-swinging melee skirmisher. The swing lands
# early in the animation (the big flaming arc is frame 3 of 8, well before the
# halfway point — the second half is just embers and recovery), so the hit is
# timed to hit_fraction rather than a flat 50%. Each hit also sets the target
# on fire via the shared apply_burning() on unit_base.gd/enemy_base.gd, same
# params as enemy_imp.gd's breath lingers.

@export var attack_damage : int   = 4
@export var attack_rate   : float = 1.7
@export var engage_range  : float = 45.0

# Fraction of the attack animation at which the swing connects. The flame arc
# is frame index 2 of 8 (25%-37.5%), so 0.375 lands as it finishes sweeping.
@export var hit_fraction  : float = 0.375

@export var burn_damage_per_tick : int   = 1
@export var burn_tick_interval   : float = 0.5
@export var burn_duration        : float = 3.0

func _ready() -> void:
	max_hp     = 22
	move_speed = 68.0
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
	# create a phantom swing that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing lands at hit_fraction of the swing (frame-count/speed gives the
# full duration) rather than waiting for the whole animation to finish.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "attack1" and _sprite.sprite_frames.has_animation("attack1"):
		var frame_count : int   = _sprite.sprite_frames.get_frame_count("attack1")
		var fps         : float = _sprite.sprite_frames.get_animation_speed("attack1")
		await get_tree().create_timer((float(frame_count) / fps) * hit_fraction).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if is_instance_valid(_target) and _target.hp > 0:
		CombatAudio.play(_get_attack_sound())
		_target.take_damage(attack_damage, self)
		if is_instance_valid(_target) and _target.has_method("apply_burning"):
			_target.apply_burning(burn_damage_per_tick, burn_tick_interval, burn_duration, self)
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
