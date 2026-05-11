# ui_audio.gd
# Autoload singleton for UI sound effects.
# Usage: UiAudio.play()  or  UiAudio.play("click1")
extends Node

const SOUNDS : Dictionary = {
	"click1":        preload("res://assets/audio/UI/click1.ogg"),
	"select":        preload("res://assets/audio/UI/select_008.ogg"),
	"switch":        preload("res://assets/audio/UI/switch_002.ogg"),
	"toggle":        preload("res://assets/audio/UI/toggle_001.ogg"),
	"building_land": preload("res://assets/audio/general/universfield-giant-fall-impact-352446.mp3"),
	"deep_thumps":   preload("res://assets/audio/general/deep-thumps.mp3"),
}

const DEFAULT_SOUND : String = "click1"

var _player         : AudioStreamPlayer = null
var _trimmed_player : AudioStreamPlayer = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	add_child(_player)
	_trimmed_player = AudioStreamPlayer.new()
	_trimmed_player.bus = "SFX"
	_trimmed_player.volume_db = 24.0
	add_child(_trimmed_player)

func play(sound: String = DEFAULT_SOUND, from_position: float = 0.0) -> void:
	var stream : AudioStream = SOUNDS.get(sound, SOUNDS[DEFAULT_SOUND])
	_player.stream = stream
	_player.play(from_position)

func play_trimmed(sound: String, from_sec: float, to_sec: float) -> void:
	var stream : AudioStream = SOUNDS.get(sound, null)
	if stream == null:
		push_warning("UiAudio: unknown sound '%s'" % sound)
		return
	_trimmed_player.stream = stream
	_trimmed_player.play(from_sec)
	var dur : float = to_sec - from_sec
	get_tree().create_timer(dur).timeout.connect(func() -> void:
		if _trimmed_player.playing:
			_trimmed_player.stop()
	)
