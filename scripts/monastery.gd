extends Node

# Monastery -- attached as a child of a PlacedBuilding when building_id == "monastery".
# Spawns up to MAX_MONKS monks, one every SPAWN_INTERVAL seconds.

const MAX_MONKS      = 2
const SPAWN_INTERVAL = 10.0
const MEAT_COST      = 2
const TILE_SIZE      = 64

const MONK_SCENE = preload("res://scenes/monk.tscn")

var units_layer: Node2D = null

var _live_monks: int = 0
var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	var parent := get_parent()
	var max_units := parent.get_effective_unit_cap(MAX_MONKS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_MONKS
	var spawn_interval := parent.get_effective_spawn_interval(SPAWN_INTERVAL) if parent != null and parent.has_method("get_effective_spawn_interval") else SPAWN_INTERVAL
	if parent != null and parent.has_method("is_upgrade_blocking_production") and parent.is_upgrade_blocking_production():
		return
	if _live_monks >= max_units:
		_spawn_timer = 0.0
		return
	if not ResourceManager.has_meat(MEAT_COST):
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_monk()

func _spawn_monk() -> void:
	if units_layer == null:
		push_error("Monastery: units_layer not set")
		return
	if not ResourceManager.spend_meat(MEAT_COST):
		return  # not enough meat — try again next interval

	var monk := MONK_SCENE.instantiate() as CharacterBody2D
	var parent := get_parent()
	var tile := parent.get_meta("tile") as Vector2i
	var below := Vector2i(tile.x, tile.y + 1)
	monk.position = Vector2(
		below.x * TILE_SIZE + TILE_SIZE * 0.5,
		below.y * TILE_SIZE + TILE_SIZE * 1.5
	)
	monk.z_index = 3
	monk.home_position = parent.position
	monk.home_node = parent
	if parent != null and parent.has_method("apply_unit_bonuses"):
		parent.apply_unit_bonuses(monk)

	units_layer.add_child(monk)
	_live_monks += 1

	monk.died.connect(_on_monk_died)

func _on_monk_died() -> void:
	_live_monks = max(0, _live_monks - 1)

func get_live_monks() -> int:
	return _live_monks

func get_max_monks() -> int:
	var parent := get_parent()
	return parent.get_effective_unit_cap(MAX_MONKS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_MONKS

func get_spawn_timer() -> float:
	return _spawn_timer
