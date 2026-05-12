extends Node

# tower.gd -- attached as a child of a PlacedBuilding when building_id == "tower".
# Towers spawn lancers — heavy spear troops with long reach.
# Lancers spawn from the tower and patrol nearby.

const MAX_LANCERS    = 3
const SPAWN_INTERVAL = 10.0
const MEAT_COST      = 4
const TILE_SIZE      = 64

const LANCER_SCENE = preload("res://scenes/lancer.tscn")

var units_layer : Node2D = null

var _live_lancers : int   = 0
var _spawn_timer  : float = 0.0

func _process(delta: float) -> void:
	var parent := get_parent()
	var max_units : int = parent.get_effective_unit_cap(MAX_LANCERS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_LANCERS
	var spawn_interval : int = parent.get_effective_spawn_interval(SPAWN_INTERVAL) if parent != null and parent.has_method("get_effective_spawn_interval") else SPAWN_INTERVAL
	if parent != null and parent.has_method("is_upgrade_blocking_production") and parent.is_upgrade_blocking_production():
		return
	if _live_lancers >= max_units:
		_spawn_timer = 0.0
		return
	if not ResourceManager.has_meat(MEAT_COST):
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_lancer()

func _spawn_lancer() -> void:
	if units_layer == null:
		push_error("Tower: units_layer not set")
		return
	if not ResourceManager.spend_meat(MEAT_COST):
		return

	var lancer := LANCER_SCENE.instantiate() as CharacterBody2D
	var parent := get_parent()
	var tile   := parent.get_meta("tile") as Vector2i
	var below  := Vector2i(tile.x, tile.y + 1)
	lancer.position = Vector2(
		below.x * TILE_SIZE + TILE_SIZE * 0.5,
		below.y * TILE_SIZE + TILE_SIZE * 1
	)
	lancer.z_index = 3

	lancer.home_position = parent.position
	lancer.home_node     = parent
	if parent != null and parent.has_method("apply_unit_bonuses"):
		parent.apply_unit_bonuses(lancer)

	units_layer.add_child(lancer)
	_live_lancers += 1

	lancer.died.connect(_on_lancer_died)

func _on_lancer_died() -> void:
	_live_lancers = max(0, _live_lancers - 1)

func get_live_lancers()  -> int:   return _live_lancers
func get_max_lancers()   -> int:
	var parent := get_parent()
	return parent.get_effective_unit_cap(MAX_LANCERS) if parent != null and parent.has_method("get_effective_unit_cap") else MAX_LANCERS
func get_spawn_timer()   -> float: return _spawn_timer
