extends Node

# Castle -- attached as a child of a PlacedBuilding when building_id == "castle".
# Spawns up to MAX_PAWNS pawns, one every SPAWN_INTERVAL seconds.
# Injects home_position and resource_delivered signal wiring into each pawn.

signal pawn_delivered_resource(resource_type: String, amount: int)

const MAX_PAWNS      = 3
const SPAWN_INTERVAL = 5.0
const TILE_SIZE      = 64

const PAWN_SCENE = preload("res://scenes/pawn.tscn")

# Injected by PlacedBuilding.setup()
var units_layer : Node2D = null

var _live_pawns  : int   = 0
var _spawn_timer : float = 0.0

func _process(delta: float) -> void:
	if _live_pawns >= MAX_PAWNS:
		_spawn_timer = 0.0
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_pawn()

func _spawn_pawn() -> void:
	if units_layer == null:
		push_error("Castle: units_layer not set")
		return

	var pawn     := PAWN_SCENE.instantiate() as CharacterBody2D
	var parent   := get_parent()
	var tile     := parent.get_meta("tile") as Vector2i
	var below    := Vector2i(tile.x, tile.y + 1)
	pawn.position = Vector2(below.x * TILE_SIZE + TILE_SIZE * 0.5,
							below.y * TILE_SIZE + TILE_SIZE * 0.5)
	pawn.z_index  = 3

	# Tell the pawn where home is so it can return after gathering
	pawn.home_position = parent.position
	pawn.home_node     = parent   # PlacedBuilding StaticBody2D — arrival detected by collision

	units_layer.add_child(pawn)
	_live_pawns += 1

	pawn.died.connect(_on_pawn_died)
	pawn.resource_delivered.connect(_on_pawn_delivered)

func _on_pawn_died() -> void:
	_live_pawns = max(0, _live_pawns - 1)

func _on_pawn_delivered(resource_type: String, amount: int) -> void:
	emit_signal("pawn_delivered_resource", resource_type, amount)

# -- Read-only stats ----------------------------------------------------------
func get_live_pawns()  -> int:   return _live_pawns
func get_max_pawns()   -> int:   return MAX_PAWNS
func get_spawn_timer() -> float: return _spawn_timer
