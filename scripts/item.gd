extends Node2D

# item.gd
# A droppable item that pops out of a chest and lands on the ground.
# The player drags it onto a unit to apply a stat boost.

# =========================================================================== #
#  Item types and rarity
# =========================================================================== #

enum ItemType { SWORD, SHIELD, BOOTS, QUIVER, TOME, AMULET }
enum Rarity   { COMMON, RARE, EPIC }

# Icons per item type — [common, rare, epic] cell coordinates (col, row) on 32px grid
const ITEM_ICONS : Dictionary = {
	ItemType.SWORD:  [Vector2i(0,  0), Vector2i(17, 1), Vector2i(15, 2)],
	ItemType.SHIELD: [Vector2i(10, 0), Vector2i(14, 1), Vector2i(15, 1)],
	ItemType.BOOTS:  [Vector2i(2,  1), Vector2i(0,  1), Vector2i(0,  2)],
	ItemType.QUIVER: [Vector2i(3,  0), Vector2i(5,  1), Vector2i(5,  2)],
	ItemType.TOME:   [Vector2i(19, 0), Vector2i(19, 1), Vector2i(20, 2)],
	ItemType.AMULET: [Vector2i(2,  2), Vector2i(2,  3), Vector2i(17, 2)],
}

const ICON_SIZE   : int = 32
const ICON_STRIDE : int = 32  # no padding — tight grid

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
	_build_tooltip()
	set_process(false)

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
	var tex      : Texture2D  = preload("res://assets/items/Freebies_Full_Icons.png")
	var icons    : Array      = ITEM_ICONS.get(item_type, [Vector2i(0,0), Vector2i(0,0), Vector2i(0,0)])
	var cell     : Vector2i   = icons[clamp(int(rarity), 0, icons.size() - 1)]
	var atlas    := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = Rect2(cell.x * ICON_STRIDE, cell.y * ICON_STRIDE, ICON_SIZE, ICON_SIZE)
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
	if event is InputEventMouseMotion:
		var world_mouse : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		var local       : Vector2 = to_local(world_mouse)
		var over        : bool    = local.length() < 28.0
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
			if local.length() < 28.0:
				_dragging    = true
				_drag_offset = position - world_mouse
				_label.visible = true
				if _tooltip != null:
					_tooltip.visible = false
				z_index = _base_z_index + 50
				_show_sell_zone(true)
				set_process(true)
				get_viewport().set_input_as_handled()
		else:
			if _dragging:
				_dragging = false
				set_process(false)
				z_index = _base_z_index
				get_viewport().set_input_as_handled()
				_show_sell_zone(false)
				_try_apply_to_unit()

func _process(_delta: float) -> void:
	if _dragging:
		position = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()) + _drag_offset
		# Highlight sell zone when dragging near it
		var screen_pos : Vector2 = get_viewport().get_canvas_transform() * position
		for zone in get_tree().get_nodes_in_group("sell_zone"):
			if is_instance_valid(zone) and zone.has_method("set_highlighted"):
				zone.set_highlighted(zone.get_global_rect().has_point(screen_pos))

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

func _sell() -> void:
	var nuggets : int = SELL_PRICES.get(rarity, 1)
	ResourceManager.add("gold", nuggets)
	UiAudio.play("loot_interact")
	CombatNumbers.show_number(position, nuggets * 10, true, false)
	queue_free()
