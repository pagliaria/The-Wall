extends Node

signal wave_countdown_changed(seconds_left: float)
signal wave_started(wave_number: int)
signal wave_ended(player_won: bool)
signal enemy_count_changed(count: int)

const WAVE_INTERVAL     = 90.0
const SPAWN_END_TIME    = 30.0
const BATTLE_CHECK_RATE = 0.5
const RETARGET_RATE     = .5

const SPAWN_MIN_X = 48.0
const SPAWN_MAX_X = 580.0
const SPAWN_MIN_Y = 200.0
const SPAWN_MAX_Y = 1520.0

const BATTLEFIELD_LEFT  = 0.0
const BATTLEFIELD_MID   = 640.0
const BATTLEFIELD_RIGHT = 1280.0

const WAVE_COMPOSITIONS : Array = [
	# Wave 1
	[{ "path": "res://scenes/enemy_slime.tscn", "count": 2 },
	{ "path": "res://scenes/enemy_warrior.tscn", "count": 2 },
	{ "path": "res://scenes/enemy_badger.tscn", "count": 2 }],
	# Wave 2
	[{ "path": "res://scenes/enemy_slime.tscn", "count": 5 },
	{ "path": "res://scenes/enemy_badger.tscn", "count": 2 },
	{ "path": "res://scenes/enemy_warrior.tscn", "count": 5 }],
	# Wave 3
	[{ "path": "res://scenes/enemy_slime.tscn", "count": 10 },
	{ "path": "res://scenes/enemy_badger.tscn", "count": 5 },
	{ "path": "res://scenes/enemy_warrior.tscn", "count": 5 }],
	# Wave 4 BOSS
	[{ "path": "res://scenes/enemy_cat_boss.tscn", "count": 1 }],
]
const LATE_WAVE_SCALE : float = 1.5

enum Phase { PREP, BATTLE , NONE}

var _phase          : Phase = Phase.NONE
var _wave_number    : int   = 0
var _countdown      : float = WAVE_INTERVAL
var _battle_check   : float = 0.0
var _retarget_timer : float = 0.0
var _spawn_timer    : float = 0.0
var _spawn_step     : float = 0.0

var _enemies      : Array = []
var _player_units : Array = []
var _spawn_queue  : Array = []
var _battle_start_positions : Dictionary = {}

var units_layer : Node2D = null
var drawbridge  : Node   = null

var _rng         := RandomNumberGenerator.new()
var _scene_cache := {}

func _ready() -> void:
	_rng.randomize()
	#_prepare_next_wave()

func _process(delta: float) -> void:
	match _phase:
		Phase.PREP:
			_countdown -= delta
			_process_prep_spawns(delta)
			emit_signal("wave_countdown_changed", maxf(0.0, _countdown))
			if _countdown <= 0.0:
				_start_wave()
		Phase.BATTLE:
			_retarget_timer -= delta
			if _retarget_timer <= 0.0:
				_retarget_timer = RETARGET_RATE
				_do_retarget()
			_battle_check -= delta
			if _battle_check <= 0.0:
				_battle_check = BATTLE_CHECK_RATE
				_check_battle_over()

func _start_wave() -> void:
	_wave_number += 1
	_phase = Phase.BATTLE

	if is_instance_valid(drawbridge):
		drawbridge.force_raise()

	_spawn_remaining_prep_enemies()
	_player_units = _get_battlefield_player_units()

	call_deferred("_begin_battle")

	emit_signal("wave_started", _wave_number)
	emit_signal("enemy_count_changed", _enemies.size())
	_battle_check = BATTLE_CHECK_RATE
	_retarget_timer = RETARGET_RATE

func _begin_battle() -> void:
	_player_units = _get_battlefield_player_units()
	_enemies = _get_battlefield_enemies()

	# Snapshot each battle unit's position so we can teleport survivors home.
	_battle_start_positions.clear()
	for u in _player_units:
		if is_instance_valid(u):
			_battle_start_positions[u] = u.global_position

	for e in _enemies:
		if is_instance_valid(e):
			e.start_battle(_player_units)

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("start_battle"):
			u.start_battle(_enemies)

# =========================================================================== #
#  Rush wave — public API called by main.gd
# =========================================================================== #

func is_in_prep() -> bool:
	return _phase == Phase.PREP

func get_countdown() -> float:
	return _countdown

func rush_wave() -> Dictionary:
	if _phase != Phase.PREP:
		return {}
	var reward : Dictionary = calc_rush_reward(_countdown)
	_countdown = 0.0
	return reward

func calc_rush_reward(seconds_left: float) -> Dictionary:
	var ratio : float = clampf(seconds_left / WAVE_INTERVAL, 0.0, 1.0)
	var reward : Dictionary = {}
	reward["gold"] = int(25.0 * ratio)
	if ratio >= 0.5:
		reward["wood"] = int(20.0 * ratio)
	if ratio >= 0.7:
		reward["meat"] = int(10.0 * ratio)
	return reward

func _prepare_next_wave() -> void:
	_countdown = WAVE_INTERVAL
	_phase = Phase.PREP
	_spawn_queue.clear()
	var comp_index := mini(_wave_number, WAVE_COMPOSITIONS.size() - 1)
	var composition : Array = WAVE_COMPOSITIONS[comp_index]
	var overflow := maxi(0, _wave_number + 1 - WAVE_COMPOSITIONS.size())
	var scale := 1.0 + overflow * (LATE_WAVE_SCALE - 1.0)

	for entry in composition:
		var count := int(ceil(float(entry["count"]) * scale))
		var scene := _get_scene(entry["path"])
		if scene == null:
			continue
		for _i in count:
			_spawn_queue.append(scene)

	if _spawn_queue.is_empty():
		_spawn_step = 0.0
	else:
		_spawn_step = (WAVE_INTERVAL - SPAWN_END_TIME) / float(_spawn_queue.size())
	_spawn_timer = 0.0

func _process_prep_spawns(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	if _countdown <= SPAWN_END_TIME or _spawn_step <= 0.0:
		_spawn_remaining_prep_enemies()
		return
	_spawn_timer += delta
	while _spawn_timer >= _spawn_step and not _spawn_queue.is_empty():
		_spawn_timer -= _spawn_step
		var scene: PackedScene = _spawn_queue.pop_front()
		_spawn_one(scene)

func _spawn_remaining_prep_enemies() -> void:
	while not _spawn_queue.is_empty():
		var scene: PackedScene = _spawn_queue.pop_front()
		_spawn_one(scene)

func _spawn_one(scene: PackedScene) -> void:
	var e : CharacterBody2D = scene.instantiate()
	units_layer.add_child(e)
	e.position = Vector2(
		_rng.randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
		_rng.randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
	)
	e.died.connect(_on_enemy_died.bind(e))
	_enemies.append(e)
	emit_signal("enemy_count_changed", _enemies.size())

func _get_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

func _get_battlefield_player_units() -> Array:
	var result : Array = []
	if units_layer == null:
		return result
	for u in units_layer.get_children():
		if not u.has_method("take_damage"):
			continue
		var f = u.get("faction")
		if f == null or f != "player":
			continue
		if u.get("hp") != null and u.hp > 0 and _is_in_player_battlefield(u.global_position):
			result.append(u)
	return result

func _get_battlefield_enemies() -> Array:
	var result : Array = []
	for e in _enemies:
		if is_instance_valid(e) and e.hp > 0 and _is_in_enemy_battlefield(e.global_position):
			result.append(e)
	return result

func _is_in_player_battlefield(pos: Vector2) -> bool:
	return pos.x >= BATTLEFIELD_MID and pos.x < BATTLEFIELD_RIGHT

func _is_in_enemy_battlefield(pos: Vector2) -> bool:
	return pos.x >= BATTLEFIELD_LEFT and pos.x < BATTLEFIELD_RIGHT

func _do_retarget() -> void:
	_enemies = _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	for e in _enemies:
		e.update_target(_player_units)
	for u in _player_units:
		if u.has_method("update_battle_target"):
			u.update_battle_target(_enemies)

func _check_battle_over() -> void:
	_enemies = _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	if _enemies.is_empty():
		_end_wave(true)
	elif _player_units.is_empty():
		_end_wave(false)

func _end_wave(player_won: bool) -> void:
	_phase = Phase.NONE

	if is_instance_valid(drawbridge):
		drawbridge.force_lower()

	# Teleport survivors back to where they stood when the battle started.
	for u in _player_units:
		if is_instance_valid(u) and _battle_start_positions.has(u):
			u.global_position = _battle_start_positions[u]
	_battle_start_positions.clear()

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("end_battle"):
			u.end_battle()

	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_player_units.clear()
	#_prepare_next_wave()

	emit_signal("wave_ended", player_won)

func _on_enemy_died(enemy: Node) -> void:
	_enemies.erase(enemy)
	emit_signal("enemy_count_changed", _enemies.size())

# =========================================================================== #
#  Public hook — call from any enemy script to register a mid-battle spawn
# =========================================================================== #

func register_enemy(enemy: CharacterBody2D) -> void:
	if _phase != Phase.BATTLE:
		return
	units_layer.add_child(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.start_battle(_player_units)
	_enemies.append(enemy)
	emit_signal("enemy_count_changed", _enemies.size())
