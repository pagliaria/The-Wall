# settings_screen.gd
# Full pause/settings overlay. Opened via ESC or settings button.
# Pauses the game while open (saves/restores previous time_scale).
# Persists settings to a config file so they survive restarts.
extends CanvasLayer

signal closed
signal resume_requested
signal display_changed

const CONFIG_PATH : String = "user://settings.cfg"

# =========================================================================== #
#  Settings state
# =========================================================================== #

var _prev_time_scale : float = 1.0

# Audio
var _vol_master : float = 1.0
var _vol_music  : float = 1.0
var _vol_sfx    : float = 1.0

# Display
var _fullscreen : bool = false
var _vsync      : bool = true

# Gameplay
var _wave_interval    : float = 180.0   # seconds between waves
var _start_gold       : int   = 100
var _start_wood       : int   = 50
var _start_meat       : int   = 10

# =========================================================================== #
#  Node refs
# =========================================================================== #

@onready var _panel               : Panel        = $Panel
@onready var _tab_bar             : TabContainer = $Panel/MarginContainer/VBox/TabContainer

# Audio tab
@onready var _slider_master       : HSlider = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/SliderMaster
@onready var _slider_music        : HSlider = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/SliderMusic
@onready var _slider_sfx          : HSlider = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/SliderSfx
@onready var _label_master        : Label   = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/LabelMasterVal
@onready var _label_music         : Label   = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/LabelMusicVal
@onready var _label_sfx           : Label   = $Panel/MarginContainer/VBox/TabContainer/Audio/MarginAudio/Grid/LabelSfxVal

# Display tab
@onready var _check_fullscreen    : CheckButton = $Panel/MarginContainer/VBox/TabContainer/Display/MarginDisplay/Grid/CheckFullscreen
@onready var _check_vsync         : CheckButton = $Panel/MarginContainer/VBox/TabContainer/Display/MarginDisplay/Grid/CheckVsync

# Gameplay tab
@onready var _spin_wave_interval  : SpinBox = $Panel/MarginContainer/VBox/TabContainer/Gameplay/MarginGameplay/Grid/SpinWaveInterval
@onready var _spin_start_gold     : SpinBox = $Panel/MarginContainer/VBox/TabContainer/Gameplay/MarginGameplay/Grid/SpinStartGold
@onready var _spin_start_wood     : SpinBox = $Panel/MarginContainer/VBox/TabContainer/Gameplay/MarginGameplay/Grid/SpinStartWood
@onready var _spin_start_meat     : SpinBox = $Panel/MarginContainer/VBox/TabContainer/Gameplay/MarginGameplay/Grid/SpinStartMeat

# Buttons
@onready var _btn_resume          : Button = $Panel/MarginContainer/VBox/Buttons/BtnResume
@onready var _btn_apply           : Button = $Panel/MarginContainer/VBox/Buttons/BtnApply
@onready var _btn_defaults        : Button = $Panel/MarginContainer/VBox/Buttons/BtnDefaults

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_populate_controls()
	_connect_signals()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume()
		else:
			open()

# =========================================================================== #
#  Open / close
# =========================================================================== #

func open() -> void:
	_prev_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	_populate_controls()
	visible = true

func _on_resume() -> void:
	Engine.time_scale = _prev_time_scale
	visible = false
	emit_signal("closed")

# =========================================================================== #
#  Controls → settings
# =========================================================================== #

func _connect_signals() -> void:
	_btn_resume.pressed.connect(_on_resume)
	_btn_apply.pressed.connect(_on_apply)
	_btn_defaults.pressed.connect(_on_defaults)

	_slider_master.value_changed.connect(_on_master_changed)
	_slider_music.value_changed.connect(_on_music_changed)
	_slider_sfx.value_changed.connect(_on_sfx_changed)

	_check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_check_vsync.toggled.connect(_on_vsync_toggled)

func _on_master_changed(value: float) -> void:
	_vol_master = value
	_label_master.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_changed(value: float) -> void:
	_vol_music = value
	_label_music.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))

func _on_sfx_changed(value: float) -> void:
	_vol_sfx = value
	_label_sfx.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	_fullscreen = pressed
	var mode : DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	await get_tree().process_frame
	emit_signal("display_changed")

func _on_vsync_toggled(pressed: bool) -> void:
	_vsync = pressed
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)

func _on_apply() -> void:
	# Gameplay — update live values
	_wave_interval = _spin_wave_interval.value
	_start_gold    = int(_spin_start_gold.value)
	_start_wood    = int(_spin_start_wood.value)
	_start_meat    = int(_spin_start_meat.value)

	# Apply starting resources to ResourceManager if not yet spent
	# (only meaningful before the first wave — we just update the stored values)
	_save_config()
	UiAudio.play()

func _on_defaults() -> void:
	_vol_master       = 1.0
	_vol_music        = 1.0
	_vol_sfx          = 1.0
	_fullscreen       = false
	_vsync            = true
	_wave_interval    = 180.0
	_start_gold       = 100
	_start_wood       = 50
	_start_meat       = 10
	_apply_audio()
	_populate_controls()
	_save_config()
	UiAudio.play()

# =========================================================================== #
#  Populate controls from current settings
# =========================================================================== #

func _populate_controls() -> void:
	# Audio
	_slider_master.value = _vol_master
	_slider_music.value  = _vol_music
	_slider_sfx.value    = _vol_sfx
	_label_master.text   = "%d%%" % int(_vol_master * 100)
	_label_music.text    = "%d%%" % int(_vol_music  * 100)
	_label_sfx.text      = "%d%%" % int(_vol_sfx    * 100)

	# Display
	_check_fullscreen.button_pressed = _fullscreen
	_check_vsync.button_pressed      = _vsync

	# Gameplay
	_spin_wave_interval.value = _wave_interval
	_spin_start_gold.value    = _start_gold
	_spin_start_wood.value    = _start_wood
	_spin_start_meat.value    = _start_meat

func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_vol_master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),  linear_to_db(_vol_music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),    linear_to_db(_vol_sfx))

# =========================================================================== #
#  Config persistence
# =========================================================================== #

func _save_config() -> void:
	var cfg : ConfigFile = ConfigFile.new()

	cfg.set_value("audio",    "master",        _vol_master)
	cfg.set_value("audio",    "music",         _vol_music)
	cfg.set_value("audio",    "sfx",           _vol_sfx)

	cfg.set_value("display",  "fullscreen",    _fullscreen)
	cfg.set_value("display",  "vsync",         _vsync)

	cfg.set_value("gameplay", "wave_interval", _wave_interval)
	cfg.set_value("gameplay", "start_gold",    _start_gold)
	cfg.set_value("gameplay", "start_wood",    _start_wood)
	cfg.set_value("gameplay", "start_meat",    _start_meat)

	cfg.save(CONFIG_PATH)

func _load_config() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return   # no saved config — use defaults

	_vol_master    = cfg.get_value("audio",    "master",        1.0)
	_vol_music     = cfg.get_value("audio",    "music",         1.0)
	_vol_sfx       = cfg.get_value("audio",    "sfx",           1.0)

	_fullscreen    = cfg.get_value("display",  "fullscreen",    false)
	_vsync         = cfg.get_value("display",  "vsync",         true)

	_wave_interval = cfg.get_value("gameplay", "wave_interval", 180.0)
	_start_gold    = cfg.get_value("gameplay", "start_gold",    100)
	_start_wood    = cfg.get_value("gameplay", "start_wood",    50)
	_start_meat    = cfg.get_value("gameplay", "start_meat",    10)

	_apply_audio()
	_apply_display()

func _apply_display() -> void:
	var mode : DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	emit_signal("display_changed")

# =========================================================================== #
#  Public getters for main.gd to read gameplay settings
# =========================================================================== #

func get_wave_interval() -> float:
	return _wave_interval

func get_start_resources() -> Dictionary:
	return { "gold": _start_gold, "wood": _start_wood, "meat": _start_meat }
