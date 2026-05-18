extends "res://scripts/enemy_base.gd"
# enemy_boar.gd — Melee warrior enemy.
# Charges into melee range and alternates between attack1 / attack2.
# All movement, targeting, push, and health logic lives in enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage : int   = 5
@export var attack_rate   : float = 3
@export var engage_range  : float = 48.0

# based on frames assuming 60 FPS
var SPECIAL_COOLDOWN = 120

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 20
	move_speed    = 100.0
	patrol_radius = 180.0
	super._ready()

func _do_special() -> void:
	#TODO
	pass

# -- Virtual overrides -------------------------------------------------------
func _move() -> void:
	SPECIAL_COOLDOWN -= 1
	if SPECIAL_COOLDOWN <= 0 and not State.ATTACKING:
		SPECIAL_COOLDOWN = 120
		_sprite.play("attack1")
		await _sprite.animation_finished
		_do_special()
		_sprite.play("run")
		print("Boar Special")
	pass

func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	if is_instance_valid(_target):
		CombatAudio.play("enemy_attack_slime")
		_target.take_damage(attack_damage)

func _on_enter_idle_state() -> void:
	# Alternate between idle and guard for visual variety.
	var anim := "guard" if _rng.randf() > 0.5 else "idle"
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	elif _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_attacking_state() -> void:
	_do_attack_tick(0)

func _do_attack_tick(_delta: float) -> void:
	var anim := "attack1" if _rng.randf() > 0.5 else "attack2"
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		await _sprite.animation_finished
		_sprite.play("idle")
