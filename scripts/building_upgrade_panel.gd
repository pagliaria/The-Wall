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
	_title_label.text = "%s Upgrades" % display_name
	_status_label.text = _tracked_building.get_upgrade_status_text() if _tracked_building.has_method("get_upgrade_status_text") else ""

	var upgrade_defs: Dictionary = _tracked_building.get_upgrade_definitions()
	var available_upgrade_ids: Array = _tracked_building.get_available_upgrade_ids()
	var selected_id: String = _tracked_building.get_active_upgrade_id() if _tracked_building.has_method("get_active_upgrade_id") else ""

	for upgrade_id in BUTTON_ORDER:
		var button: Button = _buttons[upgrade_id]
		if not available_upgrade_ids.has(upgrade_id):
			button.hide()
			continue
		button.show()
		var upgrade_def: Dictionary = upgrade_defs.get(upgrade_id, {})
		var current_level: int = _tracked_building.get_upgrade_level(upgrade_id) if _tracked_building.has_method("get_upgrade_level") else 0
		var max_level: int = int(upgrade_def.get("max_level", 0))
		var is_maxed := current_level >= max_level and max_level > 0
		var is_active : Variant = selected_id == upgrade_id

		button.text = "%s %d/%d" % [UPGRADE_LABELS[upgrade_id], current_level, max_level]
		button.tooltip_text = _build_tooltip(upgrade_def, current_level, max_level)
		button.disabled = is_maxed or is_active or not _tracked_building.can_start_upgrade(upgrade_id)

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
