extends Node

# WaveManager — owns the wave countdown, enemy spawning, and battle trigger.
#
# Zones (world-space x):
#   Enemy mill zone  : x   0 – 640   (cols  0–9,  left half of wilds)
#   Deployment zone  : x 640 – 1280  (cols 10–19, right half, player puts units)
#   Town zone        : x 1280+       (col 20+, behind the wall)
#
# Wave flow:
#   1. Countdown timer ticks down (visible on HUD)
#   2. At 0: drawbridge raises, gate closes, battle starts
#   3. All enemies find nearest player unit and fight
#   4. All player units in the deployment zone find nearest enemy and fight
#   5. When one side is wiped, battle ends — next wave countdown begins

signal wave_countdown_changed(seconds_left: float)
signal wave_started(wave_number: int)
signal wave_ended(player_won: bool)
signal enemy_count_changed(count: int)

# -- Tuning -------------------------------------------------------------------
const WAVE_INTERVAL      = 90.0   # seconds between waves
const BATTLE_CHECK_RATE  = 0.5    # how often we check if battle is over
const RETARGET_RATE      = 1.0    # how often enemies/units re-pick targets

# Spawn counts scale per wave: base + (wave-1) * scale
const ENEMY_BASE_COUNT   = 4
const ENEMY_SCALE        = 2      # extra enemies per wave

# Enemy spawn band (world-space)
const SPAWN_MIN_X = 48.0
const SPAWN_MAX_X = 580.0
const SPAWN_MIN_Y = 200.0
const SPAWN_MAX_Y = 1520.0

# Deployment zone x boundary — player units east of this join the battle
const DEPLOY_MAX_X = 1280.0

# -- State --------------------------------------------------------------------
enum Phase { PREP, BATTLE }
var _phase          : Phase = Phase.PREP
var _wave_number    : int   = 0
var _countdown      : float = WAVE_INTERVAL
var _battle_check   : float = 0.0
var _retarget_timer : float = 0.0

var _enemies        : Array = []   # live Enemy nodes
var _player_units   : Array = []   # player units currently in deploy zone

# -- Injected by main.gd ------------------------------------------------------
var units_layer    : Node2D  = null
var drawbridge     : Node    = null   # drawbridge.gd node
var enemy_scene    : PackedScene = null

var _rng := RandomNumberGenerator.new()

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
			_battle_check -= delta
			_retarget_timer -= delta
			if _retarget_timer <= 0.0:
				_retarget_timer = RETARGET_RATE
				_do_retarget()
			if _battle_check <= 0.0:
				_battle_check = BATTLE_CHECK_RATE
				_check_battle_over()

# =========================================================================== #
#  Wave start
# =========================================================================== #

func _start_wave() -> void:
	_wave_number += 1
	_phase = Phase.BATTLE

	# Close the drawbridge
	if is_instance_valid(drawbridge):
		drawbridge.force_raise()

	# Spawn enemies
	var count := ENEMY_BASE_COUNT + (_wave_number - 1) * ENEMY_SCALE
	for i in count:
		_spawn_enemy()

	# Collect player units in the deployment zone
	_player_units = _get_deploy_zone_units()

	# Tell each enemy to start fighting
	for e in _enemies:
		if is_instance_valid(e):
			e.start_battle(_player_units)

	# Tell player units in deploy zone to start fighting
	for u in _player_units:
		if is_instance_valid(u) and u.has_method("start_battle"):
			u.start_battle(_enemies)

	emit_signal("wave_started", _wave_number)
	emit_signal("enemy_count_changed", _enemies.size())
	_battle_check   = BATTLE_CHECK_RATE
	_retarget_timer = RETARGET_RATE

func _spawn_enemy() -> void:
	if enemy_scene == null:
		push_error("WaveManager: enemy_scene not set")
		return
	var e : CharacterBody2D = enemy_scene.instantiate()
	units_layer.add_child(e)
	e.position = Vector2(
		_rng.randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
		_rng.randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
	)
	e.died.connect(_on_enemy_died.bind(e))
	_enemies.append(e)

func _get_deploy_zone_units() -> Array:
	var result : Array = []
	if units_layer == null:
		return result
	for u in units_layer.get_children():
		# Only units west of the wall and not enemies
		if u.has_method("take_damage") and u.get("faction") != "enemy":
			if u.position.x <= DEPLOY_MAX_X:
				result.append(u)
	return result

# =========================================================================== #
#  Battle upkeep
# =========================================================================== #

func _do_retarget() -> void:
	# Clean dead refs first
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e))
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)

	for e in _enemies:
		if is_instance_valid(e):
			e.update_target(_player_units)

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("update_battle_target"):
			u.update_battle_target(_enemies)

func _check_battle_over() -> void:
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e))
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)

	if _enemies.is_empty():
		_end_wave(true)
	elif _player_units.is_empty():
		_end_wave(false)

func _end_wave(player_won: bool) -> void:
	_phase = Phase.PREP
	_countdown = WAVE_INTERVAL

	# Open the drawbridge
	if is_instance_valid(drawbridge):
		drawbridge.force_lower()

	# Pull surviving player units back to idle
	for u in _player_units:
		if is_instance_valid(u) and u.has_method("end_battle"):
			u.end_battle()

	# Clean up any leftover enemies
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_player_units.clear()

	emit_signal("wave_ended", player_won)
	emit_signal("wave_countdown_changed", _countdown)

# =========================================================================== #
#  Enemy died callback
# =========================================================================== #

func _on_enemy_died(enemy: Node) -> void:
	_enemies.erase(enemy)
	emit_signal("enemy_count_changed", _enemies.size())
