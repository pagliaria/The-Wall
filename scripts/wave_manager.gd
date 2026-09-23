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

const TOTAL_WAVES    : int   = 15
const BOSS_WAVE_CAT  : int   = 5
const BOSS_WAVE_WITCH : int  = 10
const BOSS_WAVE_PENGU : int  = 15

const WAVE_COMPOSITIONS : Array = [
	# ── Wave 1 — Tutorial: slimes and a few warriors ──────────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",   "count": 3},
		{"path": "res://scenes/enemy_warrior.tscn", "count": 3},
	],
	# ── Wave 2 — Badgers introduced ───────────────────────────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",   "count": 4},
		{"path": "res://scenes/enemy_warrior.tscn", "count": 4},
		{"path": "res://scenes/enemy_badger.tscn",  "count": 2},
	],
	# ── Wave 3 — More pressure, skeletons appear ──────────────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",    "count": 5},
		{"path": "res://scenes/enemy_warrior.tscn",  "count": 5},
		{"path": "res://scenes/enemy_badger.tscn",   "count": 3},
		{"path": "res://scenes/enemy_skeleton.tscn", "count": 4},
	],
	# ── Wave 4 — Boars introduced, building up to boss ────────────────────
	[
		{"path": "res://scenes/enemy_warrior.tscn",  "count": 6},
		{"path": "res://scenes/enemy_badger.tscn",   "count": 4},
		{"path": "res://scenes/enemy_skeleton.tscn", "count": 6},
		{"path": "res://scenes/enemy_boar.tscn",     "count": 2},
	],
	# ── Wave 5 — BOSS: Cat Boss + bodyguard boars ─────────────────────────
	[
		{"path": "res://scenes/enemy_cat_boss.tscn", "count": 1},
		{"path": "res://scenes/enemy_boar.tscn",     "count": 3},
		{"path": "res://scenes/enemy_warrior.tscn",  "count": 4},
	],
	# ── Wave 6 — Post-boss relief, witch doctors teased ───────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",       "count": 6},
		{"path": "res://scenes/enemy_badger.tscn",       "count": 5},
		{"path": "res://scenes/enemy_witch_doctor.tscn", "count": 1},
	],
	# ── Wave 7 — Skeleton swarms begin ────────────────────────────────────
	[
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 12},
		{"path": "res://scenes/enemy_warrior.tscn",     "count": 5},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 2},
	],
	# ── Wave 8 — Boars and badgers combined ───────────────────────────────
	[
		{"path": "res://scenes/enemy_boar.tscn",        "count": 4},
		{"path": "res://scenes/enemy_badger.tscn",       "count": 6},
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 8},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 2},
	],
	# ── Wave 9 — Everything before boss 2, full chaos ─────────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",       "count": 8},
		{"path": "res://scenes/enemy_warrior.tscn",     "count": 8},
		{"path": "res://scenes/enemy_boar.tscn",        "count": 4},
		{"path": "res://scenes/enemy_badger.tscn",      "count": 5},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 3},
	],
	# ── Wave 10 — BOSS: Witch Doctor Boss + skeleton army ─────────────────
	[
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 1},
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 16},
		{"path": "res://scenes/enemy_badger.tscn",      "count": 4},
	],
	# ── Wave 11 — Post-boss, pengu teased via environment ─────────────────
	[
		{"path": "res://scenes/enemy_warrior.tscn",     "count": 10},
		{"path": "res://scenes/enemy_boar.tscn",        "count": 5},
		{"path": "res://scenes/enemy_badger.tscn",      "count": 6},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 2},
	],
	# ── Wave 12 — Skeleton flood ───────────────────────────────────────────
	[
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 20},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 3},
		{"path": "res://scenes/enemy_boar.tscn",        "count": 4},
	],
	# ── Wave 13 — All enemy types, max pressure ────────────────────────────
	[
		{"path": "res://scenes/enemy_slime.tscn",       "count": 8},
		{"path": "res://scenes/enemy_warrior.tscn",     "count": 8},
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 10},
		{"path": "res://scenes/enemy_boar.tscn",        "count": 5},
		{"path": "res://scenes/enemy_badger.tscn",      "count": 6},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 3},
	],
	# ── Wave 14 — Final gauntlet before pengu ─────────────────────────────
	[
		{"path": "res://scenes/enemy_cat_boss.tscn",    "count": 1},
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 12},
		{"path": "res://scenes/enemy_boar.tscn",        "count": 6},
		{"path": "res://scenes/enemy_witch_doctor.tscn","count": 3},
		{"path": "res://scenes/enemy_badger.tscn",      "count": 6},
	],
	# ── Wave 15 — FINAL BOSS: Pengu ───────────────────────────────────────
	[
		{"path": "res://scenes/enemy_pengu_boss.tscn",  "count": 1},
		{"path": "res://scenes/enemy_skeleton.tscn",    "count": 10},
		{"path": "res://scenes/enemy_warrior.tscn",     "count": 6},
	],
]

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
var _hired_units  : Array = []
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

	# Units are now committed — gate's closed. Snapshot the defense for VS mode
	# mirroring before anything moves or dies during the fight that follows.
	var defense_snapshot : Dictionary = capture_defense_snapshot()
	_save_snapshot_to_disk(defense_snapshot)

	# ============================================================= #
	# TEMP TEST HOOK — DO NOT SHIP. Remove once step 3 (real match
	# loading) exists. Spawns the defense we JUST captured back in as
	# a mirrored hostile wave, purely to visually confirm the capture
	# -> reconstruct -> spawn pipeline works end to end. This means
	# solo waves will fight a mirrored copy of your OWN nomans defense
	# on top of the normal composition while this hook is active —
	# that's expected for testing, not real gameplay behavior.
	# ============================================================= #
	if not defense_snapshot.get("units", []).is_empty() or not defense_snapshot.get("hired_units", []).is_empty():
		spawn_mirrored_defense(defense_snapshot)

	call_deferred("_begin_battle")

	emit_signal("wave_started", _wave_number)
	emit_signal("enemy_count_changed", _enemies.size())
	_battle_check = BATTLE_CHECK_RATE
	_retarget_timer = RETARGET_RATE

# =========================================================================== #
#  VS mode — defense snapshot capture
# =========================================================================== #

const SNAPSHOT_DIR := "user://defense_snapshots"

# Captures every player unit currently committed to this wave (already inside
# the nomans zone when the gate closed) as plain data: type, level, exact
# position, equipped items, and current building-bonus totals. No buildings,
# no locations of buildings — only what an opposing player's wilds-side
# enemies need to reconstruct an equivalent unit and place it precisely.
func capture_defense_snapshot() -> Dictionary:
	var units_data : Array = []
	for u in _player_units:
		if not is_instance_valid(u):
			continue
		units_data.append({
			"unit_type":        _get_unit_type_key(u),
			"level":            int(u.level) if u.get("level") != null else 1,
			"position":         [u.global_position.x, u.global_position.y],
			"equipped_items":   _serialize_items(u),
			"building_bonuses": _serialize_building_bonuses(u),
		})
	return {
		"schema_version": 1,
		"day":            _wave_number,
		"captured_at":    Time.get_datetime_string_from_system(),
		"units":          units_data,
		"hired_units":    _serialize_hired_units(),
	}

# Hired units (house.gd) have no level/items/building bonuses to capture —
# they're plain enemy_*.tscn scenes with allegiance flipped, so every hire of
# a given hire_id is stat-identical by definition. Just id + position needed;
# reconstruction just instantiates the matching scene as a normal hostile enemy.
func _serialize_hired_units() -> Array:
	var out : Array = []
	for h in _hired_units:
		if not is_instance_valid(h):
			continue
		if not _is_in_player_battlefield(h.global_position):
			continue
		out.append({
			"hire_id":  str(h.get_meta("hire_id", "")),
			"position": [h.global_position.x, h.global_position.y],
		})
	return out

func _get_unit_type_key(unit: Node) -> String:
	# Script filename doubles as the scene name (warrior.gd / warrior.tscn),
	# which is exactly what the reconstruction step needs to respawn the type.
	var script : Script = unit.get_script()
	if script:
		return script.resource_path.get_file().get_basename()
	return "unit"

func _serialize_items(unit: Node) -> Array:
	var out      : Array = []
	var equipped = unit.get("_equipped_items")
	if equipped == null:
		return out
	for entry in equipped:
		out.append({
			"item_type": int(entry.get("type",   0)),
			"rarity":    int(entry.get("rarity", 0)),
		})
	return out

func _serialize_building_bonuses(unit: Node) -> Dictionary:
	var bonuses = unit.get("_building_bonuses")
	if bonuses == null or not (bonuses is Dictionary):
		return {}
	return (bonuses as Dictionary).duplicate()

func _save_snapshot_to_disk(snapshot: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SNAPSHOT_DIR)
	var path : String = "%s/wave_%d.json" % [SNAPSHOT_DIR, int(snapshot.get("day", 0))]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write defense snapshot to " + path)
		return
	f.store_string(JSON.stringify(snapshot, "\t"))
	f.close()
	print("Defense snapshot saved: ", path)

func _begin_battle() -> void:
	_player_units = _get_battlefield_player_units()
	_enemies = _get_battlefield_enemies()

	# Snapshot each battle unit's position so we can teleport survivors home.
	_battle_start_positions.clear()
	for u in _player_units:
		if is_instance_valid(u):
			_battle_start_positions[u] = u.global_position
	for h in _hired_units:
		if is_instance_valid(h):
			_battle_start_positions[h] = h.global_position

	var all_friendlies : Array = _player_units + _hired_units
	for e in _enemies:
		if is_instance_valid(e) and e.has_method("start_battle"):
			e.start_battle(all_friendlies)

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("start_battle"):
			u.start_battle(_enemies)
	_hired_units = _hired_units.filter(func(u): return is_instance_valid(u))
	for h in _hired_units:
		if h.has_method("start_battle"):
			h.start_battle(_enemies)

# =========================================================================== #
#  Rush wave — public API called by main.gd
# =========================================================================== #

func get_enemies() -> Array:
	return _enemies

func get_player_units() -> Array:
	return _player_units

func get_hired_units() -> Array:
	return _hired_units

func register_hired_unit(unit: Node) -> void:
	_hired_units.append(unit)
	# Defer start_battle so @onready vars are initialized first
	if _phase == Phase.BATTLE and not _enemies.is_empty():
		var enemies_copy : Array = _enemies.duplicate()
		unit.call_deferred("start_battle", enemies_copy)

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
	if _wave_number >= TOTAL_WAVES:
		return
	_countdown = WAVE_INTERVAL
	_phase = Phase.PREP
	_spawn_queue.clear()
	var composition : Array = WAVE_COMPOSITIONS[_wave_number]
	for entry in composition:
		var scene := _get_scene(entry["path"])
		if scene == null:
			continue
		for _i in entry["count"]:
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

# Formation tiers — X position bands (left = back, right = front/wall)
const FORMATION_FRONT  : float = 480.0  # melee — closest to wall
const FORMATION_MID    : float = 300.0  # skeletons, boars
const FORMATION_BACK   : float = 140.0  # ranged, support
const FORMATION_BOSS   : float = 220.0  # bosses — mid-back
const FORMATION_JITTER : float = 60.0   # random spread within tier

# Map scene filename to formation tier X
const FORMATION_TIERS : Dictionary = {
	"enemy_warrior":     FORMATION_FRONT,
	"enemy_boar":        FORMATION_FRONT,
	"enemy_skeleton":    FORMATION_MID,
	"enemy_slime":       FORMATION_MID,
	"enemy_badger":      FORMATION_BACK,
	"enemy_witch_doctor": FORMATION_BACK,
	"enemy_cat_boss":    FORMATION_BOSS,
	"enemy_pengu_boss":  FORMATION_BOSS,
}

func _get_formation_x(scene: PackedScene) -> float:
	var key : String = scene.resource_path.get_file().get_basename()
	return FORMATION_TIERS.get(key, FORMATION_MID)

func _spawn_one(scene: PackedScene) -> void:
	var e : CharacterBody2D = scene.instantiate()
	units_layer.add_child(e)
	var base_x : float = _get_formation_x(scene)
	e.position = Vector2(
		base_x + _rng.randf_range(-FORMATION_JITTER, FORMATION_JITTER),
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
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	_hired_units  = _hired_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	var all_friendlies : Array = _player_units + _hired_units
	for e in _enemies:
		e.update_target(all_friendlies)
	for u in _player_units:
		if u.has_method("update_battle_target"):
			u.update_battle_target(_enemies)
	for h in _hired_units:
		if h.has_method("update_hired_target"):
			h.update_hired_target(_enemies)

func _check_battle_over() -> void:
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	_hired_units  = _hired_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	if _enemies.is_empty():
		_end_wave(true)
	elif _player_units.is_empty() and _hired_units.is_empty():
		_end_wave(false)

func _end_wave(player_won: bool) -> void:
	_phase = Phase.NONE

	if is_instance_valid(drawbridge):
		drawbridge.force_lower()

	# Teleport survivors back to where they stood when the battle started.
	for u in _player_units:
		if is_instance_valid(u) and _battle_start_positions.has(u):
			u.global_position = _battle_start_positions[u]
	for h in _hired_units:
		if is_instance_valid(h) and _battle_start_positions.has(h):
			h.global_position = _battle_start_positions[h]
	_battle_start_positions.clear()

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("end_battle"):
			u.end_battle()
	for h in _hired_units:
		if is_instance_valid(h):
			h.set("_target", null)
			h.set("_battle_ready", false)
			h.set("_hired_moving", false)
			if h.has_method("_enter_state"):
				h.call("_enter_state", 0)  # State.IDLE = 0

	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_player_units.clear()

	if player_won and _wave_number >= TOTAL_WAVES:
		# Final boss defeated — game complete
		emit_signal("wave_ended", true)
		return

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
	enemy.set("summoned", true)
	units_layer.add_child(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	# Guarded: a mirrored non-combat unit (e.g. a Pawn caught standing in
	# nomans when the gate closed) has no start_battle at all — it'll just sit
	# in _enemies as an inert, killable liability instead of crashing.
	if enemy.has_method("start_battle"):
		enemy.start_battle(_player_units)
	_enemies.append(enemy)
	emit_signal("enemy_count_changed", _enemies.size())

# =========================================================================== #
#  VS mode — reconstruction / mirrored spawn
# =========================================================================== #

const ITEM_SCRIPT  : GDScript = preload("res://scripts/item.gd")
const HouseScript   : GDScript = preload("res://scripts/house.gd")

# Mirrors a nomans-zone position (x in [640,1280]) across the shared battle
# separator line into the wilds zone (x in [0,640]). A unit standing right at
# the separator (most forward/aggressive defense) maps to the separator on
# the wilds side too, so it's still the first thing the attacker runs into; a
# unit tucked back near the wall maps to the far edge of the wilds, as far
# from the fight as possible. Y is unchanged — both zones share the same
# vertical extent.
func _mirror_position(nomans_pos: Array) -> Vector2:
	var nomans_x : float = float(nomans_pos[0]) if nomans_pos.size() > 0 else BATTLEFIELD_MID
	var nomans_y : float = float(nomans_pos[1]) if nomans_pos.size() > 1 else 0.0
	var wilds_x  : float = 2.0 * BATTLEFIELD_MID - nomans_x
	return Vector2(wilds_x, nomans_y)

# Takes a snapshot dict in the shape capture_defense_snapshot() produces (from
# this game or, eventually, downloaded from another player) and spawns its
# units as hostile enemies in the wilds zone, mirrored across the separator.
# Must be called while a battle is active (_phase == BATTLE) since it relies
# on register_enemy() for _enemies tracking and start_battle wiring — the
# natural call site is inside _start_wave(), once _phase has been set.
func spawn_mirrored_defense(snapshot: Dictionary) -> void:
	for entry in snapshot.get("units", []):
		var unit : CharacterBody2D = _build_mirrored_unit(entry)
		if unit != null:
			register_enemy(unit)
	for entry in snapshot.get("hired_units", []):
		var unit : CharacterBody2D = _build_mirrored_hired_unit(entry)
		if unit != null:
			register_enemy(unit)
			# register_enemy() flags every summon as "summoned" to stop mid-battle
			# reinforcements from dropping loot. A mirrored defender isn't a
			# throwaway summon though — it should drop chests like any real
			# enemy would, so clear the flag right back off.
			unit.set("summoned", false)

# Convenience for testing against a file saved by _save_snapshot_to_disk().
func spawn_mirrored_defense_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("Snapshot file not found: " + path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var text : String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Snapshot file is not valid JSON: " + path)
		return false
	spawn_mirrored_defense(parsed)
	return true

func _build_mirrored_unit(entry: Dictionary) -> CharacterBody2D:
	var unit_type  : String = str(entry.get("unit_type", ""))
	var scene_path : String = "res://scenes/%s.tscn" % unit_type
	if not ResourceLoader.exists(scene_path):
		push_warning("Mirrored defense: unknown unit_type '%s'" % unit_type)
		return null
	var unit : CharacterBody2D = load(scene_path).instantiate()
	unit.faction  = "enemy"
	unit.position = _mirror_position(entry.get("position", []))
	units_layer.add_child(unit)

	if unit.has_method("set_level_directly"):
		unit.set_level_directly(int(entry.get("level", 1)))

	if unit.has_method("apply_item"):
		for item_entry in entry.get("equipped_items", []):
			var temp_item := Node2D.new()
			temp_item.set_script(ITEM_SCRIPT)
			temp_item.call("setup", int(item_entry.get("item_type", 0)), int(item_entry.get("rarity", 0)))
			unit.apply_item(temp_item)
			temp_item.free()

	if unit.has_method("apply_building_bonuses"):
		unit.apply_building_bonuses(entry.get("building_bonuses", {}))

	return unit

func _build_mirrored_hired_unit(entry: Dictionary) -> CharacterBody2D:
	var hire_id    : String = str(entry.get("hire_id", ""))
	var scene_path : String = ""
	for roster_entry in HouseScript.HIRE_ROSTER:
		if str(roster_entry.get("id", "")) == hire_id:
			scene_path = str(roster_entry.get("scene", ""))
			break
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_warning("Mirrored defense: unknown hire_id '%s'" % hire_id)
		return null
	var unit : CharacterBody2D = load(scene_path).instantiate()
	# Deliberately skip set_hired() — default faction is already "enemy", exactly
	# the hostile posture we want. No stats to reconstruct: every hire of a given
	# id is stat-identical by definition (flat @export defaults, see house.gd).
	unit.position = _mirror_position(entry.get("position", []))
	units_layer.add_child(unit)
	return unit
