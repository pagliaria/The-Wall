# warrior.gd
extends "res://scripts/unit_base.gd"

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED     = 60.0
const PATROL_RADIUS  = 160.0
const ARRIVAL_RADIUS = 12.0

const MELEE_RANGE    = 48.0
const ATTACK_DAMAGE  = 5
const ATTACK_RATE    = 3

# =========================================================================== #
#  Health override
# =========================================================================== #

# (max_hp / hp set here so warrior values override the base defaults)
var _hp_init := func(): max_hp = 20; hp = 20

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO, BATTLE, ATTACKING }

var _state       : State = State.IDLE
var _state_timer_local : float = 0.0  # alias — we use _state_timer from base

var _target       : Node  = null
var _attack_timer : float = 0.0

var _is_striking  : bool = false

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = _get_base_max_hp() + get_building_hp_bonus()
	hp     = max_hp
	_enter_state(State.IDLE)

func _get_base_max_hp() -> int:
	return 20

func _process_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_apply_separation(delta)
			if _state_timer >= _state_dur:
				if has_moved:
					_enter_state(State.IDLE)
				else:
					_enter_state(_pick_next_wander_state())
		State.MOVE:
			_do_nav_move(delta, _get_move_speed())
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, _get_move_speed())
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
		State.BATTLE:
			_do_battle(delta)
		State.ATTACKING:
			if _is_striking:
				return
			_attack_timer -= delta
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target = null
				_enter_state(State.BATTLE)
				return
			if _attack_timer <= 0.0:
				_is_striking = true
				_attack_timer = _get_attack_rate()
				_sprite.play("attack1" if _rng.randf() > 0.5 else "attack2")
				_target.take_damage(_get_attack_damage())
				await _sprite.animation_finished
				_sprite.play("idle")
				_is_striking = false
			if is_instance_valid(_target) and position.distance_to(_target.position) > MELEE_RANGE * 1.5:
				_enter_state(State.BATTLE)

func _pick_next_wander_state() -> State:
	if has_moved:
		return State.IDLE
	return State.MOVE if _rng.randf() > 0.4 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("guard" if _rng.randf() > 0.5 else "idle")
		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_home     := _spawn_pos - position
			var dist        := to_home.length()
			var angle       := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir         : Vector2
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
			_sprite.play("run")
		State.ATTACKING:
			_attack_timer = 0.0

# =========================================================================== #
#  Battle
# =========================================================================== #

func start_battle(enemies: Array) -> void:
	_pick_target(enemies)
	_enter_state(State.BATTLE)

func update_battle_target(enemies: Array) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_pick_target(enemies)

func _do_battle(delta: float) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_target = null
		_enter_state(State.BATTLE)
		return
	var dist := position.distance_to(_target.position)
	if dist <= MELEE_RANGE:
		_enter_state(State.ATTACKING)
		return
	_nav_agent.target_position = _target.position
	_do_nav_move(delta, _get_move_speed())

func _pick_target(enemies: Array) -> void:
	var best      : Node  = null
	var best_dist : float = INF
	for e in enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var d := position.distance_to(e.position)
		if d < best_dist:
			best_dist = d
			best      = e
	_target = best

func _get_move_speed() -> float:
	return MOVE_SPEED * get_building_move_speed_multiplier()

func _get_attack_damage() -> int:
	return ATTACK_DAMAGE + get_building_attack_damage_bonus()

func _get_attack_rate() -> float:
	return ATTACK_RATE * get_building_attack_speed_multiplier()

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_selected() -> void:
	CombatAudio.play("male_ready")

func _on_move_to() -> void:
	CombatAudio.play("male_go")
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_target = null
	_enter_state(State.IDLE)
