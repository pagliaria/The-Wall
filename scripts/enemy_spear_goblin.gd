extends "res://scripts/enemy_base.gd"
# enemy_spear_goblin.gd — Spear-wielding foot soldier with two attacks.
# Normally uses the quick jab (damage lands halfway through, same approach as
# enemy_lizard.gd/enemy_minotaur.gd). Occasionally rolls the strong attack
# instead — a spear whirl windup followed by a long lunging thrust — which
# hits harder and lands on the lunge (past the halfway point, since the first
# half of that animation is the whirl, not the strike).

@export var fast_damage    : int   = 4
@export var strong_damage  : int   = 9
@export var strong_chance  : float = 0.25
@export var attack_rate    : float = 1.4
@export var engage_range   : float = 50.0

# Fraction of the strong animation's duration at which the lunge connects.
# Frames 1-3 (0-indexed) are the whirl, 4-6 the thrust, so 5/8 lands on the
# fully-extended thrust frame.
@export var strong_hit_fraction : float = 0.625

# Which attack this cycle is using. Decided in _do_attack_tick() (which plays
# the matching animation) and read back in _do_attack_hit(), since the base
# class calls the two back to back in the same frame.
var _use_strong : bool = false

func _ready() -> void:
	max_hp     = 20
	move_speed = 70.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first attack right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing an animation directly here instead would
	# create a phantom attack that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	_use_strong = _sprite.sprite_frames.has_animation("attack_strong") and randf() < strong_chance
	var anim : String = "attack_strong" if _use_strong else "attack_fast"
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)

# Hit timing lands partway through whichever animation is playing rather than
# waiting for it to finish: halfway for the jab, at the lunge for the strong.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	var anim   : String = "attack_strong" if _use_strong else "attack_fast"
	var damage : int    = strong_damage if _use_strong else fast_damage
	if _sprite.animation == anim and _sprite.sprite_frames.has_animation(anim):
		var frame_count : int   = _sprite.sprite_frames.get_frame_count(anim)
		var fps         : float = _sprite.sprite_frames.get_animation_speed(anim)
		var fraction    : float = strong_hit_fraction if _use_strong else 0.5
		await get_tree().create_timer((float(frame_count) / fps) * fraction).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if is_instance_valid(_target) and _target.hp > 0:
		CombatAudio.play(_get_attack_sound())
		_target.take_damage(damage, self)
	if _sprite.animation == anim:
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == anim:
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
