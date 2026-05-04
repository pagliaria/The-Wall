extends Node2D

const TILE_SIZE := 64
const MAP_COLS := 48
const MAP_ROWS := 27
const WATER_ROWS := 3
const COL_TOWN_START := 20

const Z_GOLD := 2
const Z_UNITS := 3
const Z_TREES := 4

const STUMP_RADIUS := 20.0

const GOLD_BASE = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png")
const GOLD_HIGHLIGHT = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3_Highlight.png")
const GOLD_HL_FRAMES := 6
const GOLD_HL_FPS := 10.0
const GOLD_COUNT := 6
const GOLD_SPACING := 3
const GOLD_RADIUS := 25.0
const GOLD_PLACE_RADIUS := 34.0
const GOLD_PLACE_OFFSET := Vector2(0.0, -30.0)
const GOLD_HOVER_RADIUS := 30.0
const GOLD_HOVER_OFFSET := Vector2(0.0, -15.0)

const TREE_TEXTURES := [
	preload("res://assets/Terrain/Resources/Wood/Trees/Tree1.png"),
	preload("res://assets/Terrain/Resources/Wood/Trees/Tree2.png"),
]
const TREE_FRAMES := 8
const TREE_FPS := 8.0
const TREE_COUNT := 10
const TREE_SPACING := 3
const TREE_PLACE_RADIUS := 56.0
const TREE_PLACE_OFFSET := Vector2(0.0, 0.0)
const TREE_HOVER_RADIUS := 36.0
const TREE_HOVER_OFFSET := Vector2(0.0, 40.0)   # trunk area

const SHEEP_SCENE = preload("res://scenes/sheep.tscn")
const SHEEP_IDLE = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Idle.png")
const SHEEP_GRAZE = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Grass.png")
const SHEEP_MOVE = preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const SHEEP_IDLE_FRAMES := 6
const SHEEP_GRAZE_FRAMES := 12
const SHEEP_MOVE_FRAMES := 4
const SHEEP_FPS := 8.0
const SHEEP_COUNT := 5
const SHEEP_SPACING := 2
const SHEEP_PLACE_RADIUS := 26.0
const SHEEP_HOVER_RADIUS := 28.0

# Group name used by unit_selection.gd to find resource hover areas
const RESOURCE_HOVER_GROUP := "resource_hover"

func _ready() -> void:
	pass

func spawn(ground_layer: TileMapLayer) -> void:
	var placed: Array[Vector2i] = []
	var rng := RandomNumberGenerator.new()

	rng.seed = 99
	_spawn_gold(ground_layer, rng, placed)

	rng.seed = 80
	_spawn_trees(ground_layer, rng, placed)

	rng.seed = 55
	_spawn_sheep(ground_layer, rng, placed)

func _spawn_gold(ground_layer: TileMapLayer, rng: RandomNumberGenerator, placed: Array[Vector2i]) -> void:
	var attempts := 0
	while placed.size() < GOLD_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1, MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, GOLD_SPACING):
			continue

		placed.append(Vector2i(col, row))
		_spawn_gold_stone(col, row)

func _spawn_gold_stone(col: int, row: int) -> void:
	var node := Node2D.new()
	node.name = "GoldStone_%d_%d" % [col, row]
	node.position = _tile_center(col, row)
	node.z_index = Z_GOLD

	var base := Sprite2D.new()
	base.texture = GOLD_BASE
	node.add_child(base)

	var highlight := AnimatedSprite2D.new()
	highlight.name = "Highlight"
	highlight.sprite_frames = _make_frames(GOLD_HIGHLIGHT, GOLD_HL_FRAMES, GOLD_HL_FPS, false)
	highlight.animation = "anim"
	highlight.visible = false
	node.add_child(highlight)

	node.set_script(load("res://scripts/gold_stone.gd"))
	add_child(node)

	var gold_collision := StaticBody2D.new()
	gold_collision.name = "Gold_collision_%d_%d" % [col, row]
	gold_collision.position = _tile_center(col, row)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GOLD_RADIUS
	shape.shape = circle
	gold_collision.add_child(shape)
	add_child(gold_collision)

	_add_placement_blocker(node, GOLD_PLACE_OFFSET, GOLD_PLACE_RADIUS)
	_add_hover_area(node, GOLD_HOVER_OFFSET, GOLD_HOVER_RADIUS)

func _spawn_trees(ground_layer: TileMapLayer, rng: RandomNumberGenerator, placed: Array[Vector2i]) -> void:
	var tree_placed := 0
	var attempts := 0
	while tree_placed < TREE_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1, MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, TREE_SPACING):
			continue

		placed.append(Vector2i(col, row))
		tree_placed += 1
		_spawn_tree(col, row, rng)

func _spawn_tree(col: int, row: int, rng: RandomNumberGenerator) -> void:
	var texture: Texture2D = TREE_TEXTURES[rng.randi_range(0, TREE_TEXTURES.size() - 1)]

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Tree_%d_%d" % [col, row]
	sprite.position = _tile_center(col, row)
	sprite.z_index = Z_TREES
	sprite.flip_h = rng.randf() > 0.5
	sprite.sprite_frames = _make_frames(texture, TREE_FRAMES, TREE_FPS, true)
	sprite.animation = "anim"
	sprite.frame = rng.randi_range(0, TREE_FRAMES - 1)
	sprite.play("anim")
	add_child(sprite)

	var stump := StaticBody2D.new()
	stump.name = "Stump_%d_%d" % [col, row]
	stump.position = _tile_center(col, row) + Vector2(0.0, 100.0)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = STUMP_RADIUS
	shape.shape = circle
	stump.add_child(shape)
	add_child(stump)

	_add_placement_blocker(sprite, TREE_PLACE_OFFSET, TREE_PLACE_RADIUS)
	_add_hover_area(sprite, TREE_HOVER_OFFSET, TREE_HOVER_RADIUS)

func _spawn_sheep(ground_layer: TileMapLayer, rng: RandomNumberGenerator, placed: Array[Vector2i]) -> void:
	var sheep_placed := 0
	var attempts := 0
	while sheep_placed < SHEEP_COUNT and attempts < 500:
		attempts += 1
		var col := rng.randi_range(COL_TOWN_START + 1, MAP_COLS - 2)
		var row := rng.randi_range(WATER_ROWS + 1, MAP_ROWS - 2)

		if ground_layer.get_cell_source_id(Vector2i(col, row)) == -1:
			continue
		if _too_close(placed, col, row, SHEEP_SPACING):
			continue

		placed.append(Vector2i(col, row))
		sheep_placed += 1
		_spawn_one_sheep(col, row, rng)

func _spawn_one_sheep(col: int, row: int, rng: RandomNumberGenerator) -> void:
	var sheep := SHEEP_SCENE.instantiate()
	sheep.name = "Sheep_%d_%d" % [col, row]
	sheep.position = _tile_center(col, row)
	sheep.z_index = Z_UNITS

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

	add_child(sheep)

	var sprite := sheep.get_node("Sprite") as AnimatedSprite2D
	sprite.sprite_frames = sf
	sprite.frame = rng.randi_range(0, SHEEP_IDLE_FRAMES - 1)
	sprite.flip_h = rng.randf() > 0.5

	_add_placement_blocker(sheep, Vector2.ZERO, SHEEP_PLACE_RADIUS)
	_add_hover_area(sheep, Vector2.ZERO, SHEEP_HOVER_RADIUS)

func _add_frames_to_anim(sf: SpriteFrames, anim: String, texture: Texture2D, frame_count: int) -> void:
	var frame_w: int = texture.get_width() / frame_count
	var sheet_h: int = texture.get_height()
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
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
	return Vector2(col * TILE_SIZE + TILE_SIZE * 0.5, row * TILE_SIZE + TILE_SIZE * 0.5)

func _too_close(placed: Array[Vector2i], col: int, row: int, spacing: int) -> bool:
	for p in placed:
		if abs(p.x - col) < spacing and abs(p.y - row) < spacing:
			return true
	return false

func _add_placement_blocker(parent: Node2D, local_pos: Vector2, radius: float) -> void:
	var blocker := Area2D.new()
	blocker.name = "PlacementBlocker"
	blocker.position = local_pos

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	blocker.add_child(shape)

	parent.add_child(blocker)

func _add_hover_area(parent: Node2D, local_pos: Vector2, radius: float) -> void:
	var area := Area2D.new()
	area.name = "ResourceHover"
	area.position = local_pos
	# Collision layer 0, mask 0 — purely for point queries, no physics interaction
	area.collision_layer = 0
	area.collision_mask  = 0
	area.monitorable     = true
	area.monitoring      = false
	area.add_to_group(RESOURCE_HOVER_GROUP)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)

	parent.add_child(area)
