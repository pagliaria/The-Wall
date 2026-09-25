extends PanelContainer
# sudden_death_banner.gd — HUD banner (top-center) for the sudden-death timer.
# Instanced in main.tscn under HUD. Dumb view: main.gd connects
# WaveManager.sudden_death_changed to set_state().
#
# Layout, fonts, colors and the pulse animation live in the scene. Move or
# restyle it in the editor.

const COLOR_WARN   : Color = Color(0.95, 0.75, 0.20)
const COLOR_ACTIVE : Color = Color(0.92, 0.25, 0.20)

@onready var _title  : Label           = $Margin/VBox/TitleLabel
@onready var _detail : Label           = $Margin/VBox/DetailLabel
@onready var _anim   : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false

# active = damage is running. Not active + seconds_left >= 0 = warning
# countdown. seconds_left < 0 = hide (no battle, feature off, or timer not
# in warning window yet).
func set_state(active: bool, seconds_left: float) -> void:
	if not active and seconds_left < 0.0:
		_hide_banner()
		return
	visible = true
	if active:
		_title.text = "SUDDEN DEATH"
		_title.add_theme_color_override("font_color", COLOR_ACTIVE)
		_detail.text = "Everyone takes growing damage"
		if _anim.current_animation != "pulse":
			_anim.play("pulse")
	else:
		_title.text = "Sudden death in %d" % int(seconds_left)
		_title.add_theme_color_override("font_color", COLOR_WARN)
		_detail.text = "Finish the fight"
		_stop_pulse()

func _hide_banner() -> void:
	visible = false
	_stop_pulse()

func _stop_pulse() -> void:
	_anim.stop()
	modulate = Color.WHITE
