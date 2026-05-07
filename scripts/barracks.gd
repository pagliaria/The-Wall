extends Node

# Barracks -- attached as a child of a PlacedBuilding when building_id == "barracks".
# Spawns up to MAX_WARRIORS warriors, one every SPAWN_INTERVAL seconds.
# Warriors patrol near the barracks and respond to player move orders.

const MAX_WARRIORS    = 4
const SPAWN_INTERVAL  = 8.0
const MEAT_COST       = 3
const TILE_SIZE       = 64

const WARRIOR_SCENE = preload("res://scenes/warrior.tscn")

# Injected by PlacedBuilding.setup()
var units_layer : Node2D = null

var _live_warriors : int   = 0
var _spawn_timer   : float = 0.0

func _process(delta: float) -> void:
	if _live_warriors >= MAX_WARRIORS:
		_spawn_timer = 0.0
		return
	if not ResourceManager.has_meat(MEAT_COST):
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_warrior()

func _spawn_warrior() -> void:
	if units_layer == null:
		push_error("Barracks: units_layer not set")
		return
	if not ResourceManager.spend_meat(MEAT_COST):
		return  # not enough meat — try again next interval

	var warrior  := WARRIOR_SCENE.instantiate() as CharacterBody2D
	var parent   := get_parent()
	var tile     := parent.get_meta("tile") as Vector2i
	var below    := Vector2i(tile.x, tile.y + 1)
	warrior.position = Vector2(
		below.x * TILE_SIZE + TILE_SIZE * 0.5,
		below.y * TILE_SIZE + TILE_SIZE * 1
	)
	warrior.z_index = 3

	warrior.home_position = parent.position
	warrior.home_node     = parent

	units_layer.add_child(warrior)
	_live_warriors += 1

	warrior.died.connect(_on_warrior_died)

func _on_warrior_died() -> void:
	_live_warriors = max(0, _live_warriors - 1)

# -- Read-only stats ----------------------------------------------------------
func get_live_warriors()  -> int:   return _live_warriors
func get_max_warriors()   -> int:   return MAX_WARRIORS
func get_spawn_timer()    -> float: return _spawn_timer

# Duck-typed compatibility so unit_selection can find this controller
# (it expects get_live_pawns — we don't need that, but placed_building's
# get_controller() duck-types on get_live_pawns, so we skip that hook;
# barracks warriors are found directly via UnitsLayer like pawn warriors)
