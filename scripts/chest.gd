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
	UiAudio.play()
	_sprite.play(ANIM_NAMES[chest_type][1])
	_sprite.animation_finished.connect(_on_open_anim_finished)

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
	for i in count:
		var angle    : float = (float(i) / count) * TAU + _rng.randf() * 0.5
		var land_pos : Vector2 = position + Vector2(cos(angle), sin(angle)) * radius

		var item : Node2D = ITEM_SCENE.instantiate()
		get_parent().add_child(item)

		# Pick item type and rarity
		var chosen_type   : int = _rng.randi_range(0, 5)  # ItemType enum has 6 values
		var chosen_rarity : int = _roll_rarity()

		item.call("setup", chosen_type, chosen_rarity)
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
