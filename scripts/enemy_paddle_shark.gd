extends "res://scripts/enemy_base.gd"
# enemy_paddle_shark.gd — Melee brawler swinging a wooden paddle/club. Like
# enemy_minotaur.gd, damage lands halfway through the swing instead of
# waiting for the whole animation to finish. Being a water creature, each hit
# also applies the Wet status (same params as enemy_harpoon_shark.gd, for
# consistency across the water-enemy family).

@export var attack_damage : int   = 6
@export var attack_rate   : float = 1.6
@export var engage_range  : float = 45.0

# Wet on hit — same "a little" slow as Harpoon Shark's splash.
const WET_SPEED_MULT  : float = 0.82
const WET_ATTACK_MULT : float = 1.2
const WET_DURATION    : float = 3.0

func _ready() -> void:
	max_hp     = 24
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
	# create a phantom swing that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing lands halfway through the swing (frame-count/speed gives the
# exact midpoint) rather than waiting for the whole animation to finish —
# see enemy_lizard.gd/enemy_minotaur.gd's _do_attack_hit for the same
# approach.
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
		if _target.has_method("apply_wet"):
			_target.apply_wet(WET_SPEED_MULT, WET_ATTACK_MULT, WET_DURATION)
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
