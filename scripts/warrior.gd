extends CharacterBody2D

# Warrior -- a combat unit spawned by a Barracks.
#
# NODE STRUCTURE (warrior.tscn):
#   Warrior (CharacterBody2D)   <- this script
#   |- Sprite (AnimatedSprite2D)   frames defined in scene
#   |- Collision (CollisionShape2D)
#   |- SelectionCircle (Node2D)
#   +- NavAgent (NavigationAgent2D)
#
# States:
#   IDLE    -- stands near barracks, plays idle or guard anim
#   MOVE    -- wanders within patrol radius of barracks
#   MOVE_TO -- player-commanded move (RMB on ground)

signal died
signal selected_changed(is_selected: bool)

# -- Selection ----------------------------------------------------------------
var is_selected : bool = false
var has_moved : bool = false

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	emit_signal("selected_changed", value)

# -- Constants ----------------------------------------------------------------
const TILE_SIZE       = 64
const MAP_COLS        = 48
const MAP_ROWS        = 27
const WATER_ROWS      = 3
const COL_TOWN_START  = 20

const IDLE_TIME_MIN   = 1.5
const IDLE_TIME_MAX   = 4.0
const MOVE_TIME_MIN   = 1.0
const MOVE_TIME_MAX   = 2.5
const MOVE_SPEED      = 60.0
const PUSH_DISTANCE   = 10.0
const PUSH_SPEED      = 300.0
const YIELD_TIME      = 0.2
const STALEMATE_RESET_TIME = 0.6
const STALEMATE_COLLISIONS = 1
const PATROL_RADIUS   = 160.0   # wander distance from barracks
const ARRIVAL_RADIUS  = 12.0
const STUCK_TIMEOUT   = 5.0

const WANDER_MIN_X := float((COL_TOWN_START + 1) * TILE_SIZE)
const WANDER_MAX_X := float((MAP_COLS - 2)        * TILE_SIZE)
const WANDER_MIN_Y := float((WATER_ROWS + 1)      * TILE_SIZE)
const WANDER_MAX_Y := float((MAP_ROWS - 2)        * TILE_SIZE)

# -- Health -------------------------------------------------------------------
var max_hp : int = 20
var hp     : int = 20

# -- State machine ------------------------------------------------------------
enum State { IDLE, MOVE, MOVE_TO, ATTACK }

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_target : Vector2 = Vector2.ZERO
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

# -- Push ---------------------------------------------------------------------
var _push_target     : Vector2 = Vector2.ZERO
var _is_being_pushed : bool    = false
var _yield_timer     : float   = 0.0
var _last_blocker_id : int     = -1
var _block_count     : int     = 0
var _block_timer     : float   = 0.0

# Injected by barracks.gd after adding to tree
var home_position : Vector2 = Vector2.ZERO
var home_node     : Node    = null

# -- Node refs ----------------------------------------------------------------
@onready var _sprite           : AnimatedSprite2D  = $Sprite
@onready var _selection_circle : Node2D            = $SelectionCircle
@onready var _nav_agent        : NavigationAgent2D = $NavAgent

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	call_deferred("_enter_state", State.IDLE)

func _physics_process(delta: float) -> void:
	if _yield_timer > 0.0:
		_yield_timer = maxf(0.0, _yield_timer - delta)
		return

	if _block_timer > 0.0:
		_block_timer = maxf(0.0, _block_timer - delta)
		if _block_timer == 0.0:
			_last_blocker_id = -1
			_block_count = 0

	if _is_being_pushed:
		_do_push_step(delta)
		return

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

# =========================================================================== #
#  State transitions
# =========================================================================== #

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
			# Alternate between idle and guard stance for visual variety
			if _rng.randf() > 0.5:
				_sprite.play("guard")
			else:
				_sprite.play("idle")

		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			# Patrol within PATROL_RADIUS of barracks/spawn, biased back if too far
			var to_home  := _spawn_pos - position
			var dist     := to_home.length()
			var angle    := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir      : Vector2
			if dist > PATROL_RADIUS:
				dir = to_home.normalized().rotated(angle * 0.3)
			else:
				dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var patrol_dist  := _rng.randf_range(48.0, PATROL_RADIUS)
			var raw_target   := position + dir.normalized() * patrol_dist
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
#  Navigation movement
# =========================================================================== #

func _do_nav_move(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		return
	var next_point := _nav_agent.get_next_path_position()
	var move_dir   := (next_point - position).normalized()
	_sprite.flip_h  = move_dir.x < 0
	var motion     := move_dir * MOVE_SPEED * delta
	var collision  := move_and_collide(motion)
	if collision:
		if not _handle_unit_collision(collision, move_dir, motion):
			var bounce := move_dir.bounce(collision.get_normal()).normalized()
			move_and_collide(bounce * MOVE_SPEED * delta)

# =========================================================================== #
#  Public API
# =========================================================================== #

func move_to(target: Vector2) -> void:
	_move_target = target
	_enter_state(State.MOVE_TO)

func request_push(direction: Vector2, distance: float, requester_pos: Vector2 = Vector2.ZERO) -> void:
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		return
	var side_a    := Vector2(-forward.y, forward.x)
	var side_b    := -side_a
	var preferred := side_a
	if requester_pos != Vector2.ZERO:
		var to_self := position - requester_pos
		if to_self.dot(side_b) > to_self.dot(side_a):
			preferred = side_b
	_push_target     = position + preferred * distance
	_is_being_pushed = true
	_yield_timer     = YIELD_TIME

func _do_push_step(delta: float) -> void:
	var to_target := _push_target - position
	if to_target.length() <= 2.0:
		position         = _push_target
		_is_being_pushed = false
		return
	var step := to_target.normalized() * PUSH_SPEED * delta
	if step.length() > to_target.length():
		step = to_target
	var collision := move_and_collide(step)
	if collision:
		_is_being_pushed = false

func _handle_unit_collision(collision: KinematicCollision2D, move_dir: Vector2, motion: Vector2) -> bool:
	var collider := collision.get_collider()
	if collider == null or collider == self or not collider.has_method("request_push"):
		return false

	var collider_id := collider.get_instance_id()
	if collider_id == _last_blocker_id and _block_timer > 0.0:
		_block_count += 1
	else:
		_last_blocker_id = collider_id
		_block_count = 1
	_block_timer = STALEMATE_RESET_TIME

	collider.request_push(move_dir, PUSH_DISTANCE, position)

	if _block_count >= STALEMATE_COLLISIONS:
		request_push(-move_dir, PUSH_DISTANCE * 0.75, collider.global_position)
		_yield_timer = YIELD_TIME
		_block_count = 0
		_last_blocker_id = -1
		return true

	move_and_collide(motion)
	return true

# -- Combat / health ----------------------------------------------------------

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	emit_signal("died")
	queue_free()
