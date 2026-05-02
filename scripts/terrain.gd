extends Node2D

# Terrain manager for "The Wall"
# Builds TileSet entirely in script with proper Godot 4 terrain (blob/Wang) connections.
# Calls set_cells_terrain_connect() so Godot auto-picks edge/corner tiles.
#
# Tileset sheet layout (each color PNG, 64px tiles):
#
#  LEFT GROUP – outer corners & edges        RIGHT GROUP – inner corners
#  ┌──────┬──────┬──────┬──────┐  gap  ┌──────┬──────┬──────┬──────┐
#  │(0,0) │(1,0) │(2,0) │(3,0) │       │(5,0) │(6,0) │(7,0) │(8,0) │  row 0
#  │TL-out│T-edge│TR-out│ sngl │       │TL-in │TR-in │ fill │ sngl │
#  ├──────┼──────┼──────┼──────┤       ├──────┼──────┼──────┼──────┤
#  │(0,1) │(1,1) │(2,1) │(3,1) │       │(5,1) │(6,1) │(7,1) │(8,1) │  row 1
#  │L-edge│ FILL │R-edge│ sngl │       │BL-in │BR-in │ fill │ sngl │
#  ├──────┼──────┼──────┼──────┤       ├──────┼──────┼──────┼──────┤
#  │(0,2) │(1,2) │(2,2) │(3,2) │       │(5,2) │(6,2) │(7,2) │(8,2) │  row 2
#  │BL-out│B-edge│BR-out│ sngl │       │      │      │      │      │
#  └──────┴──────┴──────┴──────┘       └──────┴──────┴──────┴──────┘
#   rows 3-4: cliff/stone base tiles (decorative, not terrain-connected)

# ── Map dimensions ────────────────────────────────────────────────────────────
const TILE_SIZE  = 64
const MAP_COLS   = 48
const MAP_ROWS   = 27
const WATER_ROWS = 3

# ── Zone column boundaries ────────────────────────────────────────────────────
const COL_WILDS_END  = 20
const COL_NOMANS_END = 20

# ── TileSet source IDs ────────────────────────────────────────────────────────
const SRC_GRASS      = 0   # Tilemap_color1.png
const SRC_DIRT       = 1   # Tilemap_color3.png
const SRC_DARK_GRASS = 2   # Tilemap_color2.png
const SRC_STONE      = 3   # Tilemap_color4.png
const SRC_WATER      = 4   # Water Background color.png

# ── Terrain IDs (within terrain set 0) ───────────────────────────────────────
const TERRAIN_GRASS      = 0
const TERRAIN_DIRT       = 1
const TERRAIN_DARK_GRASS = 2
const TERRAIN_STONE      = 3

# ── Decoration paths ──────────────────────────────────────────────────────────
const BUSH_PATHS := [
	"res://assets/Terrain/Decorations/Bushes/Bushe1.png",
	"res://assets/Terrain/Decorations/Bushes/Bushe2.png",
	"res://assets/Terrain/Decorations/Bushes/Bushe3.png",
	"res://assets/Terrain/Decorations/Bushes/Bushe4.png",
]
const ROCK_PATHS := [
	"res://assets/Terrain/Decorations/Rocks/Rock1.png",
	"res://assets/Terrain/Decorations/Rocks/Rock2.png",
	"res://assets/Terrain/Decorations/Rocks/Rock3.png",
	"res://assets/Terrain/Decorations/Rocks/Rock4.png",
]
const WATER_ROCK_PATHS := [
	"res://assets/Terrain/Decorations/Rocks in the Water/Water Rocks_01.png",
	"res://assets/Terrain/Decorations/Rocks in the Water/Water Rocks_02.png",
	"res://assets/Terrain/Decorations/Rocks in the Water/Water Rocks_03.png",
	"res://assets/Terrain/Decorations/Rocks in the Water/Water Rocks_04.png",
]
const BUSH_FRAMES       = 8
const WATER_ROCK_FRAMES = 16

# ── Wall ─────────────────────────────────────────────────────────────────────
# wall 1.png — 192×224 px = 6 cols × 7 rows of 32×32 px tiles.
# Three 2-tile-wide styles: gold (0-1), plank (2-3), stone (4-5).
# We use the stone style (cols 4-5) for the wall.
# Row layout:
#   rows 0-1 → top cap     rows 2-5 → body     row 6 → bottom cap
const WALL_TEXTURE = "res://assets/Buildings/Wall/wall 1.png"
const WALL_TILE_PX = 32   # each tile is 32×32 px
const WALL_COL     = COL_WILDS_END

@onready var ground_layer : TileMapLayer = $GroundLayer
@onready var water_layer  : TileMapLayer = $WaterLayer
@onready var decor_layer  : Node2D       = $DecorationLayer
@onready var wall_layer   : Node2D       = $WallLayer

var rng := RandomNumberGenerator.new()

# ── Boot ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	rng.seed = 45
	var ts := _build_tileset()
	ground_layer.tile_set = ts
	water_layer.tile_set  = ts
	_fill_water()
	_fill_ground(ts)
	_scatter_decorations()
	_build_wall()

# ═════════════════════════════════════════════════════════════════════════════
# TILESET CONSTRUCTION
# ═════════════════════════════════════════════════════════════════════════════

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# One terrain set using blob (corners + sides) mode
	ts.add_terrain_set(TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)  # terrain_set 0

	# Four terrains — add_terrain(terrain_set, position) then set color/name separately
	ts.add_terrain(0, -1)
	ts.set_terrain_name(0, TERRAIN_GRASS, "Grass")
	ts.set_terrain_color(0, TERRAIN_GRASS, Color(0.3, 0.7, 0.2))

	ts.add_terrain(0, -1)
	ts.set_terrain_name(0, TERRAIN_DIRT, "Dirt")
	ts.set_terrain_color(0, TERRAIN_DIRT, Color(0.6, 0.45, 0.2))

	ts.add_terrain(0, -1)
	ts.set_terrain_name(0, TERRAIN_DARK_GRASS, "DarkGrass")
	ts.set_terrain_color(0, TERRAIN_DARK_GRASS, Color(0.15, 0.4, 0.1))

	ts.add_terrain(0, -1)
	ts.set_terrain_name(0, TERRAIN_STONE, "Stone")
	ts.set_terrain_color(0, TERRAIN_STONE, Color(0.5, 0.5, 0.55))

	# Build each ground source with terrain peering data
	_add_terrain_source(ts, SRC_GRASS,      "res://assets/Terrain/Tileset/Tilemap_color1.png", TERRAIN_GRASS)
	_add_terrain_source(ts, SRC_DIRT,       "res://assets/Terrain/Tileset/Tilemap_color3.png", TERRAIN_DIRT)
	_add_terrain_source(ts, SRC_DARK_GRASS, "res://assets/Terrain/Tileset/Tilemap_color2.png", TERRAIN_DARK_GRASS)
	_add_terrain_source(ts, SRC_STONE,      "res://assets/Terrain/Tileset/Tilemap_color4.png", TERRAIN_STONE)

	# Water source — plain atlas, no terrain needed
	var water_src := TileSetAtlasSource.new()
	water_src.texture = load("res://assets/Terrain/Tileset/Water Background color.png")
	water_src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	water_src.create_tile(Vector2i(0, 0))
	ts.add_source(water_src, SRC_WATER)

	return ts

func _add_terrain_source(ts: TileSet, src_id: int, path: String, terrain_id: int) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Register all tiles in the sheet
	var tex_size   : Vector2i = src.texture.get_size()
	var sheet_cols : int = tex_size.x / TILE_SIZE
	var sheet_rows : int = tex_size.y / TILE_SIZE
	for r in range(sheet_rows):
		for c in range(sheet_cols):
			src.create_tile(Vector2i(c, r))

	ts.add_source(src, src_id)

	# ── Assign terrain peering bits ───────────────────────────────────────────
	var TL := TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER
	var T  := TileSet.CELL_NEIGHBOR_TOP_SIDE
	var TR := TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
	var R  := TileSet.CELL_NEIGHBOR_RIGHT_SIDE
	var BR := TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
	var B  := TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	var BL := TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
	var L  := TileSet.CELL_NEIGHBOR_LEFT_SIDE

	# atlas_coord → neighbor directions that belong to this terrain
	var peering := {
		# ── Outer corners & edges (left group) ──
		Vector2i(0, 0): [R, BR, B],
		Vector2i(1, 0): [L, BL, B, BR, R],
		Vector2i(2, 0): [L, BL, B],
		Vector2i(0, 1): [T, TR, R, BR, B],
		Vector2i(1, 1): [TL, T, TR, R, BR, B, BL, L],
		Vector2i(2, 1): [TL, T, L, BL, B],
		Vector2i(0, 2): [T, TR, R],
		Vector2i(1, 2): [TL, T, TR, R, L],
		Vector2i(2, 2): [TL, T, L],
		# ── Inner corners (right group) ──
		Vector2i(5, 0): [T, TR, R, BR, B, BL, L],
		Vector2i(6, 0): [TL, T, L, BL, B, BR, R],
		Vector2i(5, 1): [TL, T, TR, R, BR, B, L],
		Vector2i(6, 1): [TL, T, TR, R, B, BL, L],
	}

	for atlas_coord in peering:
		var td : TileData = src.get_tile_data(atlas_coord, 0)
		if td == null:
			continue
		td.terrain_set = 0
		td.terrain     = terrain_id
		for neighbor in peering[atlas_coord]:
			td.set_terrain_peering_bit(neighbor, terrain_id)

# ═════════════════════════════════════════════════════════════════════════════
# TILE FILLING
# ═════════════════════════════════════════════════════════════════════════════

func _fill_water() -> void:
	for row in range(WATER_ROWS):
		for col in range(MAP_COLS):
			water_layer.set_cell(Vector2i(col, row), SRC_WATER, Vector2i(0, 0))

func _fill_ground(ts: TileSet) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency  = 0.18
	noise.seed       = 7

	var cells_by_terrain : Dictionary = {
		TERRAIN_GRASS:      [],
		TERRAIN_DIRT:       [],
		TERRAIN_DARK_GRASS: [],
		TERRAIN_STONE:      [],
	}

	for row in range(WATER_ROWS, MAP_ROWS):
		for col in range(MAP_COLS):
			var terrain := _terrain_for_cell(col, row, noise)
			cells_by_terrain[terrain].append(Vector2i(col, row))

	for terrain_id in cells_by_terrain:
		if cells_by_terrain[terrain_id].is_empty():
			continue
		ground_layer.set_cells_terrain_connect(
			cells_by_terrain[terrain_id],
			0,
			terrain_id
		)

func _terrain_for_cell(col: int, row: int, noise: FastNoiseLite) -> int:
	var n : float = noise.get_noise_2d(col * 0.5, row * 0.5) * 3.0
	var effective_col : float = col #+ n

	if effective_col < COL_WILDS_END:
		#if row > MAP_ROWS - 5 and rng.randf() < 0.15:
			#return TERRAIN_STONE
		return TERRAIN_DIRT
		
	#elif effective_col < COL_NOMANS_END:
		##if rng.randf() < 0.2:
			##return TERRAIN_STONE
		#return TERRAIN_DARK_GRASS
	else:
		return TERRAIN_GRASS

func _source_for_terrain(terrain_id: int) -> int:
	match terrain_id:
		TERRAIN_GRASS:      return SRC_GRASS
		TERRAIN_DIRT:       return SRC_DIRT
		TERRAIN_DARK_GRASS: return SRC_DARK_GRASS
		TERRAIN_STONE:      return SRC_STONE
	return SRC_GRASS

# ═════════════════════════════════════════════════════════════════════════════
# DECORATION SCATTERING
# ═════════════════════════════════════════════════════════════════════════════

func _scatter_decorations() -> void:
	# Water rocks in the water strip
	for _i in range(10):
		var col := rng.randi_range(0, MAP_COLS - 1)
		var row := rng.randi_range(0, WATER_ROWS - 1)
		_place_animated(WATER_ROCK_PATHS, WATER_ROCK_FRAMES, 8.0, col, row, 0.85)

	for col in range(MAP_COLS):
		for row in range(WATER_ROWS, MAP_ROWS):
			# Skip any cell the terrain system left empty
			if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
				continue

			var rock_chance := 0.0
			if col < COL_WILDS_END:
				rock_chance = 0.04
			elif col < COL_NOMANS_END:
				rock_chance = 0.10
			if rng.randf() < rock_chance:
				_place_static(ROCK_PATHS, col, row, 0.9)

			var bush_chance := 0.0
			if col >= COL_NOMANS_END:
				bush_chance = 0.08
			elif col < 6:
				bush_chance = 0.06
			if rng.randf() < bush_chance:
				_place_animated(BUSH_PATHS, BUSH_FRAMES, 8.0, col, row, 0.9)

func _place_animated(paths: Array, frame_count: int, fps: float,
					  col: int, row: int, scale_val: float) -> void:
	var path    : String    = paths[rng.randi_range(0, paths.size() - 1)]
	var texture : Texture2D = load(path)
	var frame_w : int       = texture.get_width() / frame_count

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", fps)
	sf.set_animation_loop("idle", true)
	for i in range(frame_count):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = texture
		atlas.region = Rect2(i * frame_w, 0, frame_w, texture.get_height())
		sf.add_frame("idle", atlas)

	var anim           := AnimatedSprite2D.new()
	anim.sprite_frames  = sf
	anim.animation      = "idle"
	anim.frame          = rng.randi_range(0, frame_count - 1)
	anim.position       = _tile_center(col, row)
	anim.scale          = Vector2(scale_val, scale_val)
	anim.flip_h         = rng.randf() > 0.5
	anim.play("idle")
	decor_layer.add_child(anim)

func _place_static(paths: Array, col: int, row: int, scale_val: float) -> void:
	var sprite     := Sprite2D.new()
	sprite.texture  = load(paths[rng.randi_range(0, paths.size() - 1)])
	sprite.position = _tile_center(col, row)
	sprite.scale    = Vector2(scale_val, scale_val)
	sprite.flip_h   = rng.randf() > 0.5
	decor_layer.add_child(sprite)

func _tile_center(col: int, row: int) -> Vector2:
	var jitter := Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0))
	return Vector2(col * TILE_SIZE + TILE_SIZE * 0.5,
				   row * TILE_SIZE + TILE_SIZE * 0.5) + jitter

# ── Public helpers ────────────────────────────────────────────────────────────

func get_zone_center(zone: String) -> Vector2:
	var mid_col: float
	match zone:
		"wilds":  mid_col = COL_WILDS_END * 0.5
		"nomans": mid_col = (COL_WILDS_END + COL_NOMANS_END) * 0.5
		"town":   mid_col = (COL_NOMANS_END + MAP_COLS) * 0.5
		_:        mid_col = MAP_COLS * 0.5
	return Vector2(mid_col * TILE_SIZE, (MAP_ROWS * 0.5) * TILE_SIZE)

# ═════════════════════════════════════════════════════════════════════════════
# WALL
# ═════════════════════════════════════════════════════════════════════════════

func _build_wall() -> void:
	var texture    : Texture2D = load(WALL_TEXTURE)
	var total_rows : int       = MAP_ROWS - WATER_ROWS
	# Cols 0-1 (x=0..63), rows 3-4 (y=96..159) = body and top cap — 64x64 px, no scaling.
	# Cols 0-1 (x=0..63), rows 5-6 (y=160..223) = bottom cap — 64x64 px, no scaling.
	for i in range(total_rows):
		var row : int   = WATER_ROWS + i
		var x   : float = WALL_COL * TILE_SIZE
		var y   : float = row * TILE_SIZE

		var sheet_y : int
		if i == total_rows - 1:
			sheet_y = 5 * WALL_TILE_PX    # bottom cap (rows 5-6)
		elif i == total_rows - 2:
			sheet_y = 3 * WALL_TILE_PX    # bottom cap top (rows 3-4)
		else:
			sheet_y = 3 * WALL_TILE_PX    # body + top cap (row 3)

		var sprite           := Sprite2D.new()
		sprite.texture        = texture
		sprite.region_enabled = true
		sprite.region_rect    = Rect2(0 * WALL_TILE_PX, sheet_y, 2 * WALL_TILE_PX, 2 * WALL_TILE_PX)
		sprite.centered       = false
		sprite.position       = Vector2(x, y)
		sprite.scale          = Vector2(1.0, 1.0)
		wall_layer.add_child(sprite)

		# Collision
		var body  := StaticBody2D.new()
		body.position = Vector2(x + TILE_SIZE * 0.5, y + TILE_SIZE * 0.5)
		var shape := CollisionShape2D.new()
		var box   := RectangleShape2D.new()
		box.size   = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = box
		body.add_child(shape)
		wall_layer.add_child(body)
