extends CanvasLayer

# game_over.gd
# Shown when the player loses a wave. Overlays the game with a dark panel,
# "DEFEATED" title, and Restart / Main Menu / Exit buttons.

@onready var _restart_btn : Button = $Panel/VBox/MarginContainer/VBoxInner/Buttons/RestartBtn
@onready var _menu_btn    : Button = $Panel/VBox/MarginContainer/VBoxInner/Buttons/MenuBtn
@onready var _exit_btn    : Button = $Panel/VBox/MarginContainer/VBoxInner/Buttons/ExitBtn

func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart)
	_menu_btn.pressed.connect(_on_menu)
	_exit_btn.pressed.connect(_on_exit)

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_menu() -> void:
	# Main menu not yet built — placeholder reloads game
	get_tree().reload_current_scene()

func _on_exit() -> void:
	get_tree().quit()
