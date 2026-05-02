extends AnimatedSprite2D

# Sheep behaviour — state machine with idle, graze, and move states.
# The sheep wanders within the town zone, occasionally stopping to eat or rest.
# Z index is fixed at 3 (Units layer) — set by resource_spawner.gd at spawn.

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const IDLE_TIME_MIN  = 1.5
const IDLE_TIME_MAX  = 4.0
const GRAZE_TIME_MIN = 2.0
const GRAZE_TIME_MAX = 5.0
const MOVE_TIME_MIN  = 1.0
const MOVE_TIME_MAX  = 2.5

const MOVE_SPEED     = 25.0   # px/sec

enum State { IDLE, GRAZE, MOVE }

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_dir    : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_enter_state(_pick_random_state())

func _process(delta: float) -> void:
	_state_timer += delta
	if _state == State.MOVE:
		_do_move(delta)
	if _state_timer >= _state_dur:
		_enter_state(_pick_random_state())

func _pick_random_state() -> State:
	var r := _rng.randf()
	if r < 0.4:   return State.IDLE
	elif r < 0.8: return State.GRAZE
	else:         return State.MOVE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0
	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			play("idle")
		State.GRAZE:
			_state_dur = _rng.randf_range(GRAZE_TIME_MIN, GRAZE_TIME_MAX)
			play("graze")
		State.MOVE:
			_state_dur  = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var angle   := _rng.randf_range(-PI * 0.4, PI * 0.4)
			var sign_x  := 1.0 if _rng.randf() > 0.5 else -1.0
			_move_dir    = Vector2(cos(angle) * sign_x, sin(angle)).normalized()
			flip_h       = _move_dir.x < 0
			play("move")

func _do_move(delta: float) -> void:
	var new_pos := position + _move_dir * MOVE_SPEED * delta

	var min_x := (COL_TOWN_START + 1) * TILE_SIZE + TILE_SIZE * 0.5
	var max_x := (MAP_COLS - 2)       * TILE_SIZE + TILE_SIZE * 0.5
	var min_y := (WATER_ROWS + 1)     * TILE_SIZE + TILE_SIZE * 0.5
	var max_y := (MAP_ROWS - 2)       * TILE_SIZE + TILE_SIZE * 0.5

	if new_pos.x < min_x or new_pos.x > max_x:
		_move_dir.x *= -1.0
		flip_h       = _move_dir.x < 0
		new_pos      = position + _move_dir * MOVE_SPEED * delta
	if new_pos.y < min_y or new_pos.y > max_y:
		_move_dir.y  *= -1.0
		new_pos       = position + _move_dir * MOVE_SPEED * delta

	position = new_pos
