extends CanvasLayer

# HUD — bottom action bar
# Emits signals that main.gd (or any other system) can connect to.

signal build_pressed

@onready var build_button : TextureButton = $ActionBar/BuildButton

func _ready() -> void:
	build_button.pressed.connect(_on_build_button_pressed)

func _on_build_button_pressed() -> void:
	emit_signal("build_pressed")
