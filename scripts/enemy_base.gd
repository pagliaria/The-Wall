extends CharacterBody2D

# enemy_base.gd — Base class for all enemy unit types.

signal died

@export var max_hp        : int   = 18
@export var move_speed    : float = 55.0
@export var patrol_radius : float = 180.0
@export var idle_time_min : float = 1.5
@export var idle_time_max : float = 4.0
@export var move_time_min : float = 1.0
@export var move_time_max : float = 2.5

const PUSH_DISTANCE        = 10.0
const PUSH_SPEED           = 300.0
const YIELD_TIME           = 0.2
const STALEMATE_RESET_TIME = 0.6
const STALEMATE_COLLISIONS = 1

const WANDER_MIN_X = 32.0
const WANDER_MAX_X = 580.0
const WANDER_MIN_Y = 200.0
const WANDER_MAX_Y = 1520.0

var faction : String = "enemy"
var hp      : int    = 0

enum State { IDLE, BATTLE, ATTACKING, DEAD }

var _state        : State   = State.IDLE
var _state_timer  : float   = 0.0
var _state_dur    : float   = 0.0
var _spawn_pos    : Vector2 = Vector2.ZERO
var _rng          := RandomNumberGenerator.new()
var _battle_ready : bool    = false   # set true once start_battle() is called

var _target       : Node  = null
var _attack_timer : float = 0.0

var _push_target     : Vector2 = Vector2.ZERO
var _is_being_pushed : bool    = false
var _yield_timer     : float   = 0.0
var _last_blocker_id : int     = -1
var _block_count     : int     = 0
var _block_timer     : float   = 0.0

@onready var _sprite : AnimatedSprite2D  = $Sprite
@onready var _nav    : NavigationAgent2D = $NavAgent

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	hp = max_hp
	_spawn_pos = position
	# Don't enter MILL yet — wait for start_battle() or a deferred mill start
	# so that wave_manager can call start_battle() before the first state runs.
	call_deferred("_initial_state")

func _initial_state() -> void:
	# If start_battle() already fired before this deferred call, stay in BATTLE.
	if _battle_ready:
		return
	_enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

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
			return

		State.BATTLE:
			_do_battle(delta)

		State.ATTACKING:
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target = null
				_enter_state(State.BATTLE)
				return
			if position.distance_to(_target.position) > _get_engage_range() * 1.6:
				_enter_state(State.BATTLE)
				return
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = _get_attack_rate()
				_do_attack_hit()
			_do_attack_tick(delta)

# =========================================================================== #
#  State transitions
# =========================================================================== #

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(idle_time_min, idle_time_max)
			_on_enter_idle_state()

		State.BATTLE:
			_on_enter_battle_state()

		State.ATTACKING:
			_attack_timer = 0.0
			_on_enter_attacking_state()

		State.DEAD:
			_on_enter_dead_state()
			set_physics_process(false)

# =========================================================================== #
#  Battle logic
# =========================================================================== #

func start_battle(player_units: Array) -> void:
	_battle_ready = true
	_pick_target(player_units)
	_enter_state(State.BATTLE)

func update_target(player_units: Array) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_pick_target(player_units)

func _do_battle(delta: float) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_target = null
		_on_enter_idle_state()
		return

	var dist := position.distance_to(_target.position)
	if dist <= _get_engage_range():
		_enter_state(State.ATTACKING)
		return

	# Drive nav toward target every frame so it tracks movement
	_nav.target_position = _target.position
	_do_nav_move(delta)

func _pick_target(units: Array) -> void:
	var best      : Node  = null
	var best_dist : float = INF
	for u in units:
		if not is_instance_valid(u) or u.hp <= 0:
			continue
		var d := position.distance_to(u.position)
		if d < best_dist:
			best_dist = d
			best = u
	_target = best

# =========================================================================== #
#  Navigation
# =========================================================================== #

func _do_nav_move(delta: float) -> void:
	# In battle mode, ignore nav_finished — the target keeps moving so we
	# always want to be steering. Only skip if we literally have no path yet.
	if _state != State.BATTLE and _nav.is_navigation_finished():
		return

	var next   := _nav.get_next_path_position()
	# If nav has no path, next == position; fall back to direct movement toward target
	var dir : Vector2
	if next.distance_to(position) < 2.0 and _target != null and is_instance_valid(_target):
		dir = (position.direction_to(_target.position))
	else:
		dir = (next - position).normalized()

	if dir == Vector2.ZERO:
		return

	_sprite.flip_h = dir.x < 0
	var motion    := dir * move_speed * delta
	var collision := move_and_collide(motion)
	if collision:
		if not _handle_unit_collision(collision, dir, motion):
			move_and_collide(dir.bounce(collision.get_normal()).normalized() * move_speed * delta)

# =========================================================================== #
#  Push
# =========================================================================== #

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

# =========================================================================== #
#  Health
# =========================================================================== #

func take_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	_state = State.DEAD
	emit_signal("died")
	queue_free()

# =========================================================================== #
#  Virtual methods
# =========================================================================== #

func _get_engage_range() -> float:
	return 48.0

func _get_attack_rate() -> float:
	return 1.2

func _do_attack_hit() -> void:
	if is_instance_valid(_target):
		_target.take_damage(4)

func _do_attack_tick(_delta: float) -> void:
	pass

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_mill_state() -> void:
	if _sprite.sprite_frames.has_animation("run"):
		_sprite.play("run")

func _on_enter_battle_state() -> void:
	if _sprite.sprite_frames.has_animation("run"):
		_sprite.play("run")

func _on_enter_attacking_state() -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")

func _on_enter_dead_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")
