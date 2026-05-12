# monk.gd
# Support unit. During battle:
#   - Priority 1: heal any injured friendly unit within HEAL_RANGE
#   - Priority 2: attack the nearest enemy with a holy bolt
# Outside battle: wanders the town and heals nearby injured allies.
extends "res://scripts/unit_base.gd"

const HEAL_EFFECT_SCENE := preload("res://scenes/heal_effect.tscn")

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED         : float = 58.0
const PATROL_RADIUS      : float = 170.0

const HEAL_RANGE         : float = 220.0
const ATTACK_RANGE       : float = 200.0
const ATTACK_RANGE_MIN   : float = 80.0
const HEAL_AMOUNT        : int   = 6
const ATTACK_DAMAGE      : int   = 4
const CAST_RATE          : float = 2.2
const IDLE_HEAL_SCAN_RATE : float = 1.0

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO, BATTLE, CASTING }

var _state : State = State.IDLE

var _enemies       : Array = []
var _attack_target : Node  = null
var _heal_target   : Node  = null
var _cast_timer    : float = 0.0
var _casting       : bool  = false
var _cast_is_heal  : bool  = true
var _pre_cast_state : State = State.IDLE
var _idle_heal_timer : float = 0.0

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = _get_base_max_hp() + get_building_hp_bonus()
	hp     = max_hp
	_sprite.animation_finished.connect(_on_cast_animation_finished)
	_enter_state(State.IDLE)

func _get_base_max_hp() -> int:
	return 14

func _process_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_apply_separation(delta)
			_idle_heal_timer -= delta
			if _idle_heal_timer <= 0.0:
				_idle_heal_timer = IDLE_HEAL_SCAN_RATE
				_try_idle_heal()
			if not has_moved and _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE:
			_do_nav_move(delta, _get_move_speed())
			_idle_heal_timer -= delta
			if _idle_heal_timer <= 0.0:
				_idle_heal_timer = IDLE_HEAL_SCAN_RATE
				_try_idle_heal()
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, _get_move_speed())
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
		State.BATTLE:
			_do_battle(delta)
		State.CASTING:
			_cast_timer -= delta
			var in_battle : bool = _pre_cast_state == State.BATTLE
			# Validate targets are still worth casting on
			var heal_valid : bool = _is_valid_heal_target(_heal_target)
			var atk_valid  : bool = _is_valid_attack_target(_attack_target)
			if in_battle and not heal_valid and not atk_valid:
				_casting = false
				_enter_state(State.BATTLE)
				return
			if not in_battle and not heal_valid:
				_casting = false
				_enter_state(_pre_cast_state)
				return
			if _cast_timer <= 0.0 and not _casting:
				_do_cast()

func _pick_next_wander_state() -> State:
	if has_moved:
		return State.IDLE
	return State.MOVE if _rng.randf() > 0.4 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0
	_casting     = false

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")
		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_home    : Vector2 = _spawn_pos - position
			var dist       : float   = to_home.length()
			var angle      : float   = _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir        : Vector2
			if dist > PATROL_RADIUS:
				dir = to_home.normalized().rotated(angle * 0.3)
			else:
				dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var patrol_dist   : float   = _rng.randf_range(48.0, PATROL_RADIUS)
			var raw_target    : Vector2 = position + dir.normalized() * patrol_dist
			var patrol_target : Vector2 = Vector2(
				clampf(raw_target.x, WANDER_MIN_X, WANDER_MAX_X),
				clampf(raw_target.y, WANDER_MIN_Y, WANDER_MAX_Y)
			)
			_nav_agent.target_position = patrol_target
			_sprite.play("run")
		State.MOVE_TO:
			has_moved = true
			_state_dur = STUCK_TIMEOUT
			_nav_agent.target_position = _move_target
			_sprite.flip_h = (_move_target - position).x < 0
			_sprite.play("run")
		State.BATTLE:
			_sprite.play("idle")
		State.CASTING:
			_cast_timer = _get_attack_rate()
			_sprite.play("idle")

# =========================================================================== #
#  Target validation helpers
# =========================================================================== #

func _is_valid_heal_target(t) -> bool:
	return is_instance_valid(t) \
		and t.get("hp") != null \
		and t.get("max_hp") != null \
		and t.hp > 0 \
		and t.hp < t.max_hp

func _is_valid_attack_target(t) -> bool:
	return is_instance_valid(t) \
		and t.get("hp") != null \
		and t.hp > 0

# =========================================================================== #
#  Ally scanning — single shared implementation
# =========================================================================== #

func _scan_for_heal_target(range_limit: float) -> Node:
	var parent : Node = get_parent()
	if parent == null:
		return null
	var best       : Node  = null
	var best_dist  : float = range_limit
	for child in parent.get_children():
		if child == self:
			continue
		if not child is CharacterBody2D:
			continue
		if child.get("faction") != "player":
			continue
		if not _is_valid_heal_target(child):
			continue
		var d : float = position.distance_to(child.position)
		if d < best_dist:
			best_dist = d
			best      = child
	return best

func _scan_for_attack_target() -> Node:
	var best      : Node  = null
	var best_dist : float = INF
	for e in _enemies:
		if not _is_valid_attack_target(e):
			continue
		var d : float = position.distance_to(e.position)
		if d < best_dist:
			best_dist = d
			best      = e
	return best

# =========================================================================== #
#  Idle healing
# =========================================================================== #

func _try_idle_heal() -> void:
	var target : Node = _scan_for_heal_target(HEAL_RANGE)
	if target == null:
		return
	_heal_target    = target
	_attack_target  = null
	_cast_is_heal   = true
	_pre_cast_state = _state
	_enter_state(State.CASTING)

# =========================================================================== #
#  Battle
# =========================================================================== #

func start_battle(enemies: Array) -> void:
	_enemies = enemies
	_enter_state(State.BATTLE)

func update_battle_target(enemies: Array) -> void:
	_enemies = enemies

func _do_battle(delta: float) -> void:
	# Re-scan each battle tick — keeps ally list fresh as units die or arrive
	_heal_target   = _scan_for_heal_target(HEAL_RANGE)
	_attack_target = _scan_for_attack_target()

	if _heal_target != null:
		_sprite.flip_h  = _heal_target.position.x < position.x
		_pre_cast_state = State.BATTLE
		_enter_state(State.CASTING)
		return

	if _attack_target != null:
		var dist : float = position.distance_to(_attack_target.position)
		_sprite.flip_h   = _attack_target.position.x < position.x

		if dist < ATTACK_RANGE_MIN:
			var flee_dir : Vector2 = (position - _attack_target.position).normalized()
			var flee_pos : Vector2 = Vector2(
				clampf(position.x + flee_dir.x * ATTACK_RANGE, WANDER_MIN_X, WANDER_MAX_X),
				clampf(position.y + flee_dir.y * ATTACK_RANGE, WANDER_MIN_Y, WANDER_MAX_Y)
			)
			_nav_agent.target_position = flee_pos
			_do_nav_move(delta, _get_move_speed())
		elif dist <= ATTACK_RANGE:
			_pre_cast_state = State.BATTLE
			_enter_state(State.CASTING)
		else:
			var toward   : Vector2 = position.direction_to(_attack_target.position)
			var approach : Vector2 = _attack_target.position - toward * (ATTACK_RANGE * 0.75)
			_nav_agent.target_position = approach
			_do_nav_move(delta, _get_move_speed())
		return

	_sprite.play("idle")

# =========================================================================== #
#  Casting
# =========================================================================== #

func _do_cast() -> void:
	_casting = true

	# Re-validate targets at cast time — heal takes priority
	if _is_valid_heal_target(_heal_target):
		_cast_is_heal  = true
		_sprite.flip_h = _heal_target.position.x < position.x
	elif _is_valid_attack_target(_attack_target):
		_cast_is_heal  = false
		_sprite.flip_h = _attack_target.position.x < position.x
	else:
		_casting = false
		_enter_state(State.BATTLE if _pre_cast_state == State.BATTLE else _pre_cast_state)
		return

	_sprite.play("heal")

func _on_cast_animation_finished() -> void:
	if _state != State.CASTING or not _casting:
		return

	if _cast_is_heal and _is_valid_heal_target(_heal_target):
		var effect : Node2D = HEAL_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = _heal_target.global_position
		effect.init(_heal_target, HEAL_AMOUNT, true)
	elif not _cast_is_heal and _is_valid_attack_target(_attack_target):
		var effect : Node2D = HEAL_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = _attack_target.global_position
		effect.init(_attack_target, _get_attack_damage(), false)

	_casting    = false
	_cast_timer = _get_attack_rate()
	_sprite.play("idle")
	_enter_state(_pre_cast_state)

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_selected() -> void:
	CombatAudio.play("monk_ready")

func _on_move_to() -> void:
	CombatAudio.play("monk_go")
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_enemies.clear()
	_attack_target = null
	_heal_target   = null
	_casting       = false
	_enter_state(State.IDLE)

func _get_move_speed() -> float:
	return MOVE_SPEED * get_building_move_speed_multiplier()

func _get_attack_damage() -> int:
	return ATTACK_DAMAGE + get_building_attack_damage_bonus()

func _get_attack_rate() -> float:
	return CAST_RATE * get_building_attack_speed_multiplier()
