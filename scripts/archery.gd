extends Node

# Archery -- attached as a child of a PlacedBuilding when building_id == "archery".
# Spawns up to MAX_ARCHERS archers, one every SPAWN_INTERVAL seconds.

const MAX_ARCHERS    = 4
const SPAWN_INTERVAL = 8.0
const MEAT_COST      = 3
const TILE_SIZE      = 64

const ARCHER_SCENE = preload("res://scenes/archer.tscn")

var units_layer: Node2D = null

var _live_archers: int = 0
var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	var parent := get_parent()
	var max_units := parent.get_effective_unit_cap(MAX_ARCHERS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_ARCHERS
	var spawn_interval := parent.get_effective_spawn_interval(SPAWN_INTERVAL) if parent != null and parent.has_method("get_effective_spawn_interval") else SPAWN_INTERVAL
	if parent != null and parent.has_method("is_upgrade_blocking_production") and parent.is_upgrade_blocking_production():
		return
	if _live_archers >= max_units:
		_spawn_timer = 0.0
		return
	if not ResourceManager.has_meat(MEAT_COST):
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_archer()

func _spawn_archer() -> void:
	if units_layer == null:
		push_error("Archery: units_layer not set")
		return
	if not ResourceManager.spend_meat(MEAT_COST):
		return  # not enough meat — try again next interval

	var archer := ARCHER_SCENE.instantiate() as CharacterBody2D
	var parent := get_parent()
	var tile := parent.get_meta("tile") as Vector2i
	var below := Vector2i(tile.x, tile.y + 1)
	archer.position = Vector2(
		below.x * TILE_SIZE + TILE_SIZE * 0.5,
		below.y * TILE_SIZE + TILE_SIZE * 1
	)
	archer.z_index = 3
	archer.home_position = parent.position
	archer.home_node = parent
	if parent != null and parent.has_method("apply_unit_bonuses"):
		parent.apply_unit_bonuses(archer)

	units_layer.add_child(archer)
	_live_archers += 1

	archer.died.connect(_on_archer_died)

func _on_archer_died() -> void:
	_live_archers = max(0, _live_archers - 1)

func get_live_archers() -> int:
	return _live_archers

func get_max_archers() -> int:
	var parent := get_parent()
	return parent.get_effective_unit_cap(MAX_ARCHERS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_ARCHERS

func get_spawn_timer() -> float:
	return _spawn_timer
