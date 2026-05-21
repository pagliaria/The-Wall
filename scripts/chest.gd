extends Node2D

# chest.gd
# Spawned on enemy death. Player clicks to open — plays open animation,
# pops out 1-3 items around itself. One-shot.

# =========================================================================== #
#  Rarity and drop table
# =========================================================================== #

enum ChestType { COMMON, RARE, EPIC }

const ITEM_COUNTS : Dictionary = {
	ChestType.COMMON: 1,
	ChestType.RARE:   2,
	ChestType.EPIC:   3,
}

# Item rarity pools per chest type — weights (higher = more likely)
const ITEM_POOL : Dictionary = {
	ChestType.COMMON: [
		{type = 0, rarity = 0, weight = 70},  # COMMON items
		{type = 0, rarity = 1, weight = 25},  # RARE items
		{type = 0, rarity = 2, weight = 5},   # EPIC items
	],
	ChestType.RARE: [
		{type = 0, rarity = 0, weight = 30},
		{type = 0, rarity = 1, weight = 55},
		{type = 0, rarity = 2, weight = 15},
	],
	ChestType.EPIC: [
		{type = 0, rarity = 0, weight = 10},
		{type = 0, rarity = 1, weight = 40},
		{type = 0, rarity = 2, weight = 50},
	],
}

const ANIM_NAMES : Dictionary = {
	ChestType.COMMON: ["common_closed", "common_open"],
	ChestType.RARE:   ["rare_closed",   "rare_open"],
	ChestType.EPIC:   ["epic_closed",   "epic_open"],
}

const ITEM_SCENE : PackedScene = preload("res://scenes/item.tscn")

# =========================================================================== #
#  State
# =========================================================================== #

var chest_type : ChestType = ChestType.COMMON
var _opened    : bool      = false
var _rng       := RandomNumberGenerator.new()

@onready var _sprite  : AnimatedSprite2D = $Sprite
@onready var _area    : Area2D           = $ClickArea

# =========================================================================== #
#  Setup
# =========================================================================== #

func setup(type: ChestType) -> void:
	chest_type = type

func _ready() -> void:
	_rng.randomize()
	_sprite.play(ANIM_NAMES[chest_type][0])
	_area.input_event.connect(_on_click)

# =========================================================================== #
#  Click to open
# =========================================================================== #

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _opened:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_open()

func _open() -> void:
	_opened = true
	UiAudio.play("chest_open")
	_sprite.play(ANIM_NAMES[chest_type][1])
	_spawn_open_effect()
	_sprite.animation_finished.connect(_on_open_anim_finished)

func _spawn_open_effect() -> void:
	var rarity_color : Color
	match chest_type:
		ChestType.COMMON: rarity_color = Color(1.0,  0.9,  0.5)
		ChestType.RARE:   rarity_color = Color(0.4,  0.6,  1.0)
		ChestType.EPIC:   rarity_color = Color(0.85, 0.3,  1.0)
		_:                rarity_color = Color.WHITE
	# Burst of sparkle nodes flying outward
	var count : int = 8 + chest_type * 4  # 8 common, 12 rare, 16 epic
	for i in count:
		var spark  : Node2D   = Node2D.new()
		var sprite : Sprite2D = Sprite2D.new()
		sprite.texture  = preload("res://assets/Particle FX/Explosion_01.png")
		var cell_size : int = 192
		var atlas     := AtlasTexture.new()
		atlas.atlas   = sprite.texture
		atlas.region  = Rect2(0, 0, cell_size, cell_size)
		sprite.texture  = atlas
		sprite.scale    = Vector2(0.25, 0.25)
		sprite.modulate = rarity_color
		spark.add_child(sprite)
		spark.position = position
		get_parent().add_child(spark)
		spark.z_index = 30
		var angle   : float  = (float(i) / count) * TAU + _rng.randf() * 0.4
		var dist    : float  = _rng.randf_range(60.0, 130.0)
		var dest    : Vector2 = position + Vector2(cos(angle), sin(angle)) * dist
		var tw      : Tween  = spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", dest, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale", Vector2(0.05, 0.05), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(spark, "modulate:a", 0.0, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)
	# Camera shake
	var cam : Camera2D = get_tree().current_scene.get_node_or_null("Camera2D")
	if cam != null:
		var shake_tw : Tween = cam.create_tween()
		var origin   : Vector2 = cam.offset
		for _s in 6:
			shake_tw.tween_property(cam, "offset",
				origin + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-4.0, 4.0)), 0.04)
		shake_tw.tween_property(cam, "offset", origin, 0.05)

func _on_open_anim_finished() -> void:
	_spawn_items()
	# Fade chest out after items pop
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

# =========================================================================== #
#  Item spawning
# =========================================================================== #

func _spawn_items() -> void:
	var count  : int   = ITEM_COUNTS[chest_type]
	var radius : float = 60.0
	# Compute visible world bounds from camera so items don't land offscreen
	var cam       : Camera2D = get_tree().current_scene.get_node_or_null("Camera2D")
	var pad       : float    = 80.0  # inset from screen edge
	var world_min : Vector2  = Vector2.ZERO
	var world_max : Vector2  = Vector2(3072, 1728)
	if cam != null:
		var vp_size  : Vector2 = get_viewport().get_visible_rect().size
		var zoom     : Vector2 = cam.zoom
		var half     : Vector2 = (vp_size / zoom) * 0.5
		world_min = cam.global_position - half + Vector2(pad, pad)
		world_max = cam.global_position + half - Vector2(pad, pad)
	for i in count:
		var angle    : float   = (float(i) / count) * TAU + _rng.randf() * 0.5
		var raw_pos  : Vector2 = position + Vector2(cos(angle), sin(angle)) * radius
		var land_pos : Vector2 = Vector2(
			clampf(raw_pos.x, world_min.x, world_max.x),
			clampf(raw_pos.y, world_min.y, world_max.y)
		)
		var chosen_type   : int = _rng.randi_range(0, 5)
		var chosen_rarity : int = _roll_rarity()
		var item : Node2D = ITEM_SCENE.instantiate()
		item.call("setup", chosen_type, chosen_rarity)
		get_parent().add_child(item)
		item.call("pop_from", position, land_pos)

func _roll_rarity() -> int:
	var pool   : Array = ITEM_POOL[chest_type]
	var total  : int   = 0
	for entry in pool:
		total += entry.weight
	var roll   : int   = _rng.randi_range(0, total - 1)
	var cumul  : int   = 0
	for entry in pool:
		cumul += entry.weight
		if roll < cumul:
			return entry.rarity
	return 0
