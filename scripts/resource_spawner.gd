extends Node2D

# Resource spawner — places gold stones, wood trees, and sheep in the town zone.
# A single shared 'placed' array is passed to every spawner so nothing overlaps.

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20   # must match terrain.gd COL_NOMANS_END

# ── Gold Stone 3 ──────────────────────────────────────────────────────────────
const GOLD_BASE      = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png")
const GOLD_HIGHLIGHT = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3_Highlight.png")
const GOLD_HL_FRAMES = 6
const GOLD_HL_FPS    = 10.0
const GOLD_COUNT     = 6
const GOLD_SPACING   = 3

# ── Trees ─────────────────────────────────────────────────────────────────────
const TREE_TEXTURES := [
	preload("res://assets/Terrain/Resources/Wood/Trees/Tree1.png"),
	preload("res://assets/Terrain/Resources/Wood/Trees/Tree2.png"),
]
const TREE_FRAMES  = 8
const TREE_FPS     = 8.0
const TREE_COUNT   = 10
const TREE_SPACING = 3

# ── Sheep ─────────────────────────────────────────────────────────────────────
const SHEEP_IDLE  = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Idle.png")
const SHEEP_GRAZE = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Grass.png")
const SHEEP_MOVE  = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const SHEEP_IDLE_FRAMES  = 6
const SHEEP_GRAZE_FRAMES = 12
const SHEEP_MOVE_FRAMES  = 4
const SHEEP_FPS          = 8.0
const SHEEP_COUNT        = 6
const SHEEP_SPACING      = 2   # sheep can be closer together than trees/gold

func _ready() -> void:
	pass  # called from main.gd after terrain is ready

func spawn(ground_layer: TileMapLayer) -> void:
	# One shared list — every placed resource blocks future ones regardless of type
	var placed : Array[Vector2i] = []
	var rng    := RandomNumberGenerator.new()

	rng.seed = 99
	_spawn_gold(ground_layer, rng, placed)

	rng.seed = 77
	_spawn_trees(ground_layer, rng, placed)

	rng.seed = 55
	_spawn_sheep(ground_layer, rng, placed)

# ── Gold ──────────────────────────────────────────────────────────────────────

func _spawn_gold(ground_layer: TileMapLayer, rng: RandomNumberGenerator,
				 placed: Array[Vector2i]) -> void:
	var attempts := 0
	while placed.size() < GOLD_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1,     MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, GOLD_SPACING):
			continue

		placed.append(Vector2i(col, row))
		_spawn_gold_stone(col, row)

func _spawn_gold_stone(col: int, row: int) -> void:
	var node      := Node2D.new()
	node.name      = "GoldStone_%d_%d" % [col, row]
	node.position  = _tile_center(col, row)
	node.z_index   = row

	var base      := Sprite2D.new()
	base.texture   = GOLD_BASE
	node.add_child(base)

	var highlight := AnimatedSprite2D.new()
	highlight.name = "Highlight"
	highlight.sprite_frames = _make_frames(GOLD_HIGHLIGHT, GOLD_HL_FRAMES, GOLD_HL_FPS, false)
	highlight.animation = "anim"
	highlight.visible   = false
	node.add_child(highlight)

	node.set_script(load("res://scripts/gold_stone.gd"))
	add_child(node)

# ── Trees ─────────────────────────────────────────────────────────────────────

func _spawn_trees(ground_layer: TileMapLayer, rng: RandomNumberGenerator,
				  placed: Array[Vector2i]) -> void:
	var tree_placed := 0
	var attempts    := 0
	while tree_placed < TREE_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1,     MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, TREE_SPACING):
			continue

		placed.append(Vector2i(col, row))
		tree_placed += 1
		_spawn_tree(col, row, rng)

func _spawn_tree(col: int, row: int, rng: RandomNumberGenerator) -> void:
	var texture : Texture2D = TREE_TEXTURES[rng.randi_range(0, TREE_TEXTURES.size() - 1)]

	var node     := AnimatedSprite2D.new()
	node.name     = "Tree_%d_%d" % [col, row]
	node.position = _tile_center(col, row)
	node.z_index  = row
	node.flip_h   = rng.randf() > 0.5

	node.sprite_frames = _make_frames(texture, TREE_FRAMES, TREE_FPS, true)
	node.animation     = "anim"
	node.frame         = rng.randi_range(0, TREE_FRAMES - 1)
	node.play("anim")

	add_child(node)

# ── Sheep ─────────────────────────────────────────────────────────────────────

func _spawn_sheep(ground_layer: TileMapLayer, rng: RandomNumberGenerator,
				  placed: Array[Vector2i]) -> void:
	var sheep_placed := 0
	var attempts     := 0
	while sheep_placed < SHEEP_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1,     MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, SHEEP_SPACING):
			continue

		placed.append(Vector2i(col, row))
		sheep_placed += 1
		_spawn_one_sheep(col, row, rng)

func _spawn_one_sheep(col: int, row: int, rng: RandomNumberGenerator) -> void:
	# Build SpriteFrames with all three named animations
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	sf.add_animation("idle")
	sf.set_animation_speed("idle", SHEEP_FPS)
	sf.set_animation_loop("idle", true)
	_add_frames_to_anim(sf, "idle", SHEEP_IDLE, SHEEP_IDLE_FRAMES)

	sf.add_animation("graze")
	sf.set_animation_speed("graze", SHEEP_FPS)
	sf.set_animation_loop("graze", true)
	_add_frames_to_anim(sf, "graze", SHEEP_GRAZE, SHEEP_GRAZE_FRAMES)

	sf.add_animation("move")
	sf.set_animation_speed("move", SHEEP_FPS)
	sf.set_animation_loop("move", true)
	_add_frames_to_anim(sf, "move", SHEEP_MOVE, SHEEP_MOVE_FRAMES)

	var sheep          := AnimatedSprite2D.new()
	sheep.name          = "Sheep_%d_%d" % [col, row]
	sheep.sprite_frames = sf
	sheep.position      = _tile_center(col, row)
	sheep.z_index       = row
	# Stagger start frame and random flip so they don't look identical
	sheep.frame         = rng.randi_range(0, SHEEP_IDLE_FRAMES - 1)
	sheep.flip_h        = rng.randf() > 0.5
	sheep.set_script(load("res://scripts/sheep.gd"))

	add_child(sheep)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_frames_to_anim(sf: SpriteFrames, anim: String,
						  texture: Texture2D, frame_count: int) -> void:
	var frame_w : int = texture.get_width() / frame_count
	var sheet_h : int = texture.get_height()
	for i in range(frame_count):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = texture
		atlas.region = Rect2(i * frame_w, 0, frame_w, sheet_h)
		sf.add_frame(anim, atlas)

func _make_frames(texture: Texture2D, frame_count: int, fps: float, loop: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("anim")
	sf.set_animation_speed("anim", fps)
	sf.set_animation_loop("anim", loop)
	_add_frames_to_anim(sf, "anim", texture, frame_count)
	return sf

func _tile_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE_SIZE + TILE_SIZE * 0.5,
				   row * TILE_SIZE + TILE_SIZE * 0.5)

func _too_close(placed: Array[Vector2i], col: int, row: int, spacing: int) -> bool:
	for p in placed:
		if abs(p.x - col) < spacing and abs(p.y - row) < spacing:
			return true
	return false
