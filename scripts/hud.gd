extends CanvasLayer

signal build_pressed
signal building_selected(building_id: String)
signal settings_pressed
signal rush_pressed

@onready var build_button     : TextureButton  = $ActionBar/BuildButton
@onready var build_menu       : Control        = $BuildMenu
@onready var resource_display : Control        = $ResourceDisplay
@onready var wave_label       : Label          = $WaveTimer/WaveLabel
@onready var wave_display     : Control        = $WaveTimer
@onready var speed_controls   : HBoxContainer  = $ActionBar/SpeedControls
@onready var victory          : Label          = $WaveTimer/Victory
@onready var title            : Label          = $WaveTimer/Title
@onready var settings_btn     : Button         = $ActionBar/SettingsBtn
@onready var rush_button      : NinePatchRect = $WaveTimer/RushButton

var _speed_buttons : Array[Button] = []
var _current_speed : float = 1.0

func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.closed.connect(_on_build_menu_closed)
	settings_btn.pressed.connect(_on_settings_pressed)
	rush_button.gui_input.connect(_on_rush_gui_input)
	rush_button.visible = false
	wave_label.text = ""
	_setup_speed_buttons()

const SPEED_MAP : Dictionary = {
	"PauseBtn":    0.0,
	"NormalBtn":   1.0,
	"FastBtn":     2.0,
	"VeryFastBtn": 5.0,
}

# Keys 0-3 → speeds
const KEY_SPEED_MAP : Dictionary = {
	KEY_0: 0.0,
	KEY_1: 1.0,
	KEY_2: 2.0,
	KEY_3: 5.0,
}

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_B:
		_on_build_button_pressed()
		return
	if KEY_SPEED_MAP.has(event.keycode):
		_set_speed(KEY_SPEED_MAP[event.keycode])

func _setup_speed_buttons() -> void:
	for child in speed_controls.get_children():
		if child is Button and SPEED_MAP.has(child.name):
			_speed_buttons.append(child as Button)
			(child as Button).pressed.connect(_on_speed_button_pressed.bind(child))
	_highlight_speed(1.0)

func _on_speed_button_pressed(btn: Button) -> void:
	var speed : float = SPEED_MAP.get(btn.name, 1.0)
	UiAudio.play()
	_set_speed(speed)

func _set_speed(speed: float) -> void:
	_current_speed    = speed
	Engine.time_scale = speed
	_highlight_speed(speed)

func _highlight_speed(speed: float) -> void:
	for btn : Button in _speed_buttons:
		var btn_speed : float = SPEED_MAP.get(btn.name, 1.0)
		if btn_speed == speed:
			btn.add_theme_color_override("font_color",       Color(1.0, 0.85, 0.2))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.2))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")

func _on_build_button_pressed() -> void:
	UiAudio.play()
	if build_menu.visible:
		build_menu.hide()
	else:
		build_menu.open()
	emit_signal("build_pressed")

func _on_building_selected(building_id: String) -> void:
	emit_signal("building_selected", building_id)

func _on_build_menu_closed() -> void:
	pass

const _RUSH_TEX_NORMAL  : Texture2D = preload("res://assets/UI Elements/UI Elements/Buttons/BigBlueButton_Regular_together.png")
const _RUSH_TEX_PRESSED : Texture2D = preload("res://assets/UI Elements/UI Elements/Buttons/BigBlueButton_Pressed_together.png")

func _on_rush_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			rush_button.texture = _RUSH_TEX_PRESSED
		else:
			rush_button.texture = _RUSH_TEX_NORMAL
			UiAudio.play()
			emit_signal("rush_pressed")

func _on_settings_pressed() -> void:
	UiAudio.play()
	emit_signal("settings_pressed")

func update_resources(gold: int, wood: int, meat: int) -> void:
	resource_display.set_resources(gold, wood, meat)
	build_menu.set_resources(gold, wood, meat)

func set_build_button_enabled(enabled: bool) -> void:
	build_button.disabled = not enabled

func set_wave_countdown(seconds: float) -> void:
	wave_display.visible = true
	if seconds > 0.0:
		wave_label.text = "%d s" % int(ceil(seconds))
	else:
		wave_label.text     = "WAVE!"
		wave_label.modulate = Color(1.0, 0.3, 0.3)

const _ICON_GOLD : String = "res://assets/UI Elements/UI Elements/Icons/Icon_03.png"
const _ICON_WOOD : String = "res://assets/UI Elements/UI Elements/Icons/Icon_02.png"
const _ICON_MEAT : String = "res://assets/UI Elements/UI Elements/Icons/Icon_04.png"

func update_rush_button(reward: Dictionary) -> void:
	if not rush_button.visible:
		return
	var lbl : RichTextLabel = rush_button.get_node_or_null("Label")
	if lbl == null:
		return
	var gold : int = reward.get("gold", 0)
	var text : String = "[center]⚔ Rush!  [img=14x14]%s[/img] +%d" % [_ICON_GOLD, gold * 10]
	if reward.has("wood"):
		text += "  [img=14x14]%s[/img] +%d" % [_ICON_WOOD, reward["wood"] * 10]
	if reward.has("meat"):
		text += "  [img=14x14]%s[/img] +%d" % [_ICON_MEAT, reward["meat"]]
	text += "[/center]"
	lbl.text = text

func show_rush_button() -> void:
	rush_button.visible = true

func hide_rush_button() -> void:
	rush_button.visible = false

func is_rush_button_visible() -> bool:
	return rush_button.visible

func set_wave_active(_wave_number: int) -> void:
	wave_label.text     = "Fight!"
	wave_label.modulate = Color(1.0, 0.3, 0.3)

func set_wave_ended(player_won: bool) -> void:
	victory.visible    = true
	wave_label.visible = false
	title.visible      = false
	var original_color := wave_display.modulate
	victory.text           = "Victory!" if player_won else "Defeated..."
	wave_display.modulate  = Color(0.3, 1.0, 0.3) if player_won else Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(5, true, false, true).timeout
	wave_display.visible   = false
	victory.visible        = false
	title.visible          = true
	wave_label.visible     = true
	wave_display.modulate  = original_color
