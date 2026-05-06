extends CanvasLayer

signal castle_placement_requested

@onready var place_button: Button = $Panel/MarginContainer/VBox/CastleCard/VBox/PlaceButton

func _ready() -> void:
	place_button.pressed.connect(_on_place_pressed)

func _on_place_pressed() -> void:
	hide()
	emit_signal("castle_placement_requested")
