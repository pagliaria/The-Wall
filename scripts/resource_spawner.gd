extends Node2D

# Spawns gold stone resources in the town zone at startup.
# Attach to a ResourceLayer Node2D that is a child of Main.

const GoldStoneScene = preload("res://scripts/gold_stone.gd")

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20   # must match terrain.gd COL_NOMANS_END

const GOLD_STONE_BASE      = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png")
const GOLD_STONE_HIGHLIGHT = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3_Highlight.png")
const HIGHLIGHT_FRAMES     = 6
const HIGHLIGHT_FPS        = 10.0

const SPAWN_COUNT          = 6    # how many gold stones to place
const MIN_SPACING          = 3    # minimum tile distance between stones

func _ready() -> void:
	pass  # call spawn() from main.gd after terrain is ready

func spawn(ground_layer: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var placed : Array[Vector2i] = []

	var attempts := 0
	while placed.size() < SPAWN_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1,     MAP_ROWS - 2)

		# Skip empty tiles
		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue

		# Enforce minimum spacing between stones
		var too_close := false
		for p in placed:
			if abs(p.x - col) < MIN_SPACING and abs(p.y - row) < MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue

		placed.append(Vector2i(col, row))
		_spawn_stone(col, row)

func _spawn_stone(col: int, row: int) -> void:
	var node := Node2D.new()
	node.name = "GoldStone_%d_%d" % [col, row]
	node.position = Vector2(col * TILE_SIZE + TILE_SIZE * 0.5,
							row * TILE_SIZE + TILE_SIZE * 0.5)

	# Static base sprite
	var base       := Sprite2D.new()
	base.texture    = GOLD_STONE_BASE
	node.add_child(base)

	# Animated glint highlight
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("glint")
	sf.set_animation_speed("glint", HIGHLIGHT_FPS)
	sf.set_animation_loop("glint", false)   # plays once per glint

	var sheet_w  : int = GOLD_STONE_HIGHLIGHT.get_width()
	var sheet_h  : int = GOLD_STONE_HIGHLIGHT.get_height()
	var frame_w  : int = sheet_w / HIGHLIGHT_FRAMES
	for i in range(HIGHLIGHT_FRAMES):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = GOLD_STONE_HIGHLIGHT
		atlas.region = Rect2(i * frame_w, 0, frame_w, sheet_h)
		sf.add_frame("glint", atlas)

	var highlight           := AnimatedSprite2D.new()
	highlight.name           = "Highlight"
	highlight.sprite_frames  = sf
	highlight.visible        = false
	node.add_child(highlight)

	# Attach the glint behaviour script
	node.set_script(load("res://scripts/gold_stone.gd"))

	add_child(node)
