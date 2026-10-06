extends "res://scripts/enemy_base.gd"
# enemy_lizard.gd — Frilled display attacker. The attack animation flares a
# big spiked collar rather than a swipe or bite, so the hit is a self-centred
# AoE burst: everything within aoe_radius of the lizard itself takes damage
# at once when the frill reaches full flare, not just whichever unit happened
# to be the nominal target.
#
# Also wires in Lizard_Hit (Extra/Lizard Hit), a dedicated 2-frame flinch this
# pack ships that nothing has used yet — every other enemy just relies on the
# generic red flash from flash_red(). Only plays outside ATTACKING: swapping
# animation mid-swing would hijack the attack_hit() await below, which just
# waits on the next animation_finished signal regardless of which animation
# it came from.

@export var aoe_damage   : int   = 5
@export var aoe_radius   : float = 70.0
@export var attack_rate  : float = 2.0
@export var engage_range : float = 55.0

func _ready() -> void:
	max_hp     = 18
	move_speed = 65.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first flare right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a phantom flare that never deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing lands at the flare's peak (halfway through the animation —
# frame-count/speed gives the exact midpoint) rather than waiting for the
# whole open-then-close sequence to finish, since the frill is only actually
# "out" partway through. The closing half still plays out afterward before
# swapping back to idle, just without anything gating on it.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "attack1" and _sprite.sprite_frames.has_animation("attack1"):
		var frame_count : int   = _sprite.sprite_frames.get_frame_count("attack1")
		var fps          : float = _sprite.sprite_frames.get_animation_speed("attack1")
		var half_duration : float = (float(frame_count) / fps) * 0.5
		await get_tree().create_timer(half_duration).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	CombatAudio.play(_get_attack_sound())
	for u in _get_battle_targets():
		if not is_instance_valid(u) or u.hp <= 0:
			continue
		if position.distance_to(u.position) <= aoe_radius:
			u.take_damage(aoe_damage, self)
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

# -- Hit flinch ---------------------------------------------------------------
func flash_red() -> void:
	if _state == State.ATTACKING or _state == State.DEAD or not _sprite.sprite_frames.has_animation("hit"):
		super.flash_red()
		return
	var prev_anim : String = _sprite.animation
	_sprite.play("hit")
	await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if _state != State.ATTACKING and _state != State.DEAD and _sprite.animation == "hit":
		_sprite.play(prev_anim if _sprite.sprite_frames.has_animation(prev_anim) else "idle")
