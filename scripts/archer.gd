# archer.gd
extends "res://scripts/unit_base.gd"

const ARROW_SCENE := preload("res://scenes/arrow.tscn")

const MOVE_SPEED      = 62.0
const PATROL_RADIUS   = 180.0
const SHOOT_RANGE        : float = 500.0
const SHOOT_RANGE_MIN    : float = 80.0
const SHOOT_RANGE_BUFFER : float = 1.15
const BASE_ATTACK_DAMAGE = 3
const BASE_ATTACK_RATE   = 2.0

const LEVEL_STATS := {
	"hp":          4,
	"damage":      2,
	"attack_rate": -0.15,
}

enum State { IDLE, MOVE, MOVE_TO, BATTLE, SHOOTING, TRAINING }

var _state        : State = State.IDLE
var _target         : Node  = null
var _training_dummy : Node  = null
var _attack_timer : float = 0.0
var _shooting     : bool  = false

var _level_damage_bonus     : int   = 0
var _level_attack_rate_bonus: float = 0.0

func _on_unit_ready() -> void:
	max_hp = _get_base_max_hp() + get_building_hp_bonus()
	hp     = max_hp
	_enter_state(State.IDLE)

func _get_base_max_hp() -> int:
	return 10

# =========================================================================== #
#  XP / levelling
# =========================================================================== #

func _get_level_up_stats() -> Dictionary:
	return LEVEL_STATS

func _on_level_up_stats(stats: Dictionary) -> void:
	_level_damage_bonus      += int(stats.get("damage", 0))
	_level_attack_rate_bonus += float(stats.get("attack_rate", 0.0))

func _get_attack_damage() -> int:
	return BASE_ATTACK_DAMAGE + _level_damage_bonus + get_building_attack_damage_bonus()

func _get_attack_rate() -> float:
	return maxf(0.1, BASE_ATTACK_RATE + _level_attack_rate_bonus) * get_building_attack_speed_multiplier() * get_item_attack_speed_multiplier()

func _get_attack_range() -> float:
	return SHOOT_RANGE + get_building_range_bonus()

# =========================================================================== #
#  State machine
# =========================================================================== #

func _process_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_apply_separation(delta)
			if not has_moved and _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE:
			_do_nav_move(delta, _get_move_speed())
			if _nav_agent.is_navigation_finished() or _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, _get_move_speed())
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
		State.TRAINING:
			_do_training(delta)
		State.BATTLE:
			_do_battle(delta)
		State.SHOOTING:
			_attack_timer -= delta
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target   = null
				_shooting = false
				_enter_state(State.BATTLE)
				return
			if _attack_timer <= 0.0 and not _shooting:
				_do_shoot()
			if not _shooting and is_instance_valid(_target):
				var dist := position.distance_to(_target.position)
				if dist > _get_attack_range() * SHOOT_RANGE_BUFFER or dist < SHOOT_RANGE_MIN:
					_enter_state(State.BATTLE)

func _pick_next_wander_state() -> State:
	return State.MOVE if _rng.randf() > 0.4 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0
	_shooting    = false
	_sprite.speed_scale = 1.0
	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")
		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_home  := _spawn_pos - position
			var dist     := to_home.length()
			var angle    := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var dir      : Vector2
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
			has_moved  = true
			_state_dur = STUCK_TIMEOUT
			_nav_agent.target_position = _move_target
			_sprite.flip_h = (_move_target - position).x < 0
			_sprite.play("run")
		State.BATTLE:
			_sprite.play("run")
		State.SHOOTING:
			_attack_timer = _get_attack_rate()
			_sprite.play("idle")
		State.TRAINING:
			_attack_timer = _get_attack_rate()
			_shooting     = false

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
		var flee_dir : Vector2 = (position - _target.position).normalized()
		var flee_pos := Vector2(
			clampf((position + flee_dir * _get_attack_range()).x, WANDER_MIN_X, WANDER_MAX_X),
			clampf((position + flee_dir * _get_attack_range()).y, WANDER_MIN_Y, WANDER_MAX_Y)
		)
		_nav_agent.target_position = flee_pos
		_do_nav_move(delta, _get_move_speed())
	elif dist <= _get_attack_range():
		_enter_state(State.SHOOTING)
	else:
		var toward       := position.direction_to(_target.position)
		var approach_pos : Vector2 = _target.position - toward * (_get_attack_range() * 0.75)
		_nav_agent.target_position = approach_pos
		_do_nav_move(delta, _get_move_speed())

func _do_shoot() -> void:
	_shooting = true
	if not is_instance_valid(_target):
		_shooting = false
		return
	_sprite.flip_h = _target.position.x < position.x
	var frames   : int   = _sprite.sprite_frames.get_frame_count("shoot")
	var fps      : float = _sprite.sprite_frames.get_animation_speed("shoot")
	var anim_dur : float = frames / fps
	_sprite.speed_scale = maxf(1, anim_dur / _get_attack_rate())
	_sprite.play("shoot")
	var half_dur : float = (anim_dur / _sprite.speed_scale) * 0.5
	await get_tree().create_timer(half_dur).timeout
	_spawn_arrow()

func _spawn_arrow() -> void:
	_sprite.speed_scale = 1.0
	if _state != State.SHOOTING or not _shooting:
		return
	if is_instance_valid(_target) and _target.hp > 0:
		var arrow := ARROW_SCENE.instantiate()
		get_parent().add_child(arrow)
		arrow.global_position = global_position
		arrow.init(_target, _get_attack_damage(), self)
	_shooting           = false
	_attack_timer       = _get_attack_rate()
	_sprite.speed_scale = 1.0
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

func _get_move_speed() -> float:
	return MOVE_SPEED * get_building_move_speed_multiplier()

func _on_selected()   -> void: CombatAudio.play("female_ready")
func _on_move_to()    -> void: CombatAudio.play("female_go"); _enter_state(State.MOVE_TO)
func _on_end_battle() -> void: _target = null; _shooting = false; _training_dummy = null; _enter_state(State.IDLE)
func _enter_training_idle() -> void: _enter_state(State.IDLE)

func _on_start_training(dummy: Node) -> void:
	_training_dummy = dummy
	_enter_state(State.TRAINING)

func _do_training(delta: float) -> void:
	# Archer shoots at dummy from range
	if not is_instance_valid(_training_dummy) or not _training_dummy.get("is_active"):
		var next : Node = _find_training_target()
		if next != null:
			_training_dummy = next
		else:
			_enter_state(State.IDLE)
			return
	var dist : float = position.distance_to(_training_dummy.global_position)
	_sprite.flip_h   = _training_dummy.global_position.x < position.x
	if dist < SHOOT_RANGE_MIN:
		# Too close — back up
		var flee_dir : Vector2 = (position - _training_dummy.global_position).normalized()
		_nav_agent.target_position = position + flee_dir * _get_attack_range()
		_do_nav_move(delta, _get_move_speed())
		return
	if dist > _get_attack_range():
		# Too far — move closer
		if _sprite.animation != "run":
			_sprite.play("run")
		_nav_agent.target_position = _training_dummy.global_position
		_do_nav_move(delta, _get_move_speed())
		return
	# In range — shoot
	if _shooting:
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_shooting = true
	var frames   : int   = _sprite.sprite_frames.get_frame_count("shoot")
	var fps      : float = _sprite.sprite_frames.get_animation_speed("shoot")
	var anim_dur : float = frames / fps
	_sprite.speed_scale = maxf(1.0, anim_dur / _get_attack_rate())
	_sprite.play("shoot")
	var half_dur : float = (anim_dur / _sprite.speed_scale) * 0.5
	await get_tree().create_timer(half_dur).timeout
	_sprite.speed_scale = 1.0
	if is_instance_valid(_training_dummy) and _training_dummy.get("is_active"):
		var dmg   : int  = _get_attack_damage()
		var arrow        := ARROW_SCENE.instantiate()
		get_parent().add_child(arrow)
		arrow.global_position = global_position
		arrow.init(_training_dummy, 0, null)  # damage=0, we deal it directly below
		_training_dummy.take_damage(dmg, self)
		grant_xp(int(dmg * 0.5))
	_shooting     = false
	_attack_timer = _get_attack_rate()
	_sprite.speed_scale = 1.0
	_sprite.play("idle")
