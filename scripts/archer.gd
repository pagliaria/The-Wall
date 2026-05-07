# archer.gd
extends "res://scripts/unit_base.gd"

const ARROW_SCENE := preload("res://scenes/arrow.tscn")

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED    = 62.0
const PATROL_RADIUS = 180.0

const SHOOT_RANGE      = 500.0   # starts shooting within this distance
const SHOOT_RANGE_MIN  = 80.0    # backs away if enemy gets closer than this
const ATTACK_DAMAGE    = 3
const ATTACK_RATE      = 2     # seconds between shots

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO, BATTLE, SHOOTING }

var _state : State = State.IDLE

var _target       : Node  = null
var _attack_timer : float = 0.0
var _shooting     : bool  = false  # true while shoot animation is playing

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = 10
	hp     = 10
	#_sprite.animation_finished.connect(_on_shoot_animation_finished)
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
		State.BATTLE:
			_do_battle(delta)
		State.SHOOTING:
			_attack_timer -= delta
			# If target dies while we're waiting to fire, go back to battle
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target = null
				_shooting = false
				_enter_state(State.BATTLE)
				return
			# Fire when the timer expires (animation plays, damage dealt on finish)
			if _attack_timer <= 0.0 and not _shooting:
				_do_shoot()
			# If enemy closes in while we're waiting, reposition
			if not _shooting and is_instance_valid(_target):
				var dist := position.distance_to(_target.position)
				if dist > SHOOT_RANGE or dist < SHOOT_RANGE_MIN:
					_enter_state(State.BATTLE)

func _pick_next_wander_state() -> State:
	if has_moved:
		return State.IDLE
	return State.MOVE if _rng.randf() > 0.4 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0
	_shooting    = false

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
		State.BATTLE:
			_sprite.play("run")
		State.SHOOTING:
			_attack_timer = ATTACK_RATE
			_sprite.play("idle")

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
	_sprite.flip_h = _target.position.x < position.x

	if dist < SHOOT_RANGE_MIN:
		# Too close — back away from the enemy
		var flee_dir : Vector2 = (position - _target.position).normalized()
		var flee_pos := position + flee_dir * SHOOT_RANGE
		flee_pos = Vector2(
			clampf(flee_pos.x, WANDER_MIN_X, WANDER_MAX_X),
			clampf(flee_pos.y, WANDER_MIN_Y, WANDER_MAX_Y)
		)
		_nav_agent.target_position = flee_pos
		_do_nav_move(delta, MOVE_SPEED)
	elif dist <= SHOOT_RANGE:
		# In range — stop and shoot
		_enter_state(State.SHOOTING)
	else:
		# Out of range — close in to shoot range
		var toward := (position.direction_to(_target.position))
		var approach_pos : Vector2 = _target.position - toward * (SHOOT_RANGE * 0.75)
		_nav_agent.target_position = approach_pos
		_do_nav_move(delta, MOVE_SPEED)

func _do_shoot() -> void:
	_shooting = true
	if not is_instance_valid(_target):
		_shooting = false
		return
	_sprite.flip_h = _target.position.x < position.x
	var anim_name = "shoot"
	_sprite.play(anim_name)
	# Get frames and fps to calculate duration
	var frames = _sprite.sprite_frames.get_frame_count(anim_name)
	var fps = _sprite.sprite_frames.get_animation_speed(anim_name)
	var total_duration = frames / fps
	
	# Wait for half the animation
	await get_tree().create_timer(total_duration / 2.0).timeout
	_spawn_arrow()

func _spawn_arrow() -> void:
	if _state != State.SHOOTING or not _shooting:
		return
	# Spawn the arrow at the archer's position aimed at the target
	if is_instance_valid(_target) and _target.hp > 0:
		var arrow := ARROW_SCENE.instantiate()
		get_parent().add_child(arrow)
		arrow.global_position = global_position
		arrow.init(_target, ATTACK_DAMAGE)
	_shooting     = false
	_attack_timer = ATTACK_RATE
	await _sprite.animation_finished
	_sprite.play("idle")

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

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_move_to() -> void:
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_target   = null
	_shooting = false
	_enter_state(State.IDLE)
