extends Node
# house.gd
# Controller for house1 building.
# Allows player to hire enemy units to fight for them during a wave.

const HIRE_ROSTER : Array = [
	{
		"id":    "warrior",
		"label": "Warrior",
		"scene": "res://scenes/enemy_warrior.tscn",
		"icon":  "res://assets/Units/Red Units/Warrior/Warrior_Idle.png",
		"icon_frame": Rect2(0, 0, 192, 192),
		"cost":  {"gold": 3, "meat": 3},
		"max":   4,
	},
	{
		"id":    "skeleton",
		"label": "Skeleton",
		"scene": "res://scenes/enemy_skeleton.tscn",
		"icon":  "res://assets/Enemies/skeleton/skeleton_idle.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 2, "meat": 1},
		"max":   6,
	},
	{
		"id":    "slime",
		"label": "Slime",
		"scene": "res://scenes/enemy_slime.tscn",
		"icon":  "res://assets/Enemies/slime/S_Walk.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 2, "meat": 1},
		"max":   4,
	},
	{
		"id":    "boar",
		"label": "Boar",
		"scene": "res://scenes/enemy_boar.tscn",
		"icon":  "res://assets/Enemies/boar/Boar_Idle.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 4, "meat": 4},
		"max":   3,
	},
	{
		"id":    "badger",
		"label": "Badger",
		"scene": "res://scenes/enemy_badger.tscn",
		"icon":  "res://assets/Enemies/badger/badger_idle.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 4, "meat": 3},
		"max":   3,
	},
	{
		"id":    "witch_doctor",
		"label": "Witch Doctor",
		"scene": "res://scenes/enemy_witch_doctor.tscn",
		"icon":  "res://assets/Enemies/witch_doc/Idle1.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 6, "meat": 5},
		"max":   2,
	},
	{
		"id":    "cat_boss",
		"label": "Cat Boss",
		"scene": "res://scenes/enemy_cat_boss.tscn",
		"icon":  "res://assets/Enemies/cat_boss/cat_idle.png",
		"icon_frame": Rect2(0, 0, 0, 0),
		"cost":  {"gold": 15, "meat": 10},
		"max":   1,
	},
]

var units_layer  : Node2D = null
var _hired_units : Array  = []

# =========================================================================== #
#  Public API
# =========================================================================== #

func get_hire_roster() -> Array:
	return HIRE_ROSTER

func get_hired_count(unit_id: String) -> int:
	_hired_units = _hired_units.filter(func(u): return is_instance_valid(u))
	var count : int = 0
	for u in _hired_units:
		if u.get_meta("hire_id", "") == unit_id:
			count += 1
	return count

func can_hire(entry: Dictionary) -> bool:
	if get_hired_count(entry["id"]) >= int(entry["max"]):
		return false
	var cost : Dictionary = entry["cost"]
	return ResourceManager.gold >= int(cost.get("gold", 0)) * 10 \
		and ResourceManager.meat >= int(cost.get("meat", 0))

func try_hire(entry: Dictionary) -> bool:
	if not can_hire(entry):
		return false
	var cost : Dictionary = entry["cost"]
	var gold_cost : int = int(cost.get("gold", 0)) * 10
	var meat_cost : int = int(cost.get("meat", 0))
	if not ResourceManager.spend({"gold": gold_cost, "meat": meat_cost}):
		return false
	_spawn_hired_unit(entry)
	return true

# =========================================================================== #
#  Spawning
# =========================================================================== #

func _spawn_hired_unit(entry: Dictionary) -> void:
	var scene    : PackedScene      = load(entry["scene"])
	var unit     : CharacterBody2D  = scene.instantiate()
	unit.set_meta("hire_id", entry["id"])
	# Flip allegiance — keeps all subclass behaviour intact
	unit.call("set_hired")
	# Spawn below the house tile
	var parent    : Node     = get_parent()
	var rng       := RandomNumberGenerator.new()
	rng.randomize()
	var base_pos  : Vector2  = parent.position
	unit.position = base_pos + Vector2(
		rng.randf_range(-40.0, 40.0),
		80.0 + rng.randf_range(0.0, 32.0)
	)
	if units_layer != null:
		units_layer.add_child(unit)
	else:
		get_tree().current_scene.add_child(unit)
	_hired_units.append(unit)
	# Register with wave_manager
	var wm : Node = get_tree().current_scene.get_node_or_null("WaveManager")
	if wm != null and wm.has_method("register_hired_unit"):
		wm.register_hired_unit(unit)

func _process(_delta: float) -> void:
	_hired_units = _hired_units.filter(func(u): return is_instance_valid(u))
