extends CanvasLayer
# how_to_play.gd
# Shown from the title screen. Scrollable guide covering core mechanics.

@onready var _close_btn : Button        = $Panel/VBox/Header/CloseBtn
@onready var _scroll    : ScrollContainer = $Panel/VBox/Scroll

signal closed

func _ready() -> void:
	_close_btn.pressed.connect(_on_close)

func open() -> void:
	visible = true

func _on_close() -> void:
	visible = false
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
