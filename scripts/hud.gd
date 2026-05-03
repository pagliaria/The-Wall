extends CanvasLayer

# HUD — bottom action bar + build menu
# Emits signals that main.gd (or any other system) can connect to.

signal build_pressed
signal building_selected(building_id: String)

@onready var build_button : TextureButton = $ActionBar/BuildButton
@onready var build_menu   : Control       = $BuildMenu

func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)
	build_menu.building_selected.connect(_on_building_selected)
	build_menu.closed.connect(_on_build_menu_closed)

func _on_build_button_pressed() -> void:
	if build_menu.visible:
		build_menu.hide()
	else:
		build_menu.open()
	emit_signal("build_pressed")

func _on_building_selected(building_id: String) -> void:
	emit_signal("building_selected", building_id)

func _on_build_menu_closed() -> void:
	pass  # hook here if HUD needs to react to close (e.g. depress button)
