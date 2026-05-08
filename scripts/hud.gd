extends CanvasLayer

signal build_pressed
signal building_selected(building_id: String)

@onready var build_button     : TextureButton  = $ActionBar/BuildButton
@onready var build_menu       : Control        = $BuildMenu
@onready var resource_display : Control        = $ResourceDisplay
@onready var wave_label       : Label          = $WaveTimer/WaveLabel
@onready var wave_display     : Control        = $WaveTimer
@onready var speed_controls   : HBoxContainer  = $ActionBar/SpeedControls
@onready var victory          : Label          = $WaveTimer/Victory
@onready var title            : Label          = $WaveTimer/Title

var _speed_buttons : Array[Button] = []
var _current_speed : float = 1.0

func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.closed.connect(_on_build_menu_closed)
	wave_label.text = ""
	_setup_speed_buttons()

const SPEED_MAP : Dictionary = {
	"PauseBtn":    0.0,
	"NormalBtn":   1.0,
	"FastBtn":     2.0,
	"VeryFastBtn": 5.0,
}

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
	_current_speed = speed
	Engine.time_scale = speed
	_highlight_speed(speed)

func _highlight_speed(speed: float) -> void:
	for btn : Button in _speed_buttons:
		var btn_speed : float = btn.get_meta("speed", 1.0)
		if btn_speed == speed:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
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

func update_resources(gold: int, wood: int, meat: int) -> void:
	resource_display.set_resources(gold, wood, meat)
	build_menu.set_resources(gold, wood, meat)

func set_build_button_enabled(enabled: bool) -> void:
	build_button.disabled = not enabled

# Called by main.gd from wave_manager signals
func set_wave_countdown(seconds: float) -> void:
	wave_display.visible = true
	if seconds > 0.0:
		wave_label.text = "%d s" % int(ceil(seconds))
	else:
		wave_label.text = "WAVE!"
		wave_label.modulate = Color(1.0, 0.3, 0.3)

func set_wave_active(wave_number: int) -> void:
	wave_label.text = "Fight!"
	wave_label.modulate = Color(1.0, 0.3, 0.3)

func set_wave_ended(player_won: bool) -> void:
	victory.visible = true
	wave_label.visible = false
	title.visible = false
	var original_color = wave_display.modulate
	victory.text = "Victory!" if player_won else "Defeated..."
	wave_display.modulate = Color(0.3, 1.0, 0.3) if player_won else Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(5, true, false, true).timeout
	wave_display.visible = false
	victory.visible = false
	title.visible = true
	wave_label.visible = true
	wave_display.modulate = original_color
