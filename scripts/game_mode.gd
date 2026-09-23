extends Node
# game_mode.gd — autoload "GameMode"
# Holds the run mode picked on the title screen. Survives scene changes.
# Also holds the persistent player identity used to tag defense snapshots.

enum Mode { SOLO, VERSUS }

# Matchmaking / battle state shown by the versus_status HUD panel.
# Emitted by WaveManager (versus_status_changed), consumed by versus_status.gd.
enum VersusState { NONE, SEARCHING, READY, NO_OPPONENT, ERROR, BATTLE_OPPONENT, BATTLE_PVE }

const PROFILE_PATH          : String = "user://profile.cfg"
const MAX_PLAYER_NAME_LENGTH : int   = 24

var mode        : Mode   = Mode.SOLO
var player_id   : String = ""
var player_name : String = ""

func _ready() -> void:
	_load_profile()

func set_mode(new_mode: int) -> void:
	mode = new_mode as Mode

func is_versus() -> bool:
	return mode == Mode.VERSUS

func is_solo() -> bool:
	return mode == Mode.SOLO

# =========================================================================== #
#  Player profile — random id generated once, name editable later in settings
# =========================================================================== #

func set_player_name(new_name: String) -> void:
	var cleaned : String = new_name.strip_edges().substr(0, MAX_PLAYER_NAME_LENGTH)
	if cleaned == "":
		return
	player_name = cleaned
	save_profile()

func save_profile() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("player", "id", player_id)
	cfg.set_value("player", "name", player_name)
	var err : Error = cfg.save(PROFILE_PATH)
	if err != OK:
		push_warning("GameMode: could not save profile (error %d)" % err)

func _load_profile() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	var err : Error = cfg.load(PROFILE_PATH)
	if err == OK:
		player_id   = str(cfg.get_value("player", "id", ""))
		player_name = str(cfg.get_value("player", "name", ""))
	var dirty : bool = false
	if player_id == "":
		player_id = Crypto.new().generate_random_bytes(16).hex_encode()
		dirty = true
	if player_name == "":
		player_name = "Player_" + player_id.substr(0, 4)
		dirty = true
	if dirty:
		save_profile()
