# monk.gd
# Support unit. During battle:
#   - Priority 1: heal any injured friendly unit within HEAL_RANGE
#   - Priority 2: attack the nearest enemy with a holy bolt
# Outside battle: wanders the town.
extends "res://scripts/unit_base.gd"

const HEAL_EFFECT_SCENE := preload("res://scenes/heal_effect.tscn")

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED    = 58.0
const PATROL_RADIUS = 170.0

const HEAL_RANGE    = 220.0   # radius to scan for injured allies
const ATTACK_RANGE  = 200.0   # range for holy bolt attack on enemies
const ATTACK_RANGE_MIN = 80.0 # backs off if enemy closer than this
const HEAL_AMOUNT   = 6       # HP restored per heal projectile
const ATTACK_DAMAGE = 4       # damage dealt to enemies
const CAST_RATE          = 2.2     # seconds between any cast (heal or attack)
const IDLE_HEAL_SCAN_RATE = 1.0    # how often to scan for injured allies outside battle

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO, BATTLE, CASTING }

var _state : State = State.IDLE

var _enemies      : Array = []
var _allies       : Array = []   # all player units — injected by wave_manager or scanned
var _attack_target : Node  = null
var _heal_target   : Node  = null
var _cast_timer       : float = 0.0
var _casting          : bool  = false
var _cast_is_heal     : bool  = true
var _pre_cast_state   : State = State.IDLE   # where to return after a non-battle cast
var _idle_heal_timer  : float = 0.0

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = 14
	hp     = 14
	_sprite.animation_finished.connect(_on_cast_animation_finished)
	_enter_state(State.IDLE)

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
			_do_nav_move(delta, MOVE_SPEED)
			_idle_heal_timer -= delta
			if _idle_heal_timer <= 0.0:
				_idle_heal_timer = IDLE_HEAL_SCAN_RATE
				_try_idle_heal()
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, MOVE_SPEED)
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
		State.BATTLE:
			_do_battle(delta)
		State.CASTING:
			_cast_timer -= delta
			# If in battle, validate both targets; outside battle only need heal target
			var heal_tgt_valid : bool = is_instance_valid(_heal_target) and _heal_target.hp < _heal_target.max_hp
			var atk_tgt_valid  : bool = is_instance_valid(_attack_target) and _attack_target.hp > 0
			var in_battle      : bool = _state == State.CASTING and _pre_cast_state == State.BATTLE
			if _pre_cast_state == State.BATTLE and not heal_tgt_valid and not atk_tgt_valid:
				_casting = false
				_enter_state(State.BATTLE)
				return
			if _pre_cast_state != State.BATTLE and not heal_tgt_valid:
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
			var to_home := _spawn_pos - position
			var dist    := to_home.length()
			var angle   := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir     : Vector2
			if dist > PATROL_RADIUS:
				dir = to_home.normalized().rotated(angle * 0.3)
			else:
				dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var patrol_dist   := _rng.randf_range(48.0, PATROL_RADIUS)
			var raw_target    := position + dir.normalized() * patrol_dist
			var patrol_target := Vector2(
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
			_cast_timer = CAST_RATE
			_sprite.play("idle")

# =========================================================================== #
#  Battle logic
# =========================================================================== #

func start_battle(enemies: Array) -> void:
	_enemies = enemies
	_scan_allies()
	_enter_state(State.BATTLE)

func update_battle_target(enemies: Array) -> void:
	_enemies = enemies
	_scan_allies()

func _try_idle_heal() -> void:
	# Scan nearby allies for anyone injured — heal them without entering battle
	var parent : Node = get_parent()
	if parent == null:
		return
	var best_target : Node  = null
	var best_dist   : float = INF
	for child in parent.get_children():
		if child == self or not child is CharacterBody2D:
			continue
		if child.get("faction") != "player":
			continue
		if child.get("hp") == null or child.hp >= child.max_hp:
			continue
		var d : float = position.distance_to(child.position)
		if d < HEAL_RANGE and d < best_dist:
			best_dist   = d
			best_target = child
	if best_target == null:
		return
	_heal_target      = best_target
	_attack_target    = null
	_cast_is_heal     = true
	_pre_cast_state   = _state   # remember IDLE or MOVE to return to
	_enter_state(State.CASTING)

func _scan_allies() -> void:
	# Collect all other player CharacterBody2D in the same parent
	_allies.clear()
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self:
			continue
		if child is CharacterBody2D and child.get("faction") == "player":
			_allies.append(child)

func _do_battle(delta: float) -> void:
	# --- Pick heal target: nearest injured ally in range ---
	_heal_target = null
	var best_heal_dist := INF
	for ally in _allies:
		if not is_instance_valid(ally) or ally.get("hp") == null:
			continue
		if ally.hp >= ally.max_hp:
			continue
		var d := position.distance_to(ally.position)
		if d < HEAL_RANGE and d < best_heal_dist:
			best_heal_dist = d
			_heal_target = ally

	# --- Pick attack target: nearest living enemy ---
	_attack_target = null
	var best_atk_dist := INF
	for e in _enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var d := position.distance_to(e.position)
		if d < best_atk_dist:
			best_atk_dist = d
			_attack_target = e

	# --- Decide what to do ---
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
			_do_nav_move(delta, MOVE_SPEED)
		elif dist <= ATTACK_RANGE:
			_pre_cast_state = State.BATTLE
			_enter_state(State.CASTING)
		else:
			# Move into attack range
			var toward      := position.direction_to(_attack_target.position)
			var approach    : Vector2 = _attack_target.position - toward * (ATTACK_RANGE * 0.75)
			_nav_agent.target_position = approach
			_do_nav_move(delta, MOVE_SPEED)
		return

	# Nothing to do — stand by
	_sprite.play("idle")

# =========================================================================== #
#  Casting
# =========================================================================== #

func _do_cast() -> void:
	_casting = true

	# Re-evaluate at cast time — heal takes priority
	if is_instance_valid(_heal_target) and _heal_target.hp < _heal_target.max_hp:
		_cast_is_heal = true
		_sprite.flip_h = _heal_target.position.x < position.x
	elif is_instance_valid(_attack_target) and _attack_target.hp > 0:
		_cast_is_heal = false
		_sprite.flip_h = _attack_target.position.x < position.x
	else:
		_casting = false
		_enter_state(State.BATTLE)
		return

	_sprite.play("heal")

func _on_cast_animation_finished() -> void:
	if _state != State.CASTING or not _casting:
		return

	if _cast_is_heal and is_instance_valid(_heal_target) and _heal_target.hp < _heal_target.max_hp:
		var effect : Node2D = HEAL_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = _heal_target.global_position
		effect.init(_heal_target, HEAL_AMOUNT, true)
	elif not _cast_is_heal and is_instance_valid(_attack_target) and _attack_target.hp > 0:
		var effect : Node2D = HEAL_EFFECT_SCENE.instantiate()
		get_parent().add_child(effect)
		effect.global_position = _attack_target.global_position
		effect.init(_attack_target, ATTACK_DAMAGE, false)

	_casting    = false
	_cast_timer = CAST_RATE
	_sprite.play("idle")
	_enter_state(_pre_cast_state)

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_move_to() -> void:
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_enemies.clear()
	_allies.clear()
	_attack_target = null
	_heal_target   = null
	_casting       = false
	_enter_state(State.IDLE)
