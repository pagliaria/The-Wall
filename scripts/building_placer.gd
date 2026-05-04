extends Node2D

# BuildingPlacer — handles ghost preview and tile validation during placement mode.
#
# Usage:
#   call start_placement(building_id) to enter placement mode
#   right-click or Escape cancels; left-click on a valid tile confirms
#
# Emits:
#   building_placed(building_id: String, tile: Vector2i)
#   placement_cancelled()

signal building_placed(building_id: String, tile: Vector2i)
signal placement_cancelled

# ── World constants (must match terrain.gd / main.gd) ────────────────────────
const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3          # rows 0–2 are water — cannot build here
const COL_TOWN_START = 20         # columns 0–19 are enemy wilds — cannot build here

# ── Ghost colours ─────────────────────────────────────────────────────────────
const COLOR_VALID   = Color(0.4, 1.0, 0.4, 0.55)   # green tint — ok to place
const COLOR_INVALID = Color(1.0, 0.3, 0.3, 0.55)   # red tint  — blocked

# Building texture map (mirrors build_menu.gd)
const BUILDING_TEXTURES := {
	"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
	"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
	"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
	"house1":    "res://assets/Buildings/Black Buildings/House1.png",
	"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
	"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
}

# ── State ─────────────────────────────────────────────────────────────────────
var _active          := false
var _building_id     := ""
var _current_tile    := Vector2i(-1, -1)
var _placement_valid := false

# ── Node refs set up in main.tscn ─────────────────────────────────────────────
@onready var ghost_sprite : Sprite2D    = $GhostSprite
@onready var shape_cast   : ShapeCast2D = $ShapeCast2D

# Injected by main.gd after scene ready so the placer can do ground-tile checks
var ground_layer : TileMapLayer = null

func _ready() -> void:
	# Give the ShapeCast2D a rectangle roughly the size of one building footprint.
	# This catches overlaps with trees, gold stones, other buildings, and the wall.
	var rect        := RectangleShape2D.new()
	rect.size        = Vector2(48.0, 48.0)   # slightly inset from a full 64px tile
	shape_cast.shape = rect
	shape_cast.enabled = true

# ── Public API ────────────────────────────────────────────────────────────────

func start_placement(building_id: String) -> void:
	_building_id = building_id
	ghost_sprite.texture  = load(BUILDING_TEXTURES[building_id]) as Texture2D
	ghost_sprite.modulate = COLOR_INVALID
	ghost_sprite.visible  = true
	_active = true

func cancel_placement() -> void:
	_active              = false
	ghost_sprite.visible = false
	_building_id         = ""
	emit_signal("placement_cancelled")

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _active:
		return

	# Mouse screen → world position → tile
	var world_pos : Vector2  = get_viewport().get_canvas_transform().affine_inverse() * \
							   get_viewport().get_mouse_position()
	var tile      : Vector2i = _world_to_tile(world_pos)
	var snapped   : Vector2  = _tile_center(tile)

	ghost_sprite.position = snapped
	_current_tile         = tile

	# Zone check (grid only — fast)
	_placement_valid = _tile_in_build_zone(tile)

	# Physics overlap check (only when zone is valid)
	if _placement_valid:
		shape_cast.position = snapped
		shape_cast.force_shapecast_update()
		if shape_cast.is_colliding():
			_placement_valid = false

	ghost_sprite.modulate = COLOR_VALID if _placement_valid else COLOR_INVALID

# ── Input ─────────────────────────────────────────────────────────────────────

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

# ── Private ───────────────────────────────────────────────────────────────────

func _confirm_placement() -> void:
	_active              = false
	ghost_sprite.visible = false
	var tile             := _current_tile
	var id               := _building_id
	_building_id         = ""
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
