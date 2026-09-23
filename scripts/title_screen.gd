extends Node

# title_screen.gd

@onready var _start_btn       : NinePatchRect = $BG/ButtonRow/StartBtn
@onready var _continue_btn    : NinePatchRect = $BG/ButtonRow/ContinueBtn
@onready var _options_btn     : NinePatchRect = $BG/ButtonRow/OptionsBtn
@onready var _credits_btn     : NinePatchRect = $BG/ButtonRow/CreditsBtn
@onready var _exit_btn        : NinePatchRect = $BG/ButtonRow/ExitBtn
@onready var _settings_screen : Node          = $SettingsScreen
@onready var _how_to_play     : Node          = $HowToPlay
@onready var _mode_select     : Node          = $ModeSelect
@onready var _title_music     : AudioStreamPlayer = $TitleMusic

func _ready() -> void:
	_start_title_music()
	_start_btn.gui_input.connect(_on_btn_input.bind("start"))
	_continue_btn.gui_input.connect(_on_btn_input.bind("continue"))
	_options_btn.gui_input.connect(_on_btn_input.bind("options"))
	_credits_btn.gui_input.connect(_on_btn_input.bind("howtoplay"))
	_exit_btn.gui_input.connect(_on_btn_input.bind("exit"))
	# Relabel Resume -> Close on title screen
	var resume_btn : Button = _settings_screen.get_node_or_null("Panel/MarginContainer/VBox/Buttons/BtnResume")
	if resume_btn != null:
		resume_btn.text = "Close"
	# Title screen has its own Exit button, so the in-game Quit is redundant here.
	var quit_btn : Button = _settings_screen.get_node_or_null("Panel/MarginContainer/VBox/Buttons/BtnQuit")
	if quit_btn != null:
		quit_btn.visible = false
	_settings_screen.closed.connect(func() -> void: _settings_screen.visible = false)
	_how_to_play.closed.connect(func() -> void: _how_to_play.visible = false)
	_mode_select.mode_chosen.connect(_on_mode_chosen)
	_update_continue_visibility()

# Track is picked on the TitleMusic node in the inspector. Imports ship with
# loop off, so loop is turned on here (same trick MusicManager uses).
func _start_title_music() -> void:
	# Returning from a run: make sure no in-game track is still fading out.
	MusicManager.stop()
	var stream : AudioStream = _title_music.stream
	if stream == null:
		push_warning("TitleScreen: TitleMusic has no stream assigned.")
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_title_music.play()

func _update_continue_visibility() -> void:
	var has_save : bool = FileAccess.file_exists("user://savegame.dat")
	_continue_btn.modulate.a   = 1.0 if has_save else 0.45
	_continue_btn.mouse_filter = Control.MOUSE_FILTER_STOP if has_save else Control.MOUSE_FILTER_IGNORE

func _on_btn_input(event: InputEvent, btn_id: String) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		UiAudio.play()
		match btn_id:
			"start":      _on_start()
			"continue":   _on_continue()
			"options":    _on_options()
			"howtoplay":  _how_to_play.open()
			"exit":       get_tree().quit()

func _on_start() -> void:
	_mode_select.open()

func _on_mode_chosen(chosen_mode: int) -> void:
	GameMode.set_mode(chosen_mode)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_continue() -> void:
	# Saves are solo only for now.
	GameMode.set_mode(GameMode.Mode.SOLO)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_options() -> void:
	_settings_screen.open()
