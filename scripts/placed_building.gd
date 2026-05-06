extends StaticBody2D

# PlacedBuilding — a building that has been placed in the world.
# Generic container: creates its own sprite, collision, and click area.
# For building-specific behaviour (e.g. Castle spawning pawns), a child
# controller node is added based on building_id.

signal building_clicked(building: Node)

const TILE_SIZE = 64

const BUILDING_TEXTURES := {
	"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
	"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
	"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
	"house1":    "res://assets/Buildings/Black Buildings/House1.png",
	"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
	"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
}

# The building type — readable by UI, other systems, and child controllers.
var building_id : String = ""

# Injected by main.gd so child controllers (e.g. Castle) know where to add units.
var units_layer : Node2D = null

func setup(id: String, tile: Vector2i, p_units_layer: Node2D) -> void:
	building_id = id
	units_layer = p_units_layer
	name        = "Building_%s_%d_%d" % [id, tile.x, tile.y]
	position    = _tile_center(tile)
	z_index     = 3

	# ── Sprite ────────────────────────────────────────────────────────────────
	var sprite       := Sprite2D.new()
	var tex          := load(BUILDING_TEXTURES[id]) as Texture2D
	sprite.texture    = tex
	add_child(sprite)

	# ── Collision sized to the actual texture ─────────────────────────────────
	# Use the real pixel dimensions of the sprite so large buildings like the
	# castle get a proper-sized box rather than a fixed tile-sized one.
	var tex_size   := tex.get_size() if tex else Vector2(TILE_SIZE, TILE_SIZE)

	var shape_node         := CollisionShape2D.new()
	var rect               := RectangleShape2D.new()
	rect.size               = tex_size - Vector2(64, 128)
	shape_node.shape        = rect
	add_child(shape_node)

	# Expose the tile for child controllers (e.g. spawn-point calculation).
	set_meta("tile", tile)

	# ── Click area sized to match the collision ────────────────────────────────
	var area              := Area2D.new()
	area.name              = "ClickArea"
	var area_shape         := CollisionShape2D.new()
	var area_rect          := RectangleShape2D.new()
	area_rect.size          = tex_size
	area_shape.shape        = area_rect
	area.add_child(area_shape)
	area.input_pickable    = true
	area.input_event.connect(_on_area_input_event)
	add_child(area)

	# ── Building-specific controller ───────────────────────────────────────────
	_attach_controller(id)

func _attach_controller(id: String) -> void:
	match id:
		"castle":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/castle.gd"))
			ctrl.name          = "CastleController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
		"barracks":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/barracks.gd"))
			ctrl.name          = "BarracksController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
		"archery":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/archery.gd"))
			ctrl.name          = "ArcheryController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
		"monastery":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/monastery.gd"))
			ctrl.name          = "MonasteryController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
		# Future: "tower", "house1"

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("building_clicked", self)

func get_nav_footprint() -> Rect2:
	# Returns the world-space rect used to carve the nav mesh for this building.
	# Matches the collision shape size exactly.
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return Rect2(position, Vector2.ZERO)
	var half := (col.shape as RectangleShape2D).size * 0.5
	return Rect2(position - half, (col.shape as RectangleShape2D).size)

func get_controller() -> Node:
	# Returns the building-specific controller child, if any.
	for child in get_children():
		if child.has_method("get_live_pawns"):   # duck-typed for castle
			return child
	return null

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)
