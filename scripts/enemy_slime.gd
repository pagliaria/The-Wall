extends "res://scripts/enemy_base.gd"
# enemy_slime.gd — Melee warrior enemy.
# Charges into melee range and alternates between attack1 / attack2.
# All movement, targeting, push, and health logic lives in enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage : int   = 1
@export var attack_rate   : float = 1.5
@export var engage_range  : float = 48.0

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 5
	move_speed    = 100.0
	patrol_radius = 180.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------

func _move() -> void:
	if _rng.randf() > 0.8:
		print("Slime Special")
	pass

func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	if is_instance_valid(_target):
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
