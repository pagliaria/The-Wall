extends CharacterBody2D

signal died
signal selected_changed(is_selected: bool)

var is_selected: bool = false
var has_moved: bool = false

# -- Health -------------------------------------------------------------------
var max_hp : int = 10
var hp     : int = 10

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	emit_signal("selected_changed", value)

const TILE_SIZE := 64
const MAP_COLS := 48
const MAP_ROWS := 27
const WATER_ROWS := 3
const COL_TOWN_START := 20

const IDLE_TIME_MIN := 1.5
const IDLE_TIME_MAX := 4.0
const MOVE_TIME_MIN := 1.0
const MOVE_TIME_MAX := 2.5
const MOVE_SPEED := 62.0
const PATROL_RADIUS := 180.0
const STUCK_TIMEOUT := 5.0
const SEPARATION_RADIUS := 22.0
const SEPARATION_FORCE  := 180.0

const WANDER_MIN_X := float((COL_TOWN_START + 1) * TILE_SIZE)
const WANDER_MAX_X := float((MAP_COLS - 2) * TILE_SIZE)
const WANDER_MIN_Y := float((WATER_ROWS + 1) * TILE_SIZE)
const WANDER_MAX_Y := float((MAP_ROWS - 2) * TILE_SIZE)

enum State { IDLE, MOVE, MOVE_TO }

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _state_dur: float = 0.0
var _move_target: Vector2 = Vector2.ZERO
var _spawn_pos: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

var home_position: Vector2 = Vector2.ZERO
var home_node: Node = null

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _selection_circle: Node2D = $SelectionCircle
@onready var _nav_agent: NavigationAgent2D = $NavAgent

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	call_deferred("_enter_state", State.IDLE)

func _physics_process(delta: float) -> void:
	_state_timer += delta

	match _state:
		State.IDLE:
			if _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE:
			_do_nav_move(delta)
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta)
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)

func _pick_next_wander_state() -> State:
	if has_moved:
		return State.IDLE
	return State.MOVE if _rng.randf() > 0.4 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")
		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_home := _spawn_pos - position
			var dist := to_home.length()
			var angle := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir: Vector2
			if dist > PATROL_RADIUS:
				dir = to_home.normalized().rotated(angle * 0.3)
			else:
				dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var patrol_dist := _rng.randf_range(48.0, PATROL_RADIUS)
			var raw_target := position + dir.normalized() * patrol_dist
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

func _do_nav_move(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		_apply_separation(delta)
		return
	var next_point := _nav_agent.get_next_path_position()
	var move_dir := (next_point - position).normalized()
	_sprite.flip_h = move_dir.x < 0
	move_and_collide(move_dir * MOVE_SPEED * delta)
	_apply_separation(delta)

func move_to(target: Vector2) -> void:
	_move_target = target
	_enter_state(State.MOVE_TO)

func end_battle() -> void:
	has_moved = false
	_enter_state(State.IDLE)

func _apply_separation(delta: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sep := Vector2.ZERO
	for sibling in parent.get_children():
		if sibling == self or not sibling is CharacterBody2D:
			continue
		var diff := position - sibling.position
		var dist := diff.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			sep += diff.normalized() * (SEPARATION_RADIUS - dist)
	if sep != Vector2.ZERO:
		move_and_collide(sep.normalized() * SEPARATION_FORCE * delta)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	emit_signal("died")
	queue_free()
