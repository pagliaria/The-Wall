# selection_panel.gd
extends CanvasLayer

const AVATARS := {
	"Warrior": "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_02.png",
	"Pawn":    "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_03.png",
	"Monk":    "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_04.png",
	"Archer":  "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_07.png",
	"Lancer":  "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_08.png",
}
const DEFAULT_AVATAR := "res://assets/UI Elements/UI Elements/Human Avatars/Avatars_05.png"

@onready var _panel        : NinePatchRect = $Panel
@onready var _single_view  : Control       = $Panel/SingleView
@onready var _multi_view   : Control       = $Panel/MultiView
@onready var _portrait     : TextureRect   = $Panel/SingleView/Portrait
@onready var _name_label   : Label         = $Panel/SingleView/Info/HBoxContainer/NameLabel
@onready var _level_label  : Label         = $Panel/SingleView/Info/HBoxContainer/LevelLabel
@onready var _status_label : Label         = $Panel/SingleView/Info/StatusLabel
@onready var _attack_range_label  : Label  = $Panel/SingleView/Info/StatsGrid/AttackRangeValue
@onready var _attack_damage_label : Label  = $Panel/SingleView/Info/StatsGrid/AttackDamageValue
@onready var _attack_speed_label  : Label  = $Panel/SingleView/Info/StatsGrid/AttackSpeedValue
@onready var _move_speed_label    : Label  = $Panel/SingleView/Info/StatsGrid/MoveSpeedValue
@onready var _attack_range_title  : Label  = $Panel/SingleView/Info/StatsGrid/AttackRangeTitle
@onready var _attack_damage_title : Label  = $Panel/SingleView/Info/StatsGrid/AttackDamageTitle
@onready var _attack_speed_title  : Label  = $Panel/SingleView/Info/StatsGrid/AttackSpeedTitle
@onready var _hp_fill      : TextureRect   = $Panel/SingleView/Info/HpBarContainer/Fill
@onready var _hp_label     : Label         = $Panel/SingleView/Info/HpBarContainer/HpLabel
@onready var _multi_grid   : GridContainer = $Panel/MultiView/Grid
@onready var _multi_total  : Label         = $Panel/MultiView/TotalLabel

var _tracked_unit : Node = null

const UNIT_STATS := {
	"Warrior": {"attack_range": 48.0,  "attack_damage": 5,    "attack_speed": 3.0, "move_speed": 60.0},
	"Archer":  {"attack_range": 500.0, "attack_damage": 3,    "attack_speed": 2.0, "move_speed": 62.0},
	"Lancer":  {"attack_range": 72.0,  "attack_damage": 8,    "attack_speed": 4.0, "move_speed": 55.0},
	"Monk":    {"cast_range":   300.0, "heal_amount":   6,    "cast_speed":   2.2, "move_speed": 58.0},
	"Pawn":    {"attack_range": null,  "attack_damage": null, "attack_speed": null, "move_speed": 50.0},
}

# =========================================================================== #
#  Public API
# =========================================================================== #

func refresh(units: Array) -> void:
	_tracked_unit = null

	if units.is_empty():
		_panel.hide()
		return

	_panel.show()

	if units.size() == 1 and is_instance_valid(units[0]):
		_show_single(units[0])
	else:
		_show_multi(units)

# =========================================================================== #
#  Single-unit view
# =========================================================================== #

func _show_single(unit: Node) -> void:
	_single_view.show()
	_multi_view.hide()
	_tracked_unit = unit

	var type_key := _unit_type(unit)
	_portrait.texture  = load(AVATARS.get(type_key, DEFAULT_AVATAR))
	_apply_name_and_level(unit, type_key)
	_apply_hp(unit)
	_status_label.text = _get_status(unit)
	_apply_stats(unit, type_key)

func _apply_name_and_level(unit: Node, type_key: String) -> void:
	_name_label.text = type_key
	
	var lvl : int = unit.get("level") if unit.get("level") != null else 0
	if lvl > 0:
		# Show level as roman numerals for flavour — clean and compact
		_level_label.text = "%s" % [_to_roman(lvl)]

func _to_roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
	return ""

func _apply_hp(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	var ratio := clampf(float(unit.hp) / float(unit.max_hp), 0.0, 1.0)
	_hp_fill.scale.x = ratio
	_hp_label.text   = "%d / %d" % [unit.hp, unit.max_hp]

func _get_status(unit: Node) -> String:
	if not is_instance_valid(unit):
		return ""
	if unit.get("_state") == null:
		return "Ready"

	var s := int(unit._state)

	if _unit_type(unit) == "Pawn":
		match s:
			0: return "Idle"
			1: return "Wandering"
			2: return "Moving"
			3:
				var rnode = unit.get("_resource_node")
				if rnode != null and is_instance_valid(rnode):
					return "Gathering %s" % rnode.resource_type.capitalize()
				return "Gathering"
			4:
				var rnode = unit.get("_resource_node")
				if rnode != null and is_instance_valid(rnode):
					return "Extracting %s" % rnode.resource_type.capitalize()
				return "Extracting"
			5:
				var carrying = unit.get("_carrying")
				if carrying != null and (carrying as String) != "":
					return "Returning %s" % (carrying as String).capitalize()
				return "Returning"
		return "Idle"

	match s:
		0: return "Idle"
		1: return "Patrolling"
		2: return "Moving"
		3: return "Engaging"
		4: return "Attacking"
	return "Ready"

func _apply_stats(unit: Node, type_key: String) -> void:
	var stats : Dictionary = UNIT_STATS.get(type_key, {})
	if type_key == "Monk":
		_attack_range_title.text  = "Cast Range"
		_attack_damage_title.text = "Heal Amount"
		_attack_speed_title.text  = "Cast Speed"
		var cast_range : float = float(stats.get("cast_range", 300.0)) + unit.get_building_range_bonus()
		_attack_range_label.text  = _format_stat_value(cast_range)
		var heal_amount : int = int(stats.get("heal_amount", 6))
		if unit.has_method("_get_heal_amount"):
			heal_amount = unit._get_heal_amount()
		_attack_damage_label.text = str(heal_amount)
		var cast_speed : float = float(stats.get("cast_speed", 2.2)) * unit.get_building_attack_speed_multiplier()
		_attack_speed_label.text  = _format_attack_speed(cast_speed)
		_move_speed_label.text    = _format_stat_value(_resolve_stat(unit, "move_speed", stats.get("move_speed")))
		return
	_attack_range_title.text  = "Attack Range"
	_attack_damage_title.text = "Attack Damage"
	_attack_speed_title.text  = "Attack Speed"
	_attack_range_label.text  = _format_stat_value(_resolve_stat(unit, "attack_range",  stats.get("attack_range")))
	_attack_damage_label.text = _format_stat_value(_resolve_stat(unit, "attack_damage", stats.get("attack_damage")))
	_attack_speed_label.text  = _format_attack_speed(_resolve_stat(unit, "attack_speed", stats.get("attack_speed")))
	_move_speed_label.text    = _format_stat_value(_resolve_stat(unit, "move_speed",    stats.get("move_speed")))

func _resolve_stat(unit: Node, stat_id: String, fallback):
	match stat_id:
		"attack_range":
			if unit.has_method("get_building_range_bonus") and fallback != null:
				return float(fallback) + unit.get_building_range_bonus()
		"attack_damage":
			if unit.has_method("get_building_attack_damage_bonus"):
				if fallback == null:
					return null
				return int(fallback) + unit.get_building_attack_damage_bonus()
		"attack_speed":
			if unit.has_method("get_building_attack_speed_multiplier") and fallback != null:
				return float(fallback) * unit.get_building_attack_speed_multiplier()
		"move_speed":
			if unit.has_method("get_building_move_speed_multiplier") and fallback != null:
				return float(fallback) * unit.get_building_move_speed_multiplier()
	return fallback

func _format_stat_value(value) -> String:
	if value == null:
		return "-"
	if value is float:
		return str(int(round(value)))
	return str(value)

func _format_attack_speed(value) -> String:
	if value == null:
		return "-"
	if value is float:
		return "%.1f s" % value
	return "%s s" % str(value)

# =========================================================================== #
#  Multi-unit view
# =========================================================================== #

func _show_multi(units: Array) -> void:
	_single_view.hide()
	_multi_view.show()

	var counts : Dictionary = {}
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var t := _unit_type(unit)
		counts[t] = counts.get(t, 0) + 1

	for child in _multi_grid.get_children():
		child.queue_free()

	for type_key in counts:
		_multi_grid.add_child(_make_chip(type_key, counts[type_key]))

	_multi_total.text = "%d units" % units.size()

func _make_chip(type_key: String, count: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(64, 64)

	var portrait := TextureRect.new()
	portrait.texture      = load(AVATARS.get(type_key, DEFAULT_AVATAR))
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(portrait)

	var badge_bg := ColorRect.new()
	badge_bg.color    = Color(0.1, 0.1, 0.1, 0.85)
	badge_bg.size     = Vector2(24, 18)
	badge_bg.position = Vector2(40, 46)
	root.add_child(badge_bg)

	var lbl := Label.new()
	lbl.text = "x%d" % count
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size     = Vector2(24, 18)
	lbl.position = Vector2(40, 46)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	root.add_child(lbl)

	return root

# =========================================================================== #
#  Per-frame poll
# =========================================================================== #

func _process(_delta: float) -> void:
	if not _single_view.visible or not is_instance_valid(_tracked_unit):
		return
	_apply_hp(_tracked_unit)
	_apply_name_and_level(_tracked_unit, _unit_type(_tracked_unit))
	_status_label.text = _get_status(_tracked_unit)

# =========================================================================== #
#  Helpers
# =========================================================================== #

func _unit_type(unit: Node) -> String:
	var script : Script = unit.get_script()
	if script:
		var base := script.resource_path.get_file().get_basename()
		return base.substr(0, 1).to_upper() + base.substr(1)
	return "Unit"
