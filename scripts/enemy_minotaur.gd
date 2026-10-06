extends "res://scripts/enemy_base.gd"
# enemy_minotaur.gd — Heavy melee brute with a two-handed hammer. Standard
# single-target melee (no splash/knockback, unlike enemy_bear.gd), but like
# enemy_lizard.gd, damage lands halfway through the swing instead of waiting
# for the whole animation to finish — the hammer actually connects partway
# through (the swipe-arc frames), not at the very end once it's already
# recovered.

@export var attack_damage : int   = 10
@export var attack_rate   : float = 2.2
@export var engage_range  : float = 50.0

# Guard — occasionally blocks instead of swinging. While guarding, all direct
# damage is negated; only status-effect ticks (poison/burning) still land,
# since those are passed through take_damage() with is_status_damage = true.
@export var guard_chance   : float = 0.3
@export var guard_duration : float = 2.0

var _guarding : bool = false

func _ready() -> void:
	max_hp     = 50
	move_speed = 55.0
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
# see enemy_lizard.gd's _do_attack_hit for the same approach.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	# Occasionally guard instead of swinging this cycle — no attack happens at
	# all, the hammer just comes up to block. Only rolls when not already
	# guarding, so this can't re-trigger mid-guard and extend it indefinitely.
	if not _guarding and _sprite.sprite_frames.has_animation("guard") and randf() < guard_chance:
		_guarding = true
		_sprite.play("guard")
		await get_tree().create_timer(guard_duration).timeout
		if not is_instance_valid(self) or not is_instance_valid(_sprite):
			return
		_guarding = false
		if _state != State.DEAD and _sprite.animation == "guard":
			_sprite.play("idle")
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
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

# Guard blocks all direct damage (attacker hits, friendly-fire-filtered or
# not) but status-effect ticks (poison/burning) still get through — those
# call take_damage with is_status_damage = true precisely so a status can't
# be stonewalled by timing a guard window right.
func take_damage(amount: int, attacker: Node = null, is_status_damage: bool = false) -> void:
	if _guarding and not is_status_damage:
		return
	super.take_damage(amount, attacker, is_status_damage)
