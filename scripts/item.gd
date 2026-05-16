extends Node2D

# item.gd
# A droppable item that pops out of a chest and lands on the ground.
# The player drags it onto a unit to apply a stat boost.

# =========================================================================== #
#  Item types and rarity
# =========================================================================== #

enum ItemType { SWORD, SHIELD, BOOTS, QUIVER, TOME, AMULET }
enum Rarity   { COMMON, RARE, EPIC }

# Spritesheet is Freebies_Full_Icons.png — 30x30 cells, 4px padding, top-left origin
# Each entry: [col, row] on the sheet (0-indexed)
const ITEM_ICONS : Dictionary = {
	ItemType.SWORD:  Vector2i(0,  0),
	ItemType.SHIELD: Vector2i(1,  0),
	ItemType.BOOTS:  Vector2i(2,  0),
	ItemType.QUIVER: Vector2i(3,  0),
	ItemType.TOME:   Vector2i(4,  0),
	ItemType.AMULET: Vector2i(5,  0),
}

const ICON_SIZE    : int = 22
const ICON_PADDING : int = 4
const ICON_STRIDE  : int = ICON_SIZE + ICON_PADDING  # 26px per cell

# Base stat values per item type
const BASE_STATS : Dictionary = {
	ItemType.SWORD:  {"attack_damage": 3},
	ItemType.SHIELD: {"hp_bonus": 10},
	ItemType.BOOTS:  {"move_speed_multiplier": 0.15},
	ItemType.QUIVER: {"attack_speed_multiplier": -0.20},  # negative = faster (lower attack_rate)
	ItemType.TOME:   {"range_bonus": 40.0},
	ItemType.AMULET: {"attack_damage": 1, "hp_bonus": 4, "range_bonus": 15.0},
}

# Rarity multipliers on base stats
const RARITY_MULTIPLIER : Dictionary = {
	Rarity.COMMON: 1.0,
	Rarity.RARE:   1.8,
	Rarity.EPIC:   3.2,
}

const RARITY_COLORS : Dictionary = {
	Rarity.COMMON: Color(0.85, 0.85, 0.85),
	Rarity.RARE:   Color(0.3,  0.6,  1.0),
	Rarity.EPIC:   Color(0.8,  0.3,  1.0),
}

const ITEM_NAMES : Dictionary = {
	ItemType.SWORD:  "Sword",
	ItemType.SHIELD: "Shield",
	ItemType.BOOTS:  "Boots",
	ItemType.QUIVER: "Quiver",
	ItemType.TOME:   "Tome",
	ItemType.AMULET: "Amulet",
}

# =========================================================================== #
#  State
# =========================================================================== #

var item_type : ItemType = ItemType.SWORD
var rarity    : Rarity   = Rarity.COMMON
var stats     : Dictionary = {}

var _dragging      : bool    = false
var _drag_offset   : Vector2 = Vector2.ZERO
var _on_ground     : bool    = false
var _landed_pos    : Vector2 = Vector2.ZERO
var _base_z_index  : int     = 0

@onready var _sprite  : Sprite2D = $Sprite2D
@onready var _label   : Label    = $Label

# =========================================================================== #
#  Setup
# =========================================================================== #

func setup(p_type: ItemType, p_rarity: Rarity) -> void:
	item_type = p_type
	rarity    = p_rarity
	_build_stats()

func _build_stats() -> void:
	var base : Dictionary = BASE_STATS.get(item_type, {})
	var mult : float      = RARITY_MULTIPLIER.get(rarity, 1.0)
	stats = {}
	for key in base:
		var val = base[key]
		if typeof(val) == TYPE_INT:
			stats[key] = int(round(val * mult))
		else:
			stats[key] = val * mult

func _ready() -> void:
	_base_z_index  = z_index
	_apply_icon()
	_apply_rarity_visuals()
	_label.text    = _get_display_name()
	_label.visible = false
	set_process(false)

func _apply_icon() -> void:
	var tex      : Texture2D  = preload("res://assets/items/Freebies_Full_Icons.png")
	var cell     : Vector2i   = ITEM_ICONS.get(item_type, Vector2i(0, 0))
	var atlas    := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = Rect2(
		cell.x * ICON_STRIDE + ICON_PADDING * 0.5,
		cell.y * ICON_STRIDE + ICON_PADDING * 0.5,
		ICON_SIZE, ICON_SIZE
	)
	_sprite.texture = atlas

func _apply_rarity_visuals() -> void:
	_sprite.modulate = RARITY_COLORS.get(rarity, Color.WHITE)

func _get_display_name() -> String:
	var rarity_names := {Rarity.COMMON: "Common", Rarity.RARE: "Rare", Rarity.EPIC: "Epic"}
	return "%s %s" % [rarity_names.get(rarity, ""), ITEM_NAMES.get(item_type, "Item")]

# =========================================================================== #
#  Ground landing animation
# =========================================================================== #

func pop_from(origin: Vector2, target: Vector2) -> void:
	position = origin
	var tw   := create_tween()
	# Arc up then land
	var mid  := origin.lerp(target, 0.5) + Vector2(0, -60)
	tw.tween_property(self, "position", mid, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_on_ground   = true
		_landed_pos  = target
		add_to_group("ground_items")
		_label.visible = true
		# Gentle bob
		var bob := create_tween().set_loops()
		bob.tween_property(_sprite, "position:y", -4.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(_sprite, "position:y",  0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

# =========================================================================== #
#  Drag and drop
# =========================================================================== #

func _input(event: InputEvent) -> void:
	if not _on_ground:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var world_mouse : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			var local       : Vector2 = to_local(world_mouse)
			if local.length() < 28.0:
				_dragging    = true
				_drag_offset = position - world_mouse
				_label.visible = true
				z_index = _base_z_index + 50
				set_process(true)
				get_viewport().set_input_as_handled()  # block unit_selection drag
		else:
			if _dragging:
				_dragging = false
				set_process(false)
				z_index = _base_z_index
				get_viewport().set_input_as_handled()
				_try_apply_to_unit()

func _process(_delta: float) -> void:
	if _dragging:
		position = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()) + _drag_offset

func _try_apply_to_unit() -> void:
	# Find the nearest unit within drop radius
	const DROP_RADIUS : float = 60.0
	var best_unit     : Node  = null
	var best_dist     : float = DROP_RADIUS
	for body in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(body):
			continue
		var d : float = position.distance_to(body.position)
		if d < best_dist:
			best_dist  = d
			best_unit  = body
	if best_unit != null and best_unit.has_method("apply_item"):
		best_unit.apply_item(self)
		queue_free()
	else:
		# Snap back to ground
		var tw := create_tween()
		tw.tween_property(self, "position", _landed_pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
