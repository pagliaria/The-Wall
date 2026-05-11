# combat_audio.gd
# Autoload singleton for combat sound effects.
# Uses a small pool of AudioStreamPlayers so overlapping sounds don't cut each other off.
extends Node

const POOL_SIZE : int = 8

const SOUNDS : Dictionary = {
	"hurt":        [
		preload("res://assets/audio/combat/human/hurt_03.ogg"),
		preload("res://assets/audio/combat/human/hurt_05.ogg"),
	],
	"death":       [
		preload("res://assets/audio/combat/human/human_death.mp3"),
		preload("res://assets/audio/combat/human/human_death2.mp3"),
		preload("res://assets/audio/combat/human/human_death3.mp3"),
	],
	"arrow":       [preload("res://assets/audio/combat/whoosh_1.wav")],
	"arrow_hit":   [preload("res://assets/audio/combat/impactMetal_004.ogg")],
	"buff":        [preload("res://assets/audio/combat/spells/2 - buff.wav")],
	"male_ready":  [preload("res://assets/audio/voice/male_ready.ogg")],
	"male_go":     [preload("res://assets/audio/voice/male_go.ogg")],
	"female_ready":[preload("res://assets/audio/voice/female_human_ready.ogg")],
	"female_go":   [preload("res://assets/audio/voice/female_go.ogg")],
	"monk_ready":  [preload("res://assets/audio/voice/monk_select.mp3")],
	"monk_go":     [preload("res://assets/audio/voice/monk_go.mp3")],
	"gather":      [preload("res://assets/audio/resources/pop_2.wav")],
	"gold":        [preload("res://assets/audio/resources/coins_gather_quick.wav")],
	"wood":        [preload("res://assets/audio/resources/wood_small_gather.wav")],
	"meat":        [preload("res://assets/audio/resources/meat.wav")],
	"impact_gold": [preload("res://assets/audio/resources/qubodupImpactMetal.ogg")],
	"impact_wood": [preload("res://assets/audio/resources/qubodupImpactWood.ogg")],
	"impact_meat": [preload("res://assets/audio/resources/qubodupImpactMeat01.ogg")],
	"victory":     [preload("res://assets/audio/combat/victory.mp3")],
	"defeat":      [preload("res://assets/audio/combat/defeat.mp3")],
}

# Optional trim: { "sound_name": [from_sec, to_sec, volume_db] }  — to_sec 0 = play to end, volume_db default 0
const SOUND_TRIM : Dictionary = {
	"monk_ready": [0.4, 3.0, 6.0],
}
const EXCLUSIVE_SOUNDS   : Array[String] = ["male_ready", "male_go", "female_ready", "female_go", "monk_ready", "monk_go", "gather"]
const EXCLUSIVE_COOLDOWN : float         = 1   # seconds

var _pool        : Array[AudioStreamPlayer] = []
var _pool_index  : int        = 0
var _rng         : RandomNumberGenerator   = RandomNumberGenerator.new()
var _last_played : Dictionary = {}   # sound -> last play timestamp

func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i : int in range(POOL_SIZE):
		var p : AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

func play(sound: String) -> void:
	if sound in EXCLUSIVE_SOUNDS:
		var now  : float = Time.get_ticks_msec() / 1000.0
		var last : float = _last_played.get(sound, -999.0)
		if now - last < EXCLUSIVE_COOLDOWN:
			return
		_last_played[sound] = now

	var list : Array = SOUNDS.get(sound, [])
	if list.is_empty():
		push_warning("CombatAudio: unknown sound '%s'" % sound)
		return
	var stream : AudioStream         = list[_rng.randi() % list.size()]
	var player : AudioStreamPlayer  = _pool[_pool_index % POOL_SIZE]
	_pool_index += 1
	player.stream = stream
	var trim   : Array = SOUND_TRIM.get(sound, [])
	var from   : float = trim[0] if trim.size() >= 1 else 0.0
	var to     : float = trim[1] if trim.size() >= 2 else 0.0
	var vol_db : float = trim[2] if trim.size() >= 3 else 0.0
	var prev_vol : float = player.volume_db
	player.volume_db = vol_db
	player.play(from)
	if to > 0.0:
		var dur : float = to - from
		get_tree().create_timer(dur).timeout.connect(func() -> void:
			if player.playing:
				player.stop()
			player.volume_db = prev_vol
		)
