extends Node

signal wave_countdown_changed(seconds_left: float)
signal wave_started(wave_number: int)
signal wave_ended(player_won: bool)
signal enemy_count_changed(count: int)
# Versus HUD feed. state is a GameMode.VersusState value. Consumed by
# versus_status.gd (wired in main.gd, versus mode only).
signal versus_status_changed(state: int, opponent_name: String, opponent_power: int, detail: String)

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
# Subset of _hired_units committed to the current battle: only hires standing
# in the player battlefield when the gate closed. Town hires never join.
var _battle_hired_units : Array = []
var _spawn_queue  : Array = []
var _battle_start_positions : Dictionary = {}

var units_layer : Node2D = null
var drawbridge  : Node   = null

# Debug: when true, every wave's enemies are a mirror of the player's own
# defense instead of the PvE composition. Set by main.gd from the settings
# screen (Debug tab). Can flip mid-prep; _start_wave reconciles.
var debug_mirror_defense : bool = false

var _rng         := RandomNumberGenerator.new()
var _scene_cache := {}

func _ready() -> void:
	_rng.randomize()
	#_prepare_next_wave()
	if GameMode.is_versus():
		SnapshotService.opponent_fetched.connect(_on_opponent_fetched)
		SnapshotService.request_failed.connect(_on_snapshot_request_failed)

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

	_reconcile_debug_mirror_prep()
	_spawn_remaining_prep_enemies()
	_player_units = _get_battlefield_player_units()

	# Units are now committed — gate's closed. Solo: PvE composition already
	# spawned during prep, nothing more to do. Versus: capture own defense and
	# fight the opponent's mirrored defense instead.
	if debug_mirror_defense:
		_start_debug_mirror_battle()
	elif GameMode.is_versus():
		_start_versus_battle()

	call_deferred("_begin_battle")

	emit_signal("wave_started", _wave_number)
	emit_signal("enemy_count_changed", _enemies.size())
	_battle_check = BATTLE_CHECK_RATE
	_retarget_timer = RETARGET_RATE

# =========================================================================== #
#  VS mode — defense snapshot capture
# =========================================================================== #

const SNAPSHOT_DIR := "user://defense_snapshots"

# ── Snapshot schema + validation limits ─────────────────────────────────────
# Bump SNAPSHOT_SCHEMA_VERSION whenever the snapshot shape changes.
# BONUS_LIMITS mirror the max upgrade totals in placed_building.gd
# (3 levels each). If upgrade maxima change there, update here or valid
# snapshots get clamped.
const SNAPSHOT_SCHEMA_VERSION : int   = 2
const MAX_SNAPSHOT_UNITS      : int   = 60
const MAX_SNAPSHOT_HIRED      : int   = 40
const MAX_PLAYER_ID_LENGTH    : int   = 64
const SNAPSHOT_MIN_Y          : float = 0.0
const SNAPSHOT_MAX_Y          : float = 1728.0

const UnitBaseScript : GDScript = preload("res://scripts/unit_base.gd")

# Only these unit types may be rebuilt from a snapshot. Anything else in the
# data (including enemy_* or a path-ish string) is dropped.
const MIRRORABLE_UNIT_TYPES : Array[String] = ["pawn", "warrior", "archer", "monk", "lancer"]

const INT_BONUS_KEYS : Array[String] = ["attack_damage", "hp_bonus", "turn_in_bonus"]
const BONUS_LIMITS : Dictionary = {
	"attack_damage":           [0.0, 3.0],
	"attack_speed_multiplier": [0.65, 1.0],
	"move_speed_multiplier":   [1.0, 1.35],
	"hp_bonus":                [0.0, 12.0],
	"range_bonus":             [0.0, 120.0],
	"gather_speed_multiplier": [0.6, 1.0],
	"turn_in_bonus":           [0.0, 3.0],
}

# Power rating for matchmaking. Recomputed locally from cleaned data, never
# trusted from incoming snapshots. Tune freely.
const POWER_UNIT_BASE        : int         = 10
const POWER_PER_LEVEL        : int         = 5
const POWER_PER_ITEM_RARITY  : Array[int]  = [2, 4, 8]
const POWER_PER_BONUS_DAMAGE : int         = 2
const POWER_PER_BONUS_HP     : float       = 0.5
const POWER_HIRE_MULTIPLIER  : int         = 2

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
	var raw_snapshot : Dictionary = {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"player_id":      GameMode.player_id,
		"player_name":    GameMode.player_name,
		"game_version":   str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"day":            _wave_number,
		"captured_at":    Time.get_datetime_string_from_system(),
		"units":          units_data,
		"hired_units":    _serialize_hired_units(),
	}
	# Run our own output through the same sanitizer receivers will use, so
	# what we save/upload is exactly what will be accepted. Adds `power`.
	return sanitize_snapshot(raw_snapshot)

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
			"hire_id":  _get_hire_id(h),
			"position": [h.global_position.x, h.global_position.y],
		})
	return out

# Hired units bought at a house carry a "hire_id" meta. Units a hired unit
# summoned itself (a hired Witch Doctor's skeletons) don't, so fall back to
# matching the scene file against the roster. Returns "" if nothing matches
# (sanitize_snapshot drops those).
func _get_hire_id(unit: Node) -> String:
	var meta_id : String = str(unit.get_meta("hire_id", ""))
	if meta_id != "":
		return meta_id
	for roster_entry : Dictionary in HouseScript.HIRE_ROSTER:
		if str(roster_entry.get("scene", "")) == unit.scene_file_path:
			return str(roster_entry.get("id", ""))
	return ""

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

# Versus wave start. Snapshots this player's defense BEFORE anything moves or
# dies (this is what gets uploaded for other players to fight), then spawns the
# opponent's snapshot as the hostile wave.
func _start_versus_battle() -> void:
	var own_snapshot : Dictionary = capture_defense_snapshot()
	# Empty defense is never saved (and must never be uploaded in step 5+):
	# an opponent fighting a mirror of nothing gets a free win.
	if is_snapshot_empty(own_snapshot):
		push_warning("Versus: defense snapshot empty, not saved.")
	else:
		_save_snapshot_to_disk(own_snapshot)
		SnapshotService.upload_snapshot(own_snapshot)
	var opponent_snapshot : Dictionary = _get_opponent_snapshot(own_snapshot)
	var spawned : int = spawn_mirrored_defense(opponent_snapshot)
	if spawned == 0:
		push_warning("Versus: opponent snapshot had no valid units, using PvE wave %d." % _wave_number)
		_spawn_pve_fallback()
		versus_status_changed.emit(GameMode.VersusState.BATTLE_PVE, "", 0, "Wave %d" % _wave_number)
	else:
		var opponent_name : String = str(opponent_snapshot.get("player_name", ""))
		if opponent_name == "":
			opponent_name = "Unknown"
		versus_status_changed.emit(GameMode.VersusState.BATTLE_OPPONENT, opponent_name, int(opponent_snapshot.get("power", 0)), "")

# Source of the opponent's defense for this wave: whatever _begin_opponent_fetch
# managed to download during prep. Empty if nothing arrived (offline, server
# paused, no opponents for this wave yet) — the caller then falls back to the
# PvE wave, so a bad connection never stalls or free-wins a wave.
func _get_opponent_snapshot(_own_snapshot: Dictionary) -> Dictionary:
	var snapshot : Dictionary = _pending_opponent_snapshot
	_pending_opponent_snapshot = {}
	return snapshot

# =========================================================================== #
#  VS mode — opponent prefetch (async, never blocks the wave)
# =========================================================================== #

# Sanitized opponent snapshot downloaded during prep, waiting for wave start.
var _pending_opponent_snapshot : Dictionary = {}

# Called at the start of every versus prep phase. The wave being prepared is
# _wave_number + 1 (_wave_number only increments in _start_wave).
func _begin_opponent_fetch() -> void:
	_pending_opponent_snapshot = {}
	# Emit SEARCHING first: a config error makes fetch_opponent emit request_failed
	# synchronously, and that ERROR state must land after this one, not before.
	versus_status_changed.emit(GameMode.VersusState.SEARCHING, "", 0, "")
	SnapshotService.fetch_opponent(_wave_number + 1, estimate_defense_power(), GameMode.player_id)

# Power rating of whatever defense is standing in no man's land right now.
# Used only to pick a similarly strong opponent, so a rough number is fine.
func estimate_defense_power() -> int:
	if units_layer == null:
		return 0
	var saved_units : Array = _player_units
	_player_units = _get_battlefield_player_units()
	var power : int = int(capture_defense_snapshot().get("power", 0))
	_player_units = saved_units
	return power

func _on_opponent_fetched(wave: int, snapshot: Dictionary) -> void:
	# Drop stale answers: only the wave we are currently preparing counts.
	if _phase != Phase.PREP or wave != _wave_number + 1:
		return
	var clean : Dictionary = sanitize_snapshot(snapshot)
	if is_snapshot_empty(clean):
		push_warning("Versus: no usable opponent snapshot for wave %d, will use PvE." % wave)
		versus_status_changed.emit(GameMode.VersusState.NO_OPPONENT, "", 0, "")
		return
	_pending_opponent_snapshot = clean
	versus_status_changed.emit(GameMode.VersusState.READY, str(clean["player_name"]), int(clean["power"]), "")
	print("Versus: opponent ready for wave %d: %s (power %d)" % [wave, clean["player_name"], clean["power"]])

func _on_snapshot_request_failed(kind: String, reason: String) -> void:
	push_warning("Versus: snapshot %s failed: %s" % [kind, reason])
	# Upload failures are shown by versus_status.gd itself. Only a fetch failure
	# during prep changes matchmaking state (late answers are ignored).
	if kind == "fetch" and _phase == Phase.PREP:
		versus_status_changed.emit(GameMode.VersusState.ERROR, "", 0, reason)

# =========================================================================== #
#  Debug — mirror own defense
# =========================================================================== #

# The PvE-vs-mirror choice is made when prep starts, but the flag can be
# toggled in settings during prep. Fix up whatever prep already did so the
# wave matches the flag at the moment the gate closes.
func _reconcile_debug_mirror_prep() -> void:
	if debug_mirror_defense:
		# Turned on mid-prep: drop PvE enemies that already spawned + queued.
		_spawn_queue.clear()
		for e : Variant in _enemies:
			if is_instance_valid(e):
				e.queue_free()
		_enemies.clear()
		enemy_count_changed.emit(0)
	elif not GameMode.is_versus() and _spawn_queue.is_empty() and _enemies.is_empty():
		# Turned off mid-prep: prep skipped the PvE composition, so build it now.
		_spawn_pve_fallback()

# Debug wave start. Captures the defense standing in nomans right now and
# spawns it as hostile enemies mirrored across the separator. Same rebuild path
# versus uses (level, items, building bonuses), but nothing is saved to disk or
# uploaded. Empty defense falls back to the PvE wave so it is never a free win.
func _start_debug_mirror_battle() -> void:
	var own_snapshot : Dictionary = capture_defense_snapshot()
	var spawned      : int        = 0
	if not is_snapshot_empty(own_snapshot):
		spawned = spawn_mirrored_defense(own_snapshot)
	if spawned == 0:
		push_warning("Debug mirror: no defense in nomans zone, using PvE wave %d." % _wave_number)
		_spawn_pve_fallback()
	else:
		print("Debug mirror: spawned %d mirrored units for wave %d" % [spawned, _wave_number])
	# Versus HUD may be sitting on SEARCHING/READY from prep. Clear it.
	if GameMode.is_versus():
		versus_status_changed.emit(GameMode.VersusState.NONE, "", 0, "")

func _begin_battle() -> void:
	_player_units = _get_battlefield_player_units()
	_enemies = _get_battlefield_enemies()
	_hired_units = _hired_units.filter(func(u): return is_instance_valid(u))
	_battle_hired_units = _get_battlefield_hired_units()

	# Snapshot each battle unit's position so we can teleport survivors home.
	_battle_start_positions.clear()
	for u in _player_units:
		if is_instance_valid(u):
			_battle_start_positions[u] = u.global_position
	for h in _battle_hired_units:
		if is_instance_valid(h):
			_battle_start_positions[h] = h.global_position

	var all_friendlies : Array = _player_units + _battle_hired_units
	for e in _enemies:
		if is_instance_valid(e) and e.has_method("start_battle"):
			e.start_battle(all_friendlies)

	for u in _player_units:
		if is_instance_valid(u) and u.has_method("start_battle"):
			u.start_battle(_enemies)
	for h in _battle_hired_units:
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
	# During a battle only committed hires count as targets/allies. Outside a
	# battle callers get every hire the player owns.
	if _phase == Phase.BATTLE:
		return _battle_hired_units
	return _hired_units

func register_hired_unit(unit: Node) -> void:
	_hired_units.append(unit)
	# A unit hired mid-wave spawns in town behind the raised bridge, so it sits
	# this battle out. Only join if it is already standing in the battlefield.
	# Defer start_battle so @onready vars are initialized first
	if _phase == Phase.BATTLE and not _enemies.is_empty() and _is_in_player_battlefield(unit.global_position):
		_battle_hired_units.append(unit)
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
	# Versus: opponent's mirrored defense IS the wave, so no PvE composition.
	var composition : Array = [] if (GameMode.is_versus() or debug_mirror_defense) else WAVE_COMPOSITIONS[_wave_number]
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
	if GameMode.is_versus():
		_begin_opponent_fetch()

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

func _get_battlefield_hired_units() -> Array:
	var result : Array = []
	for h in _hired_units:
		if is_instance_valid(h) and h.hp > 0 and _is_in_player_battlefield(h.global_position):
			result.append(h)
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
	_battle_hired_units = _battle_hired_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	var all_friendlies : Array = _player_units + _battle_hired_units
	for e in _enemies:
		e.update_target(all_friendlies)
	for u in _player_units:
		if u.has_method("update_battle_target"):
			u.update_battle_target(_enemies)
	for h in _battle_hired_units:
		if h.has_method("update_hired_target"):
			h.update_hired_target(_enemies)

func _check_battle_over() -> void:
	_enemies      = _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)
	_player_units = _player_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	_hired_units  = _hired_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	_battle_hired_units = _battle_hired_units.filter(func(u): return is_instance_valid(u) and u.hp > 0)
	if _enemies.is_empty():
		_end_wave(true)
	elif _player_units.is_empty() and _battle_hired_units.is_empty():
		_end_wave(false)

func _end_wave(player_won: bool) -> void:
	_phase = Phase.NONE
	if GameMode.is_versus():
		versus_status_changed.emit(GameMode.VersusState.NONE, "", 0, "")

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
	for h in _battle_hired_units:
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
	_battle_hired_units.clear()

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
	# Mirrored defenders are already parented (they need to be in the tree
	# before level/items/bonuses apply). Mid-battle summons are not.
	if enemy.get_parent() == null:
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
# Returns how many units were actually spawned. 0 means the snapshot was
# empty or fully invalid, caller should fall back (see _spawn_pve_fallback).
func spawn_mirrored_defense(raw_snapshot: Dictionary) -> int:
	var snapshot : Dictionary = sanitize_snapshot(raw_snapshot)
	var spawned  : int        = 0
	for entry : Dictionary in snapshot["units"]:
		var unit : CharacterBody2D = _build_mirrored_unit(entry)
		if unit != null:
			register_enemy(unit)
			spawned += 1
	for entry : Dictionary in snapshot["hired_units"]:
		var unit : CharacterBody2D = _build_mirrored_hired_unit(entry)
		if unit != null:
			register_enemy(unit)
			spawned += 1
			# register_enemy() flags every summon as "summoned" to stop mid-battle
			# reinforcements from dropping loot. A mirrored defender isn't a
			# throwaway summon though — it should drop chests like any real
			# enemy would, so clear the flag right back off.
			unit.set("summoned", false)
	return spawned

# Versus fallback when opponent snapshot is empty/invalid: fight this wave's
# normal PvE composition instead, so nobody gets a free win.
func _spawn_pve_fallback() -> void:
	var index : int = _wave_number - 1
	if index < 0 or index >= WAVE_COMPOSITIONS.size():
		return
	var composition : Array = WAVE_COMPOSITIONS[index]
	for entry : Dictionary in composition:
		var scene : PackedScene = _get_scene(str(entry["path"]))
		if scene == null:
			continue
		for _i : int in int(entry["count"]):
			_spawn_queue.append(scene)
	_spawn_remaining_prep_enemies()

# =========================================================================== #
#  VS mode — snapshot validation
# =========================================================================== #
# Snapshots will come from other players' machines, so nothing in one is
# trusted. sanitize_snapshot() rebuilds a clean copy from scratch: whitelisted
# unit types, clamped levels/positions/bonuses, valid item enums, capped
# counts. Bad entries are dropped, never "repaired". Also safe on {}.

func sanitize_snapshot(raw: Dictionary) -> Dictionary:
	if _as_int(raw.get("schema_version", 1), 1) > SNAPSHOT_SCHEMA_VERSION:
		push_warning("Snapshot: schema newer than this build, ignoring.")
		return sanitize_snapshot({})

	var units_out : Array = []
	for entry : Variant in _as_array(raw.get("units", [])):
		if units_out.size() >= MAX_SNAPSHOT_UNITS:
			break
		if not (entry is Dictionary):
			continue
		var clean_unit : Dictionary = _sanitize_unit_entry(entry)
		if not clean_unit.is_empty():
			units_out.append(clean_unit)

	var hired_out : Array = []
	for entry : Variant in _as_array(raw.get("hired_units", [])):
		if hired_out.size() >= MAX_SNAPSHOT_HIRED:
			break
		if not (entry is Dictionary):
			continue
		var clean_hire : Dictionary = _sanitize_hired_entry(entry)
		if not clean_hire.is_empty():
			hired_out.append(clean_hire)

	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"player_id":      _sanitize_player_id(raw.get("player_id", "")),
		"player_name":    _sanitize_player_name(raw.get("player_name", "")),
		"game_version":   str(raw.get("game_version", "")).substr(0, 16),
		"day":            clampi(_as_int(raw.get("day", 0), 0), 0, TOTAL_WAVES),
		"captured_at":    str(raw.get("captured_at", "")).substr(0, 32),
		"power":          _compute_power(units_out, hired_out),
		"units":          units_out,
		"hired_units":    hired_out,
	}

# True when there is nothing to fight. Step 5 upload must check this too.
func is_snapshot_empty(snapshot: Dictionary) -> bool:
	return _as_array(snapshot.get("units", [])).is_empty() \
		and _as_array(snapshot.get("hired_units", [])).is_empty()

func _sanitize_unit_entry(entry: Dictionary) -> Dictionary:
	var unit_type : String = str(entry.get("unit_type", ""))
	if not MIRRORABLE_UNIT_TYPES.has(unit_type):
		push_warning("Snapshot: dropped unit with disallowed type '%s'" % unit_type)
		return {}
	var pos : Array = _sanitize_position(entry.get("position", null))
	if pos.is_empty():
		return {}

	var items      : Array      = []
	var seen_types : Array[int] = []
	for item_entry : Variant in _as_array(entry.get("equipped_items", [])):
		if items.size() >= UnitBaseScript.MAX_ITEMS:
			break
		if not (item_entry is Dictionary):
			continue
		var item_type : int = _as_int(item_entry.get("item_type", -1), -1)
		var rarity    : int = _as_int(item_entry.get("rarity", -1), -1)
		if item_type < 0 or item_type >= ITEM_SCRIPT.ItemType.size():
			continue
		if rarity < 0 or rarity >= ITEM_SCRIPT.Rarity.size():
			continue
		if seen_types.has(item_type):
			continue
		seen_types.append(item_type)
		items.append({"item_type": item_type, "rarity": rarity})

	return {
		"unit_type":        unit_type,
		"level":            clampi(_as_int(entry.get("level", 1), 1), 1, UnitBaseScript.MAX_LEVEL),
		"position":         pos,
		"equipped_items":   items,
		"building_bonuses": _sanitize_bonuses(entry.get("building_bonuses", null)),
	}

func _sanitize_hired_entry(entry: Dictionary) -> Dictionary:
	var hire_id : String = str(entry.get("hire_id", ""))
	if _get_roster_entry(hire_id).is_empty():
		push_warning("Snapshot: dropped hire with unknown id '%s'" % hire_id)
		return {}
	var pos : Array = _sanitize_position(entry.get("position", null))
	if pos.is_empty():
		return {}
	return {"hire_id": hire_id, "position": pos}

func _sanitize_bonuses(raw: Variant) -> Dictionary:
	var out : Dictionary = {}
	if not (raw is Dictionary):
		return out
	var src : Dictionary = raw
	for key : String in BONUS_LIMITS:
		if not src.has(key):
			continue
		var limits : Array = BONUS_LIMITS[key]
		var value  : float = _as_finite_float(src[key], NAN)
		if is_nan(value):
			continue
		value = clampf(value, float(limits[0]), float(limits[1]))
		if INT_BONUS_KEYS.has(key):
			out[key] = roundi(value)
		else:
			out[key] = value
	return out

# Returns [x, y] clamped into the player-side battlefield, or [] if unusable.
func _sanitize_position(raw: Variant) -> Array:
	if not (raw is Array) or (raw as Array).size() < 2:
		return []
	var arr : Array = raw
	var x   : float = _as_finite_float(arr[0], NAN)
	var y   : float = _as_finite_float(arr[1], NAN)
	if is_nan(x) or is_nan(y):
		return []
	return [
		snappedf(clampf(x, BATTLEFIELD_MID, BATTLEFIELD_RIGHT - 1.0), 0.1),
		snappedf(clampf(y, SNAPSHOT_MIN_Y, SNAPSHOT_MAX_Y), 0.1),
	]

func _sanitize_player_id(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var pid : String = str(value)
	if pid.length() < 1 or pid.length() > MAX_PLAYER_ID_LENGTH:
		return ""
	var rx : RegEx = RegEx.new()
	rx.compile("^[A-Za-z0-9_-]+$")
	return pid if rx.search(pid) != null else ""

func _sanitize_player_name(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var cleaned : String = str(value).replace("\n", " ").replace("\r", " ").strip_edges()
	return cleaned.substr(0, GameMode.MAX_PLAYER_NAME_LENGTH)

func _compute_power(units: Array, hired: Array) -> int:
	var total : int = 0
	for u : Dictionary in units:
		total += POWER_UNIT_BASE + POWER_PER_LEVEL * (int(u["level"]) - 1)
		for item : Dictionary in u["equipped_items"]:
			var r : int = mini(int(item["rarity"]), POWER_PER_ITEM_RARITY.size() - 1)
			total += POWER_PER_ITEM_RARITY[r]
		var bonuses : Dictionary = u["building_bonuses"]
		total += int(bonuses.get("attack_damage", 0)) * POWER_PER_BONUS_DAMAGE
		total += int(float(bonuses.get("hp_bonus", 0)) * POWER_PER_BONUS_HP)
	for h : Dictionary in hired:
		var cost : Dictionary = _get_roster_entry(str(h["hire_id"])).get("cost", {})
		total += (int(cost.get("gold", 0)) + int(cost.get("meat", 0))) * POWER_HIRE_MULTIPLIER
	return total

func _get_roster_entry(hire_id: String) -> Dictionary:
	for roster_entry : Dictionary in HouseScript.HIRE_ROSTER:
		if str(roster_entry.get("id", "")) == hire_id:
			return roster_entry
	return {}

func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []

# JSON-safe number reads: null / strings / NaN / inf all fall back.
func _as_finite_float(value: Variant, fallback: float) -> float:
	var t : int = typeof(value)
	if t != TYPE_INT and t != TYPE_FLOAT:
		return fallback
	var f : float = float(value)
	if not is_finite(f):
		return fallback
	return f

func _as_int(value: Variant, fallback: int) -> int:
	return int(_as_finite_float(value, float(fallback)))

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
