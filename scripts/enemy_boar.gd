extends "res://scripts/enemy_base.gd"
# enemy_boar.gd — Melee warrior enemy.
# Charges into melee range and alternates between attack1 / attack2.
# All movement, targeting, push, and health logic lives in enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage : int   = 5
@export var attack_rate   : float = 3
@export var engage_range  : float = 48.0

# based on frames assuming 60 FPS
var SPECIAL_COOLDOWN = 0

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 20
	move_speed    = 100.0
	patrol_radius = 180.0
	super._ready()

func _do_special() -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return
	var charge_target : Node    = _target
	var charge_dir    : Vector2 = (charge_target.position - position).normalized()
	var charge_dest   : Vector2 = charge_target.position - charge_dir * (engage_range * 0.5)
	var charge_dist   : float   = position.distance_to(charge_dest)
	var charge_time   : float   = charge_dist / 600.0  # fast lunge
	charge_time = clampf(charge_time, 0.08, 0.4)
	# Flip sprite toward target
	_sprite.flip_h = charge_dir.x < 0
	# Tween boar rapidly toward target
	var tw : Tween = create_tween()
	tw.tween_property(self, "position", charge_dest, charge_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	# Deal damage and knock target back if still valid
	if not is_instance_valid(charge_target) or charge_target.hp <= 0:
		return
	CombatAudio.play("enemy_attack")
	charge_target.take_damage(attack_damage)
	if is_instance_valid(charge_target):
		var kb_dir  : Vector2 = (charge_target.position - position).normalized()
		var kb_dest : Vector2 = charge_target.position + kb_dir * 160.0
		var kb_tw   : Tween   = charge_target.create_tween()
		kb_tw.tween_property(charge_target, "position", kb_dest, 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# -- Virtual overrides -------------------------------------------------------
func _move() -> void:
	SPECIAL_COOLDOWN -= 1
	if SPECIAL_COOLDOWN <= 0:
		SPECIAL_COOLDOWN = 120
		_sprite.play("attack1")
		_do_special()
		await _sprite.animation_finished
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
