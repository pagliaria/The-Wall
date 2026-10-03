extends "res://scripts/enemy_base.gd"
# enemy_bumblebee.gd — Fast, fragile flying harasser.
# Low HP, quick to close distance, short dive-lunge into its target timed with
# the attack animation's stinger-dive pose, then a direct hit plus a poison
# DoT (apply_poison, defined on enemy_base.gd) that tints the victim green for
# its duration. All movement, targeting, and health logic lives in
# enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage : int   = 3
@export var attack_rate   : float = 1.5
@export var engage_range  : float = 40.0

# Dive lunge — a short dash into the target timed with the attack animation,
# not a full repositioning charge like Boar's.
@export var lunge_distance : float = 50.0
@export var lunge_time     : float = 0.3

# Poison sting — "a small DoT", applied alongside the direct hit.
@export var poison_damage_per_tick : int   = 1
@export var poison_tick_interval   : float = 0.6
@export var poison_duration        : float = 3.0

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 14
	move_speed    = 110.0
	patrol_radius = 180.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first sting right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a second, separate swing that never actually deals damage).
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")
	_do_lunge()

func _do_lunge() -> void:
	if not is_instance_valid(_target):
		return
	var dir : Vector2 = position.direction_to(_target.position)
	if dir == Vector2.ZERO:
		return
	var dest : Vector2 = position + dir * lunge_distance
	var tw   : Tween   = create_tween()
	tw.tween_property(self, "position", dest, lunge_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# Hit timing follows the swing animation itself, not the attack_rate cooldown
# clock — see enemy_bear.gd's _do_attack_hit for why the await matters here.
func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if _sprite.animation == "attack1":
		_sprite.play("idle")
	if not is_instance_valid(_target) or _target.hp <= 0:
		return
	CombatAudio.play(_get_attack_sound())
	_target.take_damage(attack_damage, self)
	if is_instance_valid(_target) and _target.has_method("apply_poison"):
		_target.apply_poison(poison_damage_per_tick, poison_tick_interval, poison_duration, self)

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_battle_state() -> void:
	if _sprite.sprite_frames.has_animation("move"):
		_sprite.play("move")
