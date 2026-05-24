extends CanvasLayer

const BUTTON_ORDER := [
	"attack_damage",
	"attack_speed",
	"move_speed",
	"hp",
	"unit_cap",
	"production_speed",
	"range",
	"gather_speed",
	"turn_in_bonus",
]

const UPGRADE_LABELS := {
	"attack_damage": "DMG",
	"attack_speed": "AS",
	"move_speed": "MS",
	"hp": "HP",
	"unit_cap": "CAP",
	"production_speed": "SPD",
	"range": "RNG",
	"gather_speed": "GTH",
	"turn_in_bonus": "BONUS",
}

@onready var _panel: NinePatchRect = $Panel
@onready var _title_label: Label = $Panel/Margin/VBox/Header/Title
@onready var _status_label: Label = $Panel/Margin/VBox/Header/Status
@onready var _buttons := {
	"attack_damage": $Panel/Margin/VBox/Grid/AttackDamageButton,
	"attack_speed": $Panel/Margin/VBox/Grid/AttackSpeedButton,
	"move_speed": $Panel/Margin/VBox/Grid/MoveSpeedButton,
	"hp": $Panel/Margin/VBox/Grid/HpButton,
	"unit_cap": $Panel/Margin/VBox/Grid/UnitCapButton,
	"production_speed": $Panel/Margin/VBox/Grid/ProductionSpeedButton,
	"range": $Panel/Margin/VBox/Grid/RangeButton,
	"gather_speed": $Panel/Margin/VBox/Grid/GatherSpeedButton,
	"turn_in_bonus": $Panel/Margin/VBox/Grid/TurnInBonusButton,
}

var _tracked_building: Node = null

func _ready() -> void:
	hide_panel()
	for upgrade_id in BUTTON_ORDER:
		var button: Button = _buttons[upgrade_id]
		button.text = UPGRADE_LABELS[upgrade_id]
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))

func show_building(building: Node) -> void:
	_tracked_building = building
	_panel.show()
	_refresh()

func hide_panel() -> void:
	_tracked_building = null
	_panel.hide()

func is_showing_building(building: Node) -> bool:
	return _tracked_building == building and _panel.visible

func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if not is_instance_valid(_tracked_building):
		hide_panel()
		return
	_refresh()

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if not is_instance_valid(_tracked_building):
		hide_panel()
		return
	if _tracked_building.has_method("try_start_upgrade"):
		_tracked_building.try_start_upgrade(upgrade_id)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_tracked_building):
		hide_panel()
		return
	if not _tracked_building.has_method("supports_upgrades") or not _tracked_building.supports_upgrades():
		hide_panel()
		return

	var display_name : String = _tracked_building.get_display_name() if _tracked_building.has_method("get_display_name") else "Building"
	_title_label.text  = "%s" % display_name
	_status_label.text = _tracked_building.get_upgrade_status_text() if _tracked_building.has_method("get_upgrade_status_text") else ""

	# House — show hire UI instead of upgrade buttons
	if _tracked_building.building_id == "house1":
		_show_hire_ui()
		return

	_hide_hire_ui()
	var upgrade_defs         : Dictionary = _tracked_building.get_upgrade_definitions()
	var available_upgrade_ids : Array     = _tracked_building.get_available_upgrade_ids()
	var selected_id          : String     = _tracked_building.get_active_upgrade_id() if _tracked_building.has_method("get_active_upgrade_id") else ""

	for upgrade_id in BUTTON_ORDER:
		var button : Button = _buttons[upgrade_id]
		if not available_upgrade_ids.has(upgrade_id):
			button.hide()
			continue
		button.show()
		var upgrade_def   : Dictionary = upgrade_defs.get(upgrade_id, {})
		var current_level : int        = _tracked_building.get_upgrade_level(upgrade_id) if _tracked_building.has_method("get_upgrade_level") else 0
		var max_level     : int        = int(upgrade_def.get("max_level", 0))
		var is_maxed      := current_level >= max_level and max_level > 0
		var is_active     : Variant    = selected_id == upgrade_id
		button.text         = "%s %d/%d" % [UPGRADE_LABELS[upgrade_id], current_level, max_level]
		button.tooltip_text = _build_tooltip(upgrade_def, current_level, max_level)
		button.disabled     = is_maxed or is_active or not _tracked_building.can_start_upgrade(upgrade_id)

var _hire_buttons : Array = []

func _show_hire_ui() -> void:
	for btn : Button in _buttons.values():
		btn.hide()
	var ctrl : Node = _tracked_building.get_controller()
	if ctrl == null or not ctrl.has_method("get_hire_roster"):
		return
	var roster : Array = ctrl.get_hire_roster()
	var grid : GridContainer = $Panel/Margin/VBox/Grid
	grid.columns = 4
	# Widen panel for hire cards
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.offset_top = -420.0
	if _hire_buttons.size() != roster.size():
		for b in _hire_buttons:
			if is_instance_valid(b):
				b.queue_free()
		_hire_buttons.clear()
		for entry in roster:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(110, 148)
			btn.clip_contents = false
			grid.add_child(btn)
			btn.pressed.connect(_on_hire_pressed.bind(entry))
			_hire_buttons.append(btn)
			var vbox := VBoxContainer.new()
			vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 4)
			btn.add_child(vbox)
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon_path : String = entry.get("icon", "")
			if icon_path != "":
				var full_tex : Texture2D = load(icon_path)
				if full_tex != null:
					var atlas   := AtlasTexture.new()
					atlas.atlas  = full_tex
					var frame_rect : Rect2 = entry.get("icon_frame", Rect2(0, 0, 0, 0))
					if frame_rect.size.x > 0.0 and frame_rect.size.y > 0.0:
						atlas.region = frame_rect
					else:
						var frame_h : int = full_tex.get_height()
						atlas.region = Rect2(0, 0, frame_h, frame_h)
					tex_rect.texture = atlas
				tex_rect.set_meta("icon_path", icon_path)
			vbox.add_child(tex_rect)
			var name_lbl := Label.new()
			name_lbl.text = entry["label"]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(name_lbl)
			var cost_lbl := Label.new()
			cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_lbl.add_theme_font_size_override("font_size", 11)
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
			cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(cost_lbl)
			var count_lbl := Label.new()
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.add_theme_font_size_override("font_size", 11)
			count_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(count_lbl)
			btn.set_meta("cost_label", cost_lbl)
			btn.set_meta("count_label", count_lbl)
			btn.set_meta("name_label", name_lbl)
	# Refresh state
	for i in roster.size():
		if i >= _hire_buttons.size():
			break
		var entry  : Dictionary = roster[i]
		var btn    : Button     = _hire_buttons[i]
		var hired  : int        = ctrl.get_hired_count(entry["id"])
		var max_c  : int        = int(entry["max"])
		var cost   : Dictionary = entry["cost"]
		var cost_lbl  : Label = btn.get_meta("cost_label")  if btn.has_meta("cost_label")  else null
		var count_lbl : Label = btn.get_meta("count_label") if btn.has_meta("count_label") else null
		var name_lbl  : Label = btn.get_meta("name_label")  if btn.has_meta("name_label")  else null
		if cost_lbl != null:
			cost_lbl.text = _format_hire_cost(cost)
		if count_lbl != null:
			count_lbl.text = "%d / %d" % [hired, max_c]
		if name_lbl != null:
			name_lbl.text = entry["label"]
		btn.disabled = not ctrl.can_hire(entry)
		btn.show()

func _hide_hire_ui() -> void:
	($Panel/Margin/VBox/Grid as GridContainer).columns = 2
	_panel.custom_minimum_size = Vector2(0, 0)
	_panel.offset_top = -360.0
	for b in _hire_buttons:
		if is_instance_valid(b):
			b.hide()

func _on_hire_pressed(entry: Dictionary) -> void:
	if not is_instance_valid(_tracked_building):
		return
	var ctrl : Node = _tracked_building.get_controller()
	if ctrl != null and ctrl.has_method("try_hire"):
		ctrl.try_hire(entry)
	_refresh()

func _build_tooltip(upgrade_def: Dictionary, current_level: int, max_level: int) -> String:
	var description: String = upgrade_def.get("description", "")
	if current_level >= max_level:
		return "%s\nMaxed" % description

	var next_level: int = current_level + 1
	var levels: Array = upgrade_def.get("levels", [])
	if current_level < 0 or current_level >= levels.size():
		return description

	var next_data: Dictionary = levels[current_level]
	var cost: Dictionary = next_data.get("cost", {})
	var time_seconds: float = float(next_data.get("time", 0.0))

	return "%s\nLevel %d\nCost: %s\nTime: %s" % [
		description,
		next_level,
		_format_cost(cost),
		_format_time(time_seconds),
	]

func _format_hire_cost(cost: Dictionary) -> String:
	var parts : Array[String] = []
	var gold  : int = int(cost.get("gold", 0)) * 10
	var meat  : int = int(cost.get("meat", 0))
	var wood  : int = int(cost.get("wood", 0))
	if gold > 0: parts.append("%d gold" % gold)
	if wood > 0: parts.append("%d wood" % wood)
	if meat > 0: parts.append("%d meat" % meat)
	if parts.is_empty(): return "Free"
	return ", ".join(parts)

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var gold: int = int(cost.get("gold", 0))
	var wood: int = int(cost.get("wood", 0))
	var meat: int = int(cost.get("meat", 0))
	if gold > 0:
		parts.append("%d gold" % gold)
	if wood > 0:
		parts.append("%d wood" % wood)
	if meat > 0:
		parts.append("%d meat" % meat)
	if parts.is_empty():
		return "Free"
	return ", ".join(parts)

func _format_time(time_seconds: float) -> String:
	return "%.0f s" % time_seconds
