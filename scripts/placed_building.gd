extends StaticBody2D

# PlacedBuilding — a building that has been placed in the world.
# Owns its own visual (Sprite2D) and collision (CollisionShape2D).
# Created at runtime by main.gd when BuildingPlacer emits building_placed.

const TILE_SIZE = 64

# Building texture map (mirrors building_placer.gd)
const BUILDING_TEXTURES := {
	"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
	"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
	"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
	"house1":    "res://assets/Buildings/Black Buildings/House1.png",
	"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
	"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
}

# Approximate footprint half-extents used for the collision box.
# Buildings are centred on a tile; the box covers one tile horizontally
# and the bottom portion of the sprite vertically so units route around
# the base rather than the full tall sprite.
const COLLISION_HALF_W = 28.0   # px — just inside one tile (32px half)
const COLLISION_HALF_H = 28.0   # px

var building_id : String = ""

func setup(id: String, tile: Vector2i) -> void:
	building_id = id
	name        = "Building_%s_%d_%d" % [id, tile.x, tile.y]
	position    = _tile_center(tile)
	z_index     = 3   # same layer as units so it sorts correctly

	# ── Sprite ────────────────────────────────────────────────────────────────
	var sprite        := Sprite2D.new()
	sprite.texture     = load(BUILDING_TEXTURES[id]) as Texture2D
	add_child(sprite)

	# ── Collision ─────────────────────────────────────────────────────────────
	var shape_node    := CollisionShape2D.new()
	var rect          := RectangleShape2D.new()
	rect.size          = Vector2(COLLISION_HALF_W * 2.0, COLLISION_HALF_H * 2.0)
	shape_node.shape   = rect
	# Offset the collision box to sit at ground level (bottom of sprite area)
	shape_node.position = Vector2(0.0, 0.0)
	add_child(shape_node)

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)
