extends Node2D

# item.gd
# A droppable item that pops out of a chest and lands on the ground.
# The player drags it onto a unit to apply a stat boost.

# =========================================================================== #
#  Item types and rarity
# =========================================================================== #

enum ItemType { SWORD, SHIELD, BOOTS, QUIVER, TOME, AMULET }
enum Rarity   { COMMON, RARE, EPIC }

# item_drops.png layout: 6 rows (item type), 3 cols (rarity: common, rare, epic left to right)
# Row order below MUST match art sheet top to bottom. Flip values here if art order differs.
const ITEM_ROW : Dictionary = {
	ItemType.SWORD:  0,
	ItemType.SHIELD: 1,
	ItemType.BOOTS:  2,
	ItemType.QUIVER: 3,
	ItemType.TOME:   4,
	ItemType.AMULET: 5,
}

const ICON_GRID_COLS : int = 3
const ICON_GRID_ROWS : int = 6

# Fraction of each cell's edge to crop off (per side) when reading the sheet.
# item_drops.png leaves gutter space baked around each icon inside its cell,
# so this zooms into the actual art instead of showing that empty border.
# 0.0 = no crop (full cell). Raise to crop tighter, lower if art starts clipping.
const ICON_CELL_INSET_RATIO : float = 0.06

# Final on-screen icon size in px, whatever the source sheet's raw cell resolution is
const ICON_DISPLAY_SIZE : float = 96.0

# Click / hover hit radius, tied to icon size so it never falls out of sync
const ICON_HIT_RADIUS : float = ICON_DISPLAY_SIZE / 2.0

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

const SELL_PRICES : Dictionary = {
	Rarity.COMMON: 1,   # 10 gold
	Rarity.RARE:   3,   # 30 gold
	Rarity.EPIC:   8,   # 80 gold
}

var item_type : ItemType = ItemType.SWORD
var rarity    : Rarity   = Rarity.COMMON
var stats     : Dictionary = {}

var _dragging      : bool    = false
var _drag_offset   : Vector2 = Vector2.ZERO
var _on_ground     : bool    = false
var _landed_pos    : Vector2 = Vector2.ZERO
var _base_z_index  : int     = 0
var _hovered       : bool    = false
var _world_parent  : Node    = null

@onready var _sprite   : Sprite2D = $Sprite2D
@onready var _label    : Label    = $Label
var _tooltip           : Control  = null

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
	_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	_position_label()
	_build_tooltip()
	set_process(false)

func _position_label() -> void:
	# Center label over icon width, sit just above icon top edge, whatever ICON_DISPLAY_SIZE is
	var half_size : float = ICON_DISPLAY_SIZE / 2.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.offset_left   = -half_size
	_label.offset_right  =  half_size
	_label.offset_bottom = -half_size - 4.0
	_label.offset_top    = _label.offset_bottom - 10.0

func _build_tooltip() -> void:
	# Build as a CanvasLayer child so it renders above everything in screen space
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.08, 0.06, 0.04, 0.92)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color        = RARITY_COLORS.get(rarity, Color.WHITE)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	cl.add_child(panel)
	_tooltip = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = _get_display_name()
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	vbox.add_child(title)

	# Separator line
	var sep := ColorRect.new()
	sep.color                = RARITY_COLORS.get(rarity, Color.WHITE)
	sep.modulate.a           = 0.4
	sep.custom_minimum_size  = Vector2(0, 1)
	vbox.add_child(sep)

	# Stat lines
	for key in stats:
		var stat_label := Label.new()
		stat_label.text = "%s: %s" % [_format_stat_key(key), _format_stat_val(key, stats[key])]
		stat_label.add_theme_font_size_override("font_size", 11)
		stat_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		vbox.add_child(stat_label)

func _format_stat_key(key: String) -> String:
	match key:
		"attack_damage":           return "Attack Damage"
		"hp_bonus":                return "Max HP"
		"move_speed_multiplier":   return "Move Speed"
		"attack_speed_multiplier": return "Attack Speed"
		"range_bonus":             return "Range"
	return key.capitalize()

func _format_stat_val(key: String, val) -> String:
	match key:
		"move_speed_multiplier":   return "+%.0f%%" % (float(val) * 100.0)
		"attack_speed_multiplier": return "%.0f%%" % (float(val) * 100.0)
		"range_bonus":             return "+%d" % int(val)
	return "+%s" % str(val)

func _apply_icon() -> void:
	var tex        : Texture2D = preload("res://assets/items/item_drops.png")
	var cell_w     : float     = float(tex.get_width())  / float(ICON_GRID_COLS)
	var cell_h     : float     = float(tex.get_height()) / float(ICON_GRID_ROWS)
	var row        : int       = ITEM_ROW.get(item_type, 0)
	var col        : int       = clamp(int(rarity), 0, ICON_GRID_COLS - 1)
	var inset_w    : float     = cell_w * ICON_CELL_INSET_RATIO
	var inset_h    : float     = cell_h * ICON_CELL_INSET_RATIO
	var crop_w     : float     = cell_w - inset_w * 2.0
	var crop_h     : float     = cell_h - inset_h * 2.0
	var atlas      := AtlasTexture.new()
	atlas.atlas    = tex
	atlas.region   = Rect2(col * cell_w + inset_w, row * cell_h + inset_h, crop_w, crop_h)
	_sprite.texture = atlas
	var uniform_scale : float = ICON_DISPLAY_SIZE / crop_w
	_sprite.scale     = Vector2(uniform_scale, uniform_scale)

func _apply_rarity_visuals() -> void:
	# Art sheet already shows rarity per column, no tint needed on top.
	_sprite.modulate = Color.WHITE

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
	if event is InputEventMouseMotion:
		var world_mouse : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		var local       : Vector2 = to_local(world_mouse)
		var over        : bool    = local.length() < ICON_HIT_RADIUS
		if over != _hovered:
			_hovered = over
			if _tooltip != null:
				_tooltip.visible = _hovered and not _dragging
		if _hovered and _tooltip != null:
			# Position tooltip near cursor in screen space with edge clamping
			var vp_size  : Vector2 = get_viewport().get_visible_rect().size
			var tip_size : Vector2 = _tooltip.size
			var offset   : Vector2 = Vector2(16, -tip_size.y - 8)
			var pos      : Vector2 = event.position + offset
			pos.x = clampf(pos.x, 4, vp_size.x - tip_size.x - 4)
			pos.y = clampf(pos.y, 4, vp_size.y - tip_size.y - 4)
			_tooltip.position = pos
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var world_mouse : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			var local       : Vector2 = to_local(world_mouse)
			if local.length() < ICON_HIT_RADIUS:
				_begin_drag(event.position)
				get_viewport().set_input_as_handled()
		else:
			if _dragging:
				_end_drag()
				get_viewport().set_input_as_handled()

func _begin_drag(screen_mouse: Vector2) -> void:
	_dragging = true
	_label.visible = true
	if _tooltip != null:
		_tooltip.visible = false
	_world_parent = get_parent()
	var screen_pos : Vector2 = get_viewport().get_canvas_transform() * position
	_drag_offset = screen_pos - screen_mouse
	_move_into_hud()
	z_index = _base_z_index + 200
	_show_sell_zone(true)
	set_process(true)
	position = screen_mouse + _drag_offset

func _end_drag() -> void:
	_dragging = false
	set_process(false)
	var screen_pos : Vector2 = position
	var world_pos  : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	_show_sell_zone(false)
	if _is_over_sell_zone(screen_pos):
		_sell()
		return
	_move_back_to_world(world_pos)
	_try_apply_to_unit()

func _move_into_hud() -> void:
	var hud : CanvasLayer = get_tree().current_scene.get_node_or_null("HUD")
	if hud == null or get_parent() == hud:
		return
	var old_parent : Node = get_parent()
	if old_parent != null:
		old_parent.remove_child(self)
	hud.add_child(self)

func _move_back_to_world(world_pos: Vector2) -> void:
	if _world_parent != null and is_instance_valid(_world_parent) and get_parent() != _world_parent:
		var current_parent : Node = get_parent()
		if current_parent != null:
			current_parent.remove_child(self)
		_world_parent.add_child(self)
	position = world_pos
	z_index = _base_z_index
	_world_parent = null

func _process(_delta: float) -> void:
	if _dragging:
		position = get_viewport().get_mouse_position() + _drag_offset
		var over_sell_zone : bool = false
		var screen_pos : Vector2 = position
		for zone in get_tree().get_nodes_in_group("sell_zone"):
			if is_instance_valid(zone) and zone.has_method("set_highlighted"):
				var is_over : bool = zone.get_global_rect().has_point(screen_pos)
				zone.set_highlighted(is_over)
				if zone.has_method("set_preview_price"):
					if is_over:
						zone.set_preview_price(_get_sell_price())
						over_sell_zone = true
					else:
						zone.clear_preview_price()
		if not over_sell_zone:
			for zone in get_tree().get_nodes_in_group("sell_zone"):
				if is_instance_valid(zone) and zone.has_method("clear_preview_price"):
					zone.clear_preview_price()

func _try_apply_to_unit() -> void:
	# Check sell zone first
	var screen_pos : Vector2 = get_viewport().get_canvas_transform() * position
	for zone in get_tree().get_nodes_in_group("sell_zone"):
		if not is_instance_valid(zone):
			continue
		var rect : Rect2 = zone.get_global_rect()
		if rect.has_point(screen_pos):
			_sell()
			return
	# Find nearest unit within drop radius
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
		if not best_unit.can_equip_item(self):
			# Can't equip — snap back
			var tw := create_tween()
			tw.tween_property(self, "position", _landed_pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			return
		UiAudio.play("loot_interact")
		best_unit.apply_item(self)
		queue_free()
	else:
		var tw := create_tween()
		tw.tween_property(self, "position", _landed_pos, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_sell_zone(on: bool) -> void:
	for zone in get_tree().get_nodes_in_group("sell_zone"):
		if is_instance_valid(zone):
			zone.visible = on
			if not on and zone.has_method("set_highlighted"):
				zone.set_highlighted(false)
			if not on and zone.has_method("clear_preview_price"):
				zone.clear_preview_price()

func _is_over_sell_zone(screen_pos: Vector2) -> bool:
	for zone in get_tree().get_nodes_in_group("sell_zone"):
		if not is_instance_valid(zone):
			continue
		if zone.get_global_rect().has_point(screen_pos):
			return true
	return false

func _sell() -> void:
	var gold_value : int = _get_sell_price()
	ResourceManager.add("gold", int(gold_value / 10))
	UiAudio.play("loot_interact")
	CombatNumbers.show_number(position, gold_value, true, false)
	queue_free()

func _get_sell_price() -> int:
	return int(SELL_PRICES.get(rarity, 1)) * 10
