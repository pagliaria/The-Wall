extends Node2D

signal building_placed(building_id: String, tile: Vector2i)
signal placement_cancelled

const TILE_SIZE := 64
const MAP_COLS := 48
const MAP_ROWS := 27
const WATER_ROWS := 3
const COL_TOWN_START := 20

const COLOR_VALID := Color(0.4, 1.0, 0.4, 0.55)
const COLOR_INVALID := Color(1.0, 0.3, 0.3, 0.55)

const BUILDING_TEXTURES := {
	"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
	"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
	"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
	"house1":    "res://assets/Buildings/Black Buildings/House1.png",
	"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
	"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
}
const FOOTPRINT_PADDING := Vector2(64, 128)

var _active := false
var _building_id := ""
var _current_tile := Vector2i(-1, -1)
var _placement_valid := false

@onready var ghost_sprite: Sprite2D = $GhostSprite
@onready var shape_cast: ShapeCast2D = $ShapeCast2D

var ground_layer: TileMapLayer = null

func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 48.0)
	shape_cast.shape = rect
	shape_cast.collide_with_areas = true
	shape_cast.collide_with_bodies = true
	shape_cast.enabled = false

func start_placement(building_id: String) -> void:
	_building_id = building_id
	var texture := load(BUILDING_TEXTURES[building_id]) as Texture2D
	ghost_sprite.texture = texture
	_update_shape_cast_for_texture(texture)
	ghost_sprite.modulate = COLOR_INVALID
	ghost_sprite.visible = true
	shape_cast.enabled = true
	_active = true

func cancel_placement() -> void:
	_active = false
	ghost_sprite.visible = false
	shape_cast.enabled = false
	_building_id = ""
	emit_signal("placement_cancelled")

func is_placing() -> bool:
	return _active

func _process(_delta: float) -> void:
	if not _active:
		return

	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	var tile := _world_to_tile(world_pos)
	var snapped := _tile_center(tile)

	ghost_sprite.position = snapped
	_current_tile = tile
	_placement_valid = _tile_in_build_zone(tile)

	if _placement_valid:
		shape_cast.position = snapped
		shape_cast.force_shapecast_update()
		if shape_cast.is_colliding():
			_placement_valid = false

	ghost_sprite.modulate = COLOR_VALID if _placement_valid else COLOR_INVALID

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _placement_valid:
					_confirm_placement()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				cancel_placement()
				get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _confirm_placement() -> void:
	_active = false
	ghost_sprite.visible = false
	shape_cast.enabled = false
	var tile := _current_tile
	var id := _building_id
	_building_id = ""
	emit_signal("building_placed", id, tile)

func _tile_in_build_zone(tile: Vector2i) -> bool:
	if tile.x < COL_TOWN_START or tile.x >= MAP_COLS:
		return false
	if tile.y < WATER_ROWS or tile.y >= MAP_ROWS:
		return false
	if ground_layer != null and ground_layer.get_cell_source_id(tile) == -1:
		return false
	return true

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / TILE_SIZE),
		int(world_pos.y / TILE_SIZE)
	)

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)

func _update_shape_cast_for_texture(texture: Texture2D) -> void:
	var rect := shape_cast.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_cast.shape = rect

	var tex_size := texture.get_size() if texture != null else Vector2(TILE_SIZE, TILE_SIZE)
	rect.size = Vector2(
		maxf(16.0, tex_size.x - FOOTPRINT_PADDING.x),
		maxf(16.0, tex_size.y - FOOTPRINT_PADDING.y)
	)
