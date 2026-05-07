extends "res://scripts/enemy_base.gd"
# enemy_warrior.gd — Melee warrior enemy.
# Charges into melee range and alternates between attack1 / attack2.
# All movement, targeting, push, and health logic lives in enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage : int   = 4
@export var attack_rate   : float = 1.2
@export var engage_range  : float = 48.0

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 18
	move_speed    = 55.0
	patrol_radius = 180.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------

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
	var anim := "attack1" if _rng.randf() > 0.5 else "attack2"
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)

func _do_attack_tick(_delta: float) -> void:
	# Replay attack anim when it finishes so it loops visually.
	if not _sprite.is_playing():
		var anim := "attack1" if _rng.randf() > 0.5 else "attack2"
		if _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)
