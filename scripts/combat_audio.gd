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
}

var _pool : Array[AudioStreamPlayer] = []
var _pool_index : int = 0
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i : int in range(POOL_SIZE):
		var p : AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

func play(sound: String) -> void:
	var list : Array = SOUNDS.get(sound, [])
	if list.is_empty():
		push_warning("CombatAudio: unknown sound '%s'" % sound)
		return
	print("playing '%s'" % sound)
	var stream : AudioStream = list[_rng.randi() % list.size()]
	var player : AudioStreamPlayer = _pool[_pool_index % POOL_SIZE]
	_pool_index += 1
	player.stream = stream
	player.play()
