extends "res://scripts/enemy_base.gd"
# enemy_snake.gd — Fast rattlesnake skirmisher. Single-target melee bite that
# lands halfway through the lunge animation (the strike actually connects
# partway through, not once it's already settled back — same approach as
# enemy_lizard.gd/enemy_minotaur.gd), and each bite applies Poison via the
# shared apply_poison() on unit_base.gd/enemy_base.gd, same params as
# enemy_bumblebee.gd's sting.

@export var attack_damage : int   = 2
@export var attack_rate   : float = 1.5
@export var engage_range  : float = 40.0

@export var poison_damage_per_tick : int   = 1
@export var poison_tick_interval   : float = 0.6
@export var poison_duration        : float = 3.0

func _ready() -> void:
	max_hp     = 14
	move_speed = 85.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first bite right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a phantom bite that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing lands halfway through the animation (frame-count/speed gives the
# exact midpoint) rather than waiting for the whole thing to finish.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "attack1" and _sprite.sprite_frames.has_animation("attack1"):
		var frame_count   : int   = _sprite.sprite_frames.get_frame_count("attack1")
		var fps           : float = _sprite.sprite_frames.get_animation_speed("attack1")
		var half_duration : float = (float(frame_count) / fps) * 0.5
		await get_tree().create_timer(half_duration).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if is_instance_valid(_target) and _target.hp > 0:
		CombatAudio.play(_get_attack_sound())
		_target.take_damage(attack_damage, self)
		if is_instance_valid(_target) and _target.has_method("apply_poison"):
			_target.apply_poison(poison_damage_per_tick, poison_tick_interval, poison_duration, self)
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
