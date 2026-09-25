extends PanelContainer
# versus_status.gd — small HUD panel (top-left) for versus matchmaking state.
# Instanced in main.tscn under HUD. Hidden in solo mode: main.gd only wires
# WaveManager.versus_status_changed to set_state() when GameMode.is_versus().
#
# Dumb view: opponent state is pushed in via set_state(). The "defense saved"
# line listens to SnapshotService directly, because upload results are
# independent of the wave phase.

const COLOR_SEARCH   : Color = Color(0.95, 0.75, 0.20)
const COLOR_READY    : Color = Color(0.30, 0.72, 0.30)
const COLOR_FALLBACK : Color = Color(0.90, 0.55, 0.15)
const COLOR_ERROR    : Color = Color(0.78, 0.25, 0.20)
const COLOR_BATTLE   : Color = Color(0.85, 0.20, 0.20)

@onready var _dot    : ColorRect = $Margin/VBox/Header/StateDot
@onready var _status : Label     = $Margin/VBox/StatusLabel
@onready var _detail : Label     = $Margin/VBox/DetailLabel
@onready var _upload : Label     = $Margin/VBox/UploadLabel

func _ready() -> void:
	visible = false
	SnapshotService.snapshot_uploaded.connect(_on_snapshot_uploaded)
	SnapshotService.request_failed.connect(_on_request_failed)

# state is a GameMode.VersusState value.
func set_state(state: int, opponent_name: String = "", opponent_power: int = 0, detail: String = "") -> void:
	if state == GameMode.VersusState.NONE:
		visible = false
		return
	visible = true
	if state == GameMode.VersusState.SEARCHING:
		_upload.text = ""  # new wave: forget last wave's upload result
		_show(COLOR_SEARCH, "Finding an opponent...", "")
	elif state == GameMode.VersusState.READY:
		_show(COLOR_READY, "Next: %s" % opponent_name, "Power %d" % opponent_power)
	elif state == GameMode.VersusState.NO_OPPONENT:
		_show(COLOR_FALLBACK, "No opponent found yet", "You will face a regular wave")
	elif state == GameMode.VersusState.ERROR:
		_show(COLOR_ERROR, "Matchmaking unavailable", "%s. You will face a regular wave." % detail)
	elif state == GameMode.VersusState.BATTLE_OPPONENT:
		_show(COLOR_BATTLE, "Fighting %s" % opponent_name, "Power %d" % opponent_power)
	elif state == GameMode.VersusState.BATTLE_PVE:
		_show(COLOR_FALLBACK, "Fighting a regular wave", detail)

func _show(color: Color, status_text: String, detail_text: String) -> void:
	_dot.color         = color
	_status.text       = status_text
	_detail.text       = detail_text
	_detail.visible    = detail_text != ""

func _on_snapshot_uploaded(wave: int) -> void:
	_upload.text = "Your defense for wave %d was saved" % wave

func _on_request_failed(kind: String, reason: String) -> void:
	if kind == "upload":
		_upload.text = "Your defense was not saved: %s" % reason
