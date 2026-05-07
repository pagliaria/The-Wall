# archer.gd
extends "res://scripts/unit_base.gd"

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED    = 62.0
const PATROL_RADIUS = 180.0

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO }

var _state : State = State.IDLE

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = 10
	hp     = 10
	_enter_state(State.IDLE)

func _process_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_apply_separation(delta)
			if not has_moved and _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE:
			_do_nav_move(delta, MOVE_SPEED)
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, MOVE_SPEED)
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)

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
			_sprite.play("idle")
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

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_move_to() -> void:
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_enter_state(State.IDLE)
