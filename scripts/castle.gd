extends Node

# Castle — attached as a child of a PlacedBuilding when building_id == "castle".
# Spawns up to MAX_PAWNS pawns, one every SPAWN_INTERVAL seconds.
# When a pawn dies it signals back here so the slot opens up for a new spawn.

const MAX_PAWNS      = 3
const SPAWN_INTERVAL = 5.0   # seconds between spawn attempts
const TILE_SIZE      = 64

const PAWN_SCENE = preload("res://scenes/pawn.tscn")

# Layer that pawns are added to — injected by PlacedBuilding.setup()
var units_layer : Node2D = null

var _live_pawns  : int   = 0
var _spawn_timer : float = 0.0

func _process(delta: float) -> void:
	if _live_pawns >= MAX_PAWNS:
		_spawn_timer = 0.0   # reset so the next pawn comes quickly after one dies
		return

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_pawn()

func _spawn_pawn() -> void:
	if units_layer == null:
		push_error("Castle: units_layer not set — cannot spawn pawn")
		return

	var pawn      := PAWN_SCENE.instantiate() as CharacterBody2D
	var parent    := get_parent()   # the PlacedBuilding (StaticBody2D)
	# Spawn at the centre of the tile directly below the building.
	var tile      := parent.get_meta("tile") as Vector2i
	var below     := Vector2i(tile.x, tile.y + 1)
	pawn.position  = Vector2(below.x * TILE_SIZE + TILE_SIZE * 0.5,
						   below.y * TILE_SIZE + TILE_SIZE * 0.5)
	pawn.z_index   = 3

	units_layer.add_child(pawn)
	_live_pawns += 1

	pawn.died.connect(_on_pawn_died)
	print("Castle spawned pawn  (live: %d/%d)" % [_live_pawns, MAX_PAWNS])

func _on_pawn_died() -> void:
	_live_pawns = max(0, _live_pawns - 1)
	print("Pawn died — live pawns now: %d/%d" % [_live_pawns, MAX_PAWNS])

# ── Read-only stats (for future upgrade UI) ───────────────────────────────────
func get_live_pawns()  -> int:   return _live_pawns
func get_max_pawns()   -> int:   return MAX_PAWNS
func get_spawn_timer() -> float: return _spawn_timer
