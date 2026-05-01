extends Node2D

# Terrain manager for "The Wall"
# Builds the TileSet in script (prevents Godot overwriting .tscn sources),
# then scatters decorations:
#   - Bushes      → AnimatedSprite2D  (8 frames, wind sway)
#   - Water Rocks → AnimatedSprite2D  (16 frames, ripple)
#   - Rocks       → Sprite2D          (static single image)

# ── Map dimensions ────────────────────────────────────────────────────────────
const TILE_SIZE  = 64
const MAP_COLS   = 32
const MAP_ROWS   = 18
const WATER_ROWS = 2        # top rows filled with water

# ── Zone column boundaries ────────────────────────────────────────────────────
const COL_WILDS_END  = 11   # cols  0–10  → enemy wilds
const COL_NOMANS_END = 20   # cols 11–19  → no-man's land  |  20–31 → town

# ── Atlas source IDs ──────────────────────────────────────────────────────────
const SRC_GRASS      = 0
const SRC_DIRT       = 1
const SRC_DARK_GRASS = 2
const SRC_STONE      = 3
const SRC_WATER      = 4

# ── Tileset atlas layout ──────────────────────────────────────────────────────
# Each color sheet is 512 x 320 px — two groups of 4 columns, 5 rows, 64px tiles.
# The large solid interior fill block sits at atlas coord (1, 1).
# We only need one good solid fill tile per source — (1,1) works for all sheets.
const FILL     := Vector2i(1, 1)
const FILL_ALT := Vector2i(6, 1)   # right-group equivalent for visual variety

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

# Confirmed frame counts from reading the actual PNGs:
# Bushes: 8 frames horizontal, Water Rocks: 16 frames horizontal, Rocks: 1 frame
const BUSH_FRAMES       = 8
const WATER_ROCK_FRAMES = 16

@onready var ground_layer : TileMapLayer = $GroundLayer
@onready var water_layer  : TileMapLayer = $WaterLayer
@onready var decor_layer  : Node2D       = $DecorationLayer

var rng := RandomNumberGenerator.new()

# ── Boot ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	rng.seed = 42
	_build_tileset()
	_fill_water()
	_fill_ground()
	_scatter_decorations()

# ── TileSet construction ──────────────────────────────────────────────────────

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var sources := [
		{ "id": SRC_GRASS,      "path": "res://assets/Terrain/Tileset/Tilemap_color1.png" },
		{ "id": SRC_DIRT,       "path": "res://assets/Terrain/Tileset/Tilemap_color3.png" },
		{ "id": SRC_DARK_GRASS, "path": "res://assets/Terrain/Tileset/Tilemap_color2.png" },
		{ "id": SRC_STONE,      "path": "res://assets/Terrain/Tileset/Tilemap_color4.png" },
		{ "id": SRC_WATER,      "path": "res://assets/Terrain/Tileset/Water Background color.png" },
	]

	for entry in sources:
		var src := TileSetAtlasSource.new()
		src.texture = load(entry["path"])
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		var tex_size : Vector2i = src.texture.get_size()
		var sheet_cols := tex_size.x / TILE_SIZE
		var sheet_rows := tex_size.y / TILE_SIZE
		for r in range(sheet_rows):
			for c in range(sheet_cols):
				src.create_tile(Vector2i(c, r))
		ts.add_source(src, entry["id"])

	ground_layer.tile_set = ts
	water_layer.tile_set  = ts

# ── Tile filling ──────────────────────────────────────────────────────────────

func _fill_water() -> void:
	for row in range(WATER_ROWS):
		for col in range(MAP_COLS):
			water_layer.set_cell(Vector2i(col, row), SRC_WATER, Vector2i(0, 0))

func _fill_ground() -> void:
	for row in range(WATER_ROWS, MAP_ROWS):
		for col in range(MAP_COLS):
			var src   := _ground_source(col, row)
			var atlas := FILL if rng.randf() > 0.2 else FILL_ALT
			ground_layer.set_cell(Vector2i(col, row), src, atlas)

func _ground_source(col: int, row: int) -> int:
	if col < COL_WILDS_END:
		if row > MAP_ROWS - 4 and rng.randf() < 0.12:
			return SRC_STONE
		return SRC_DARK_GRASS
	elif col < COL_NOMANS_END:
		if rng.randf() < 0.18:
			return SRC_STONE
		return SRC_DIRT
	else:
		return SRC_GRASS

# ── Decoration scattering ─────────────────────────────────────────────────────

func _scatter_decorations() -> void:
	# Water rocks in the water strip
	for _i in range(10):
		var col := rng.randi_range(0, MAP_COLS - 1)
		var row := rng.randi_range(0, WATER_ROWS - 1)
		_place_animated(WATER_ROCK_PATHS, WATER_ROCK_FRAMES, 8.0, col, row, 0.85)

	for col in range(MAP_COLS):
		for row in range(WATER_ROWS, MAP_ROWS):
			# Rocks (static) in wilds and no-man's land
			var rock_chance := 0.0
			if col < COL_WILDS_END:
				rock_chance = 0.04
			elif col < COL_NOMANS_END:
				rock_chance = 0.10
			if rng.randf() < rock_chance:
				_place_static(ROCK_PATHS, col, row, 0.9)

			# Animated bushes in town zone and deep wilds
			var bush_chance := 0.0
			if col >= COL_NOMANS_END:
				bush_chance = 0.08
			elif col < 6:
				bush_chance = 0.06
			if rng.randf() < bush_chance:
				_place_animated(BUSH_PATHS, BUSH_FRAMES, 8.0, col, row, 0.9)

# Place an AnimatedSprite2D for animated decorations (bushes, water rocks)
func _place_animated(paths: Array, frame_count: int, fps: float,
					 col: int, row: int, scale_val: float) -> void:
	var path : String       = paths[rng.randi_range(0, paths.size() - 1)]
	var texture : Texture2D = load(path)
	var sheet_w : int       = texture.get_width()
	var sheet_h : int       = texture.get_height()
	var frame_w : int       = sheet_w / frame_count

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", fps)
	sf.set_animation_loop("idle", true)

	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas  = texture
		atlas.region = Rect2(i * frame_w, 0, frame_w, sheet_h)
		sf.add_frame("idle", atlas)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = sf
	anim.animation     = "idle"
	anim.frame         = rng.randi_range(0, frame_count - 1)
	anim.position      = _tile_center(col, row)
	anim.scale         = Vector2(scale_val, scale_val)
	anim.flip_h        = rng.randf() > 0.5
	anim.play("idle")
	decor_layer.add_child(anim)

# Place a plain Sprite2D for static decorations (rocks)
func _place_static(paths: Array, col: int, row: int, scale_val: float) -> void:
	var sprite      := Sprite2D.new()
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
