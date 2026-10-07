extends "res://scripts/enemy_base.gd"
# enemy_panda.gd — Nunchuck-wielding spin attacker. Unlike a single-hit swing,
# the attack animation's middle section (frames 6-10 of 13, 1-indexed — a
# zero-indexed array that's indices 5-9) is the actual spin, so damage lands
# as a burst of 5 small self-centred AoE ticks spaced across that window
# instead of one hit at a fixed point, matching the sustained spinning sweep
# visually.

@export var tick_damage  : int   = 2
@export var num_ticks    : int   = 5
@export var aoe_radius   : float = 65.0
@export var attack_rate  : float = 2.2
@export var engage_range : float = 50.0

func _ready() -> void:
	max_hp     = 26
	move_speed = 65.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first spin right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a phantom spin that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Ticks damage num_ticks times, one per frame, starting at the windup's end
# (frame 6, 1-indexed) through the spin (frame 10) — the windup (frames 1-5)
# and recovery (frames 11-13) deal nothing.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "attack1" and _sprite.sprite_frames.has_animation("attack1"):
		var fps        : float = _sprite.sprite_frames.get_animation_speed("attack1")
		var frame_time : float = 1.0 / fps
		# Frame 6 (1-indexed) is array index 5 — five frames of windup already
		# played before the spin's first tick should land.
		await get_tree().create_timer(frame_time * 5.0).timeout
		if not is_instance_valid(self) or not is_instance_valid(_sprite):
			return
		for _i in num_ticks:
			if not is_instance_valid(self) or _state == State.DEAD:
				return
			CombatAudio.play(_get_attack_sound())
			for u in _get_battle_targets():
				if not is_instance_valid(u) or u.hp <= 0:
					continue
				if position.distance_to(u.position) <= aoe_radius:
					u.take_damage(tick_damage, self)
			await get_tree().create_timer(frame_time).timeout
			if not is_instance_valid(self) or not is_instance_valid(_sprite):
				return
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
