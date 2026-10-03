extends "res://scripts/enemy_base.gd"
# enemy_bear.gd — Heavy melee brute.
# Standard stand-and-swing melee like enemy_skeleton.gd, but each hit also
# splashes reduced damage to anything else near the main target and knocks
# whatever it connects with back a short distance.
# All movement, targeting, push, and health logic lives in enemy_base.gd.

# Stats — set here as defaults; can also be tweaked per-scene in the inspector.
@export var attack_damage      : int   = 7
@export var attack_rate        : float = 2.0
@export var engage_range       : float = 48.0

# Splash + knockback — "a little" of each, not a full AoE/charge.
@export var splash_radius      : float = 56.0
@export var splash_damage      : int   = 3
@export var knockback_distance : float = 70.0
@export var knockback_time     : float = 0.15

func _ready() -> void:
	# Set base exports before super._ready() initialises hp.
	max_hp        = 38
	move_speed    = 60.0
	patrol_radius = 180.0
	super._ready()

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# attack_rate is the cooldown between swings, but the hit itself and the
# return to idle should land on the swing animation's own timing, not on
# whatever the cooldown happens to be. _do_attack_tick() (above) just started
# attack1 playing this same frame, so wait for it to actually finish, THEN
# deal damage and drop back to idle. Without the await, damage would land the
# instant the swing starts instead of when the hit connects, and attack1
# (loop = false) would just freeze on its last frame for the rest of the
# cooldown instead of resetting to idle.
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
	var hit_center : Vector2 = _target.position
	_apply_hit(_target, attack_damage)
	# Splash — anything else near the main target (not the bear itself) takes
	# a smaller follow-up hit and gets knocked back too.
	for u in _get_battle_targets():
		if u == _target or not is_instance_valid(u) or u.hp <= 0:
			continue
		if hit_center.distance_to(u.position) <= splash_radius:
			_apply_hit(u, splash_damage)

func _apply_hit(body: Node, dmg: int) -> void:
	if not is_instance_valid(body):
		return
	body.take_damage(dmg)
	if not is_instance_valid(body) or body.hp <= 0:
		return
	var kb_dir : Vector2 = (body.position - position).normalized()
	if kb_dir == Vector2.ZERO:
		kb_dir = Vector2.RIGHT
	var kb_dest : Vector2 = body.position + kb_dir * knockback_distance
	var kb_tw   : Tween   = body.create_tween()
	kb_tw.tween_property(body, "position", kb_dest, knockback_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_attacking_state() -> void:
	return
