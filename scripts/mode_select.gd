extends CanvasLayer
# mode_select.gd
# Solo / Versus picker. Instanced by title_screen.tscn, opened by Start button.

signal mode_chosen(mode: int)
signal closed

@onready var _solo_btn   : NinePatchRect = $Panel/Margin/VBox/Options/SoloOption/SoloBtn
@onready var _versus_btn : NinePatchRect = $Panel/Margin/VBox/Options/VersusOption/VersusBtn
@onready var _close_btn  : Button        = $Panel/Margin/VBox/Header/CloseBtn

func _ready() -> void:
	_solo_btn.gui_input.connect(_on_option_input.bind(GameMode.Mode.SOLO))
	_versus_btn.gui_input.connect(_on_option_input.bind(GameMode.Mode.VERSUS))
	_close_btn.pressed.connect(_on_close)

func open() -> void:
	visible = true

func _on_option_input(event: InputEvent, chosen_mode: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		UiAudio.play()
		visible = false
		mode_chosen.emit(chosen_mode)

func _on_close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
