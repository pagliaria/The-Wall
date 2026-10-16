extends "res://scripts/enemy_base.gd"
# enemy_turtle.gd — Slow, very tanky, very weak. A plodding damage sponge:
# lots of HP, a bite that barely scratches, and a shell it occasionally
# withdraws into (Extra/Turtle Guard) to become immune to direct damage.
#
# Bite: the neck snaps out starting at frame 6 of 10, so the hit lands at the
# halfway point (same approach as enemy_lizard.gd/enemy_minotaur.gd).
#
# Guard: each attack cycle there's a guard_chance it withdraws into its shell
# instead of biting — shell closes (guard_in), holds for guard_duration, then
# emerges (guard_out). While in the shell all direct damage is blocked; status
# ticks (poison/burning/etc.) still land via take_damage's is_status_damage
# flag, same rule as enemy_minotaur.gd. Set guard_chance to 0 to disable it.
#
# While guarding, _physics_process is short-circuited (like the pig
# transform), so the turtle neither moves nor attacks nor gets yanked out of
# its shell animation by the state machine — it just sits there as a shell.

@export var attack_damage : int   = 2
@export var attack_rate   : float = 2.0
@export var engage_range  : float = 55.0

@export var guard_chance   : float = 0.3
@export var guard_duration : float = 1.5

var _guarding   : bool = false
var _will_guard : bool = false

func _ready() -> void:
	max_hp     = 60
	move_speed = 35.0
	super._ready()

# -- Guard -------------------------------------------------------------------

# Skips the whole state machine while in the shell. Separation still runs so a
# shelled turtle doesn't stack on top of its friends.
func _physics_process(delta: float) -> void:
	if _guarding and _state != State.DEAD:
		_apply_separation(delta)
		return
	super._physics_process(delta)

# Blocks everything except status-effect ticks while in the shell.
func take_damage(amount: int, attacker: Node = null, is_status_damage: bool = false) -> void:
	if _guarding and not is_status_damage:
		return
	super.take_damage(amount, attacker, is_status_damage)

func _do_guard() -> void:
	_guarding = true
	if _sprite.sprite_frames.has_animation("guard_in"):
		_sprite.play("guard_in")
		await _sprite.animation_finished
		if not is_instance_valid(self) or _state == State.DEAD:
			return
	# Hold on guard_in's last frame (closed shell — non-looping animations stay
	# on their final frame), then come back out.
	await get_tree().create_timer(guard_duration).timeout
	if not is_instance_valid(self) or _state == State.DEAD:
		return
	if _sprite.sprite_frames.has_animation("guard_out"):
		_sprite.play("guard_out")
		await _sprite.animation_finished
		if not is_instance_valid(self) or _state == State.DEAD:
			return
	_guarding = false
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

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

# Decides this cycle's outcome: withdraw into the shell or bite. The base class
# calls this and _do_attack_hit() back to back in the same frame, so the roll
# is stashed for _do_attack_hit() to act on.
func _do_attack_tick(_delta: float) -> void:
	_will_guard = guard_chance > 0.0 and _sprite.sprite_frames.has_animation("guard_in") and randf() < guard_chance
	if _will_guard:
		return
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Bite lands halfway through the animation (frame-count/speed gives the exact
# midpoint) rather than waiting for the whole thing to finish.
func _do_attack_hit() -> void:
	if _will_guard:
		_will_guard = false
		_do_guard()
		return
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
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
