extends Node

signal wave_countdown_changed(seconds_left: float)
signal wave_started(wave_number: int)
signal wave_ended(player_won: bool)
signal enemy_count_changed(count: int)

const WAVE_INTERVAL     = 90.0
const BATTLE_CHECK_RATE = 0.5
const RETARGET_RATE     = 1.0

const SPAWN_MIN_X = 48.0
const SPAWN_MAX_X = 580.0
const SPAWN_MIN_Y = 200.0
const SPAWN_MAX_Y = 1520.0

# Collect ALL player combat units regardless of position — the wave manager
# doesn't restrict by zone at collection time; positioning is the player's job.
# We exclude pawns (no faction var) and units already dead.
const WAVE_COMPOSITIONS : Array = [
	[{ "path": "res://scenes/enemy_warrior.tscn", "count": 4 }],
	[{ "path": "res://scenes/enemy_warrior.tscn", "count": 6 }],
	[{ "path": "res://scenes/enemy_warrior.tscn", "count": 8 }],
]
const LATE_WAVE_SCALE : float = 1.5

enum Phase { PREP, BATTLE }
var _phase          : Phase = Phase.PREP
var _wave_number    : int   = 0
var _countdown      : float = WAVE_INTERVAL
var _battle_check   : float = 0.0
var _retarget_timer : float = 0.0

var _enemies      : Array = []
var _player_units : Array = []

var units_layer : Node2D = null
var drawbridge  : Node   = null

var _rng         := RandomNumberGenerator.new()
var _scene_cache := {}

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	match _phase:
		Phase.PREP:
			_countdown -= delta
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

# =========================================================================== #
#  Wave start
# =========================================================================== #

func _start_wave() -> void:
	_wave_number += 1
	_phase = Phase.BATTLE

	if is_instance_valid(drawbridge):
		drawbridge.force_raise()

	_spawn_wave_enemies()

	# Collect player units — any combat unit currently alive
	_player_units = _get_all_player_combat_units()

	# Defer start_battle by one frame so enemy _ready() / _initial_state()
	# has already run, preventing _initial_state from overwriting BATTLE state.
	call_deferred("_begin_battle")

	emit_signal("wave_started", _wave_number)
	emit_signal("enemy_count_changed", _enemies.size())
	_battle_check   = BATTLE_CHECK_RATE
	_retarget_timer = RETARGET_RATE

func _begin_battle() -> void:
	# Re-collect player units after the deferred frame so newly-ready units
	# are included and any that died in the meantime are excluded.
	_player_units = _get_all_player_combat_units()

	for e in _enemies:
		if is_instance_valid(e):
			e.start_battle(_player_units)

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("start_battle"):
			u.start_battle(_enemies)

func _spawn_wave_enemies() -> void:
	var comp_index  := mini(_wave_number - 1, WAVE_COMPOSITIONS.size() - 1)
	var composition : Array = WAVE_COMPOSITIONS[comp_index]
	var overflow    := maxi(0, _wave_number - WAVE_COMPOSITIONS.size())
	var scale       := 1.0 + overflow * (LATE_WAVE_SCALE - 1.0)

	for entry in composition:
		var count := int(ceil(float(entry["count"]) * scale))
		var scene := _get_scene(entry["path"])
		if scene == null:
			continue
		for _i in count:
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

func _get_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

func _get_all_player_combat_units() -> Array:
	var result : Array = []
	if units_layer == null:
		return result
	for u in units_layer.get_children():
		# Must have hp and be a player faction unit (excludes enemies and pawns)
		if not u.has_method("take_damage"):
			continue
		var f = u.get("faction")
		if f == null or f != "player":
			continue
		if u.get("hp") != null and u.hp > 0:
			result.append(u)
	return result

# =========================================================================== #
#  Battle upkeep
# =========================================================================== #

func _do_retarget() -> void:
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e))
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	for e in _enemies:
		e.update_target(_player_units)
	for u in _player_units:
		if u.has_method("update_battle_target"):
			u.update_battle_target(_enemies)

func _check_battle_over() -> void:
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e))
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	if _enemies.is_empty():
		_end_wave(true)
	elif _player_units.is_empty():
		_end_wave(false)

func _end_wave(player_won: bool) -> void:
	_phase     = Phase.PREP
	_countdown = WAVE_INTERVAL

	if is_instance_valid(drawbridge):
		drawbridge.force_lower()

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("end_battle"):
			u.end_battle()

	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_player_units.clear()

	emit_signal("wave_ended", player_won)
	emit_signal("wave_countdown_changed", _countdown)

func _on_enemy_died(enemy: Node) -> void:
	_enemies.erase(enemy)
	emit_signal("enemy_count_changed", _enemies.size())
