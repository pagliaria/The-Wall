extends "res://scripts/enemy_base.gd"
# enemy_thief.gd — Fragile assassin with a teleport-backstab.
#
# Normal attack is a quick dagger slash (lands at hit_fraction of the
# animation — the slash flash is frame 3 of 6, earlier than the halfway
# point). Every teleport_cooldown seconds, while chasing or standing between
# swings, it scans for the FURTHEST valid target inside teleport_range, poofs
# out in a puff of Dust_01, reappears just behind that target (on the far side
# from where the thief was standing), and immediately stabs it for
# backstab_multiplier x damage. Preferring the furthest unit is deliberate: it
# pulls the thief past the front line toward whatever is hanging back.
#
# The teleport is instant and reuses the normal attack pipeline rather than
# running its own coroutine: it just retargets, flags the next hit as a
# backstab, and drops straight into ATTACKING with a zeroed attack timer, so
# the base state machine fires the stab on the very next frame.

@export var attack_damage : int   = 4
@export var attack_rate   : float = 1.3
@export var engage_range  : float = 40.0

# Fraction of the attack animation at which the slash connects. The slash
# flash is frame index 2 of 6 (33%-50%), so 0.4 lands mid-flash.
@export var hit_fraction  : float = 0.4

# Teleport ability.
@export var teleport_range        : float = 300.0   # furthest it can jump
@export var teleport_min_distance : float = 90.0    # closer than this isn't worth a jump
@export var teleport_cooldown     : float = 8.0
@export var teleport_initial_delay_min : float = 2.0  # so a pack doesn't all jump at once
@export var teleport_initial_delay_max : float = 5.0
@export var behind_offset         : float = 30.0    # must stay under the disengage range
@export var backstab_multiplier   : float = 3.0

const TELEPORT_SCAN_INTERVAL : float = 0.3
const ARENA_MARGIN           : float = 40.0

# Arena bounds come from wave_manager so the thief can never land past the
# wall or off the map when "behind" a target is out of bounds.
const WaveManagerScript : GDScript   = preload("res://scripts/wave_manager.gd")
const DUST_POOF_SCENE   : PackedScene = preload("res://scenes/dust_poof_fx.tscn")

var _teleport_cd_left   : float = 0.0
var _teleport_scan_left : float = 0.0
var _backstab_ready     : bool  = false

func _ready() -> void:
	max_hp     = 16
	move_speed = 85.0
	_teleport_cd_left = randf_range(teleport_initial_delay_min, teleport_initial_delay_max)
	super._ready()

# -- Teleport ----------------------------------------------------------------

# Runs ahead of the base state machine each frame. Everything it does goes
# through public state transitions (_enter_state, _target), so the base class
# never needs to know teleporting exists.
func _physics_process(delta: float) -> void:
	if _state != State.DEAD and not _transformed:
		_tick_teleport(delta)
	super._physics_process(delta)

func _tick_teleport(delta: float) -> void:
	# Only mid-battle: the cooldown doesn't burn down during prep, so a thief
	# can't arrive at the fight with the ability already waiting.
	if not _battle_ready:
		return
	if _state != State.BATTLE and _state != State.ATTACKING:
		return
	if _teleport_cd_left > 0.0:
		_teleport_cd_left -= delta
		return
	# Never mid-swing: a pending _do_attack_hit() would still be waiting on the
	# old animation when the thief vanished.
	if _state == State.ATTACKING and _is_striking:
		return
	_teleport_scan_left -= delta
	if _teleport_scan_left > 0.0:
		return
	_teleport_scan_left = TELEPORT_SCAN_INTERVAL
	var victim : Node = _pick_teleport_victim()
	if victim != null:
		_teleport_strike(victim)

# Furthest valid target within teleport_range (and beyond the minimum worth
# jumping for). Returns null if nothing qualifies, in which case the cooldown
# is NOT spent and it just rescans shortly.
func _pick_teleport_victim() -> Node:
	var best      : Node  = null
	var best_dist : float = -1.0
	for u in _get_battle_targets():
		if not _is_valid_teleport_target(u):
			continue
		var d : float = position.distance_to(u.position)
		if d > teleport_range or d < teleport_min_distance:
			continue
		if d > best_dist:
			best_dist = d
			best      = u
	return best

# Same side-picking rules as enemy_base._best_target: a regular thief hits
# player units and hired units, a hired thief only hits real enemies.
func _is_valid_teleport_target(u: Variant) -> bool:
	if not is_instance_valid(u) or u.hp <= 0:
		return false
	var u_faction : String = str(u.get("faction"))
	var u_hired   : bool   = u.get("hired") == true
	if hired:
		return u_faction == "enemy" and not u_hired
	return not (u_faction == "enemy" and not u_hired)

func _teleport_strike(victim: Node) -> void:
	var from_pos : Vector2 = global_position
	# "Behind" = the far side of the victim from where the thief is standing.
	var away : Vector2 = (victim.position - position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var dest : Vector2 = _clamp_to_arena(victim.position + away * behind_offset)

	_spawn_poof(from_pos)
	position = dest
	_spawn_poof(global_position)

	_target          = victim
	_chase_timer     = 0.0
	_sprite.flip_h   = victim.position.x < position.x
	_backstab_ready  = true
	_teleport_cd_left = teleport_cooldown * randf_range(0.85, 1.15)
	# Zeroes _attack_timer via _on_enter_attacking_state() below, so the base
	# loop fires the stab next frame.
	_enter_state(State.ATTACKING)

func _clamp_to_arena(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, WaveManagerScript.BATTLEFIELD_LEFT + ARENA_MARGIN, WaveManagerScript.BATTLEFIELD_RIGHT - ARENA_MARGIN),
		clampf(p.y, WaveManagerScript.SNAPSHOT_MIN_Y + ARENA_MARGIN, WaveManagerScript.SNAPSHOT_MAX_Y - ARENA_MARGIN)
	)

func _spawn_poof(at_pos: Vector2) -> void:
	var fx : Node2D = DUST_POOF_SCENE.instantiate()
	# Feet, not centre: the sprite's origin sits above the ground shadow.
	fx.global_position = at_pos + Vector2(0.0, 10.0)
	get_tree().current_scene.add_child(fx)

# -- Virtual overrides -------------------------------------------------------
func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	# Fire the first strike right away instead of waiting a full attack_rate,
	# through the normal _do_attack_tick()/_do_attack_hit() cycle (see
	# enemy_bear.gd for why playing the animation directly here instead would
	# create a phantom strike that never deals damage). This is also what makes
	# the teleport's backstab land immediately.
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

# Hit timing lands at hit_fraction of the animation rather than waiting for
# the whole thing to finish. The victim and backstab flag are captured before
# the wait: update_target() can swap _target every retarget tick, and a
# backstab has to land on the unit the thief actually teleported behind.
func _do_attack_hit() -> void:
	var victim   : Node = _target
	var backstab : bool = _backstab_ready
	_backstab_ready = false
	if not is_instance_valid(victim):
		return
	if _sprite.animation == "attack1" and _sprite.sprite_frames.has_animation("attack1"):
		var frame_count : int   = _sprite.sprite_frames.get_frame_count("attack1")
		var fps         : float = _sprite.sprite_frames.get_animation_speed("attack1")
		await get_tree().create_timer((float(frame_count) / fps) * hit_fraction).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if is_instance_valid(victim) and victim.hp > 0:
		var dmg : int = attack_damage
		if backstab:
			dmg = int(round(float(attack_damage) * backstab_multiplier))
		CombatAudio.play(_get_attack_sound())
		victim.take_damage(dmg, self)
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
		if is_instance_valid(self) and is_instance_valid(_sprite) and _sprite.animation == "attack1":
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
