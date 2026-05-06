extends CanvasLayer

signal build_pressed
signal building_selected(building_id: String)

@onready var build_button     : TextureButton = $ActionBar/BuildButton
@onready var build_menu       : Control       = $BuildMenu
@onready var resource_display : Control       = $ResourceDisplay
@onready var wave_label       : Label         = $WaveLabel

func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.closed.connect(_on_build_menu_closed)
	wave_label.text = ""

func _on_build_button_pressed() -> void:
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
	if seconds > 0.0:
		wave_label.text = "Wave in: %d s" % int(ceil(seconds))
	else:
		wave_label.text = "WAVE!"
		wave_label.modulate = Color(1.0, 0.3, 0.3)

func set_wave_active(wave_number: int) -> void:
	wave_label.text = "Wave %d — FIGHT!" % wave_number
	wave_label.modulate = Color(1.0, 0.3, 0.3)

func set_wave_ended(player_won: bool) -> void:
	wave_label.text = "Victory!" if player_won else "Defeated..."
	wave_label.modulate = Color(0.3, 1.0, 0.3) if player_won else Color(1.0, 0.3, 0.3)
