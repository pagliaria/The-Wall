# music_manager.gd
# Autoload singleton. Manages background music with crossfading between tracks.
#
# Usage:
#   MusicManager.play_chill()    # game start / post-battle
#   MusicManager.play_warning()  # wave countdown
#   MusicManager.play_battle()   # wave active
#
# Crossfade duration is set by FADE_TIME.
extends Node

# =========================================================================== #
#  Config
# =========================================================================== #

const FADE_TIME   : float = 2.0    # seconds to crossfade between tracks
const MUSIC_VOLUME_DB : float = 0.0

const CHILL_TRACKS : Array[String] = [
	"res://assets/audio/music/chill/Ludum Dare 38 01.ogg",
	"res://assets/audio/music/chill/Ludum Dare 38 06.ogg",
	"res://assets/audio/music/chill/Patreon Challenge 06.ogg",
]
const WARNING_TRACKS : Array[String] = [
	"res://assets/audio/music/warning/Ludum Dare 30 03.ogg",
	"res://assets/audio/music/warning/Ludum Dare 30 08.ogg",
	"res://assets/audio/music/warning/Ludum Dare 38 02.ogg",
]
const BATTLE_TRACKS : Array[String] = [
	"res://assets/audio/music/battle/Ludum Dare 38 04.ogg",
]

# =========================================================================== #
#  State
# =========================================================================== #

enum Zone { NONE, CHILL, WARNING, BATTLE }

var current_zone : Zone                  = Zone.NONE
var _player_a    : AudioStreamPlayer     = null
var _player_b    : AudioStreamPlayer     = null
var _active      : AudioStreamPlayer     = null
var _tween       : Tween                 = null
var _rng         : RandomNumberGenerator = RandomNumberGenerator.new()
var _last_track  : String                = ""

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running when time_scale = 0

	_player_a = _make_player("MusicA")
	_player_b = _make_player("MusicB")
	_active   = _player_a

func _make_player(node_name: String) -> AudioStreamPlayer:
	var p : AudioStreamPlayer = AudioStreamPlayer.new()
	p.name       = node_name
	p.bus        = "Music"
	p.volume_db  = -80.0
	add_child(p)
	return p

# =========================================================================== #
#  Public API
# =========================================================================== #

func play_chill() -> void:
	current_zone = Zone.CHILL
	_crossfade_to(_pick_track(CHILL_TRACKS))

func play_warning() -> void:
	current_zone = Zone.WARNING
	_crossfade_to(_pick_track(WARNING_TRACKS))

func play_battle() -> void:
	current_zone = Zone.BATTLE
	_crossfade_to(_pick_track(BATTLE_TRACKS))

func stop() -> void:
	current_zone = Zone.NONE
	_cancel_tween()
	_tween = create_tween()
	_tween.tween_property(_player_a, "volume_db", -80.0, FADE_TIME)
	_tween.parallel().tween_property(_player_b, "volume_db", -80.0, FADE_TIME)

# =========================================================================== #
#  Internals
# =========================================================================== #

func _pick_track(tracks: Array[String]) -> String:
	if tracks.size() == 1:
		return tracks[0]
	var pool : Array[String] = tracks.filter(func(t: String) -> bool: return t != _last_track)
	return pool[_rng.randi() % pool.size()]

func _crossfade_to(path: String) -> void:
	_last_track = path

	# Determine which player becomes the new active one
	var incoming : AudioStreamPlayer = _player_b if _active == _player_a else _player_a
	var outgoing : AudioStreamPlayer = _active

	# Load and configure the stream — set loop at runtime since imports have loop=false
	var stream : AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
	if stream == null:
		push_error("MusicManager: failed to load " + path)
		return
	stream.loop = true
	incoming.stream    = stream
	incoming.volume_db = -80.0
	incoming.play()

	_active = incoming

	# Crossfade: fade out the old, fade in the new
	_cancel_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(incoming, "volume_db", MUSIC_VOLUME_DB, FADE_TIME)
	_tween.tween_property(outgoing, "volume_db", -80.0, FADE_TIME)
	# Stop the outgoing player once it's silent so it doesn't waste memory looping silently
	_tween.chain().tween_callback(func() -> void:
		if outgoing.volume_db <= -79.0:
			outgoing.stop()
	)

func _cancel_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
