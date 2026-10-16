extends "res://scripts/enemy_base.gd"
# enemy_skull.gd — Sword-and-shield skeleton. Solid mid-weight melee with a
# guard stance (Extra/Skull Guard) it occasionally drops into instead of
# attacking.
#
# Attack: the slash arc is frame 3 of 7 and the thrust lands right after, so
# the hit lands at hit_fraction (~43%) rather than a flat halfway point.
#
# Guard: each attack cycle there's a guard_chance it raises the shield
# instead of striking, holds for guard_duration, then drops it. While guarding
# all direct damage is blocked; status ticks (poison/burning/etc.) still land
# via take_damage's is_status_damage flag, same rule as enemy_minotaur.gd and
# enemy_turtle.gd. Set guard_chance to 0 to disable it.
#
# While guarding, _physics_process is short-circuited (like the pig transform
# and the turtle's shell), so the skull neither moves nor attacks nor gets
# yanked out of its stance by the state machine.

@export var attack_damage : int   = 5
@export var attack_rate   : float = 1.6
@export var engage_range  : float = 45.0

# Fraction of the attack animation at which the strike connects. Frame index 2
# is the slash arc (28%-43%), index 3 the thrust (43%-57%).
@export var hit_fraction  : float = 0.43

@export var guard_chance   : float = 0.25
@export var guard_duration : float = 1.5

var _guarding   : bool = false
var _will_guard : bool = false

func _ready() -> void:
	max_hp     = 28
	move_speed = 65.0
	super._ready()

# -- Guard -------------------------------------------------------------------

# Skips the whole state machine while guarding. Separation still runs so a
# guarding skull doesn't stack on top of its friends.
func _physics_process(delta: float) -> void:
	if _guarding and _state != State.DEAD:
		_apply_separation(delta)
		return
	super._physics_process(delta)

# Blocks everything except status-effect ticks while guarding.
func take_damage(amount: int, attacker: Node = null, is_status_damage: bool = false) -> void:
	if _guarding and not is_status_damage:
		return
	super.take_damage(amount, attacker, is_status_damage)

# The guard stance is a looping animation (there's no separate raise/lower
# pair like the turtle's shell), so it just plays for guard_duration.
func _do_guard() -> void:
	_guarding = true
	if _sprite.sprite_frames.has_animation("guard"):
		_sprite.play("guard")
	await get_tree().create_timer(guard_duration).timeout
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
	# Fire the first strike right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a phantom strike that never deals damage).
	_attack_timer = 0.0

# Decides this cycle's outcome: raise the shield or strike. The base class
# calls this and _do_attack_hit() back to back in the same frame, so the roll
# is stashed for _do_attack_hit() to act on.
func _do_attack_tick(_delta: float) -> void:
	_will_guard = guard_chance > 0.0 and _sprite.sprite_frames.has_animation("guard") and randf() < guard_chance
	if _will_guard:
		return
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Strike lands at hit_fraction of the animation (frame-count/speed gives the
# full duration) rather than waiting for the whole thing to finish.
func _do_attack_hit() -> void:
	if _will_guard:
		_will_guard = false
		_do_guard()
		return
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
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
