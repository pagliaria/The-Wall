extends CharacterBody2D

# Enemy unit — spawns in the enemy zone (left half of wilds), mills around,
# and enters BATTLE state when the wave manager triggers the fight.

signal died

const TILE_SIZE      = 64
const MOVE_SPEED     = 55.0
const PUSH_DISTANCE  = 10.0
const PUSH_SPEED     = 300.0
const YIELD_TIME     = 0.2
const STALEMATE_RESET_TIME = 0.6
const STALEMATE_COLLISIONS = 1
const STUCK_TIMEOUT  = 5.0
const PATROL_RADIUS  = 180.0
const IDLE_TIME_MIN  = 1.5
const IDLE_TIME_MAX  = 4.0
const MOVE_TIME_MIN  = 1.0
const MOVE_TIME_MAX  = 2.5
const ARRIVAL_RADIUS = 20.0

# Enemy zone wander bounds (left half of the wilds, cols 0–9)
const WANDER_MIN_X = 32.0
const WANDER_MAX_X = 640.0
const WANDER_MIN_Y = 192.0   # below water rows
const WANDER_MAX_Y = 1536.0

# Combat
const MELEE_RANGE   = 48.0
const ATTACK_DAMAGE = 4
const ATTACK_RATE   = 1.2   # seconds between attacks

var max_hp : int = 18
var hp     : int = 18
var faction: String = "enemy"

enum State { IDLE, MILL, BATTLE, ATTACKING, DEAD }

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

# Battle
var _target      : Node    = null   # current attack target
var _attack_timer: float   = 0.0

# Push
var _push_target     : Vector2 = Vector2.ZERO
var _is_being_pushed : bool    = false
var _yield_timer     : float   = 0.0
var _last_blocker_id : int     = -1
var _block_count     : int     = 0
var _block_timer     : float   = 0.0

@onready var _sprite : AnimatedSprite2D  = $Sprite
@onready var _nav    : NavigationAgent2D = $NavAgent

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	call_deferred("_enter_state", State.MILL)

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
			if _state_timer >= _state_dur:
				_enter_state(State.MILL)
		State.MILL:
			_do_nav_move(delta)
			if _nav.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(State.IDLE if _rng.randf() > 0.5 else State.MILL)
		State.BATTLE:
			_do_battle(delta)
		State.ATTACKING:
			_attack_timer -= delta
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target = null
				_enter_state(State.BATTLE)
				return
			if _attack_timer <= 0.0:
				_target.take_damage(ATTACK_DAMAGE)
				_attack_timer = ATTACK_RATE
				# Pick an attack animation randomly
				var anim := "attack1" if _rng.randf() > 0.5 else "attack2"
				if _sprite.sprite_frames.has_animation(anim):
					_sprite.play(anim)
			# Check if target moved out of range
			if is_instance_valid(_target) and position.distance_to(_target.position) > MELEE_RANGE * 1.5:
				_enter_state(State.BATTLE)

# =========================================================================== #
#  State transitions
# =========================================================================== #

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")

		State.MILL:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_home := _spawn_pos - position
			var dist := to_home.length()
			var dir : Vector2
			if dist > PATROL_RADIUS:
				dir = to_home.normalized().rotated(_rng.randf_range(-0.5, 0.5))
			else:
				dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var raw := position + dir * _rng.randf_range(64.0, PATROL_RADIUS)
			_nav.target_position = Vector2(
				clampf(raw.x, WANDER_MIN_X, WANDER_MAX_X),
				clampf(raw.y, WANDER_MIN_Y, WANDER_MAX_Y)
			)
			_sprite.play("run")

		State.BATTLE:
			_target = null
			_sprite.play("run")

		State.ATTACKING:
			_attack_timer = 0.0   # attack immediately on first contact
			var anim := "attack1" if _rng.randf() > 0.5 else "attack2"
			if _sprite.sprite_frames.has_animation(anim):
				_sprite.play(anim)

		State.DEAD:
			_sprite.play("idle")
			set_physics_process(false)

# =========================================================================== #
#  Battle logic
# =========================================================================== #

func start_battle(player_units: Array) -> void:
	_enter_state(State.BATTLE)
	_pick_target(player_units)

func _do_battle(delta: float) -> void:
	# If current target is gone, clear it — _pick_target will be called next frame
	if not is_instance_valid(_target) or not is_instance_valid(_target) or _target.hp <= 0:
		_target = null

	if _target == null:
		# No target: idle in place waiting
		_sprite.play("idle")
		return

	var dist := position.distance_to(_target.position)
	if dist <= MELEE_RANGE:
		# Close enough — switch to attacking
		_enter_state(State.ATTACKING)
		return

	# Move toward target
	_nav.target_position = _target.position
	_do_nav_move(delta)

func _pick_target(units: Array) -> void:
	var best : Node   = null
	var best_dist := INF
	for u in units:
		if not is_instance_valid(u) or u.hp <= 0:
			continue
		var d := position.distance_to(u.position)
		if d < best_dist:
			best_dist = d
			best = u
	_target = best

# Called by wave_manager each frame during battle so enemies retarget if needed
func update_target(player_units: Array) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_pick_target(player_units)

# =========================================================================== #
#  Navigation
# =========================================================================== #

func _do_nav_move(delta: float) -> void:
	if _nav.is_navigation_finished():
		return
	var next := _nav.get_next_path_position()
	var dir  := (next - position).normalized()
	_sprite.flip_h = dir.x < 0
	var motion    := dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		if not _handle_unit_collision(collision, dir, motion):
			move_and_collide(dir.bounce(collision.get_normal()).normalized() * MOVE_SPEED * delta)

# =========================================================================== #
#  Push (same pattern as player units)
# =========================================================================== #

func request_push(direction: Vector2, distance: float, requester_pos: Vector2 = Vector2.ZERO) -> void:
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		return
	var side_a := Vector2(-forward.y, forward.x)
	var side_b := -side_a
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
