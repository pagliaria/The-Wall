extends Node
# snapshot_service.gd — autoload SCENE "SnapshotService" (scenes/snapshot_service.tscn)
# Talks to Supabase (PostgREST): uploads this player's defense snapshot and
# fetches an opponent's through the get_opponent_snapshot RPC.
# Schema + security rules live in supabase/schema.sql.
#
# Never blocks gameplay: every call is async and reports back by signal.
# Callers must always have a fallback (wave_manager falls back to the PvE wave).
#
# The three HTTPRequest nodes and their request_completed connections are set
# up in the scene, so you can see and tweak them (timeout etc.) in the editor.

signal opponent_fetched(wave: int, snapshot: Dictionary)  # empty dict = none available
signal snapshot_uploaded(wave: int)
signal request_failed(kind: String, reason: String)       # kind: "fetch" | "upload"
signal connection_tested(ok: bool, message: String)

const CONFIG_PATH : String = "user://versus.cfg"
const TABLE_PATH  : String = "defense_snapshots"
const RPC_PATH    : String = "rpc/get_opponent_snapshot"

var server_url       : String = ""
var server_key       : String = ""
var allow_self_match : bool   = false  # testing: let fetch return your own snapshots

var _fetch_wave  : int = 0
var _upload_wave : int = 0

@onready var _upload_request : HTTPRequest = $UploadRequest
@onready var _fetch_request  : HTTPRequest = $FetchRequest
@onready var _test_request   : HTTPRequest = $TestRequest

func _ready() -> void:
	_load_config()

# =========================================================================== #
#  Config
# =========================================================================== #

func is_configured() -> bool:
	return get_config_error() == ""

# "" when usable, otherwise a short human-readable reason.
func get_config_error() -> String:
	if server_url == "" or server_key == "":
		return "Server URL and key not set"
	var scheme_ok : bool = server_url.begins_with("https://") \
		or server_url.begins_with("http://localhost") \
		or server_url.begins_with("http://127.0.0.1")
	if not scheme_ok:
		return "Server URL must start with https://"
	return ""

func set_config(url: String, key: String, self_match: bool) -> void:
	server_url       = url.strip_edges()
	server_key       = key.strip_edges()
	allow_self_match = self_match
	_save_config()

func _save_config() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("server", "url", server_url)
	cfg.set_value("server", "key", server_key)
	cfg.set_value("server", "allow_self_match", allow_self_match)
	var err : Error = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("SnapshotService: could not save config (error %d)" % err)

func _load_config() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	server_url       = str(cfg.get_value("server", "url", ""))
	server_key       = str(cfg.get_value("server", "key", ""))
	allow_self_match = bool(cfg.get_value("server", "allow_self_match", false))

# =========================================================================== #
#  Request helpers
# =========================================================================== #

func _rest_url(path: String) -> String:
	return server_url.rstrip("/") + "/rest/v1/" + path

# Supabase publishable keys go on the apikey header ONLY. Also sending them as
# "Authorization: Bearer" makes the gateway reject the request as an invalid JWT.
func _build_headers(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var headers : PackedStringArray = PackedStringArray([
		"apikey: " + server_key,
		"Content-Type: application/json",
	])
	headers.append_array(extra)
	return headers

func _http_error_text(code: int, body: PackedByteArray) -> String:
	return "HTTP %d: %s" % [code, body.get_string_from_utf8().substr(0, 200)]

# =========================================================================== #
#  Fetch opponent
# =========================================================================== #

# Async. Result arrives via opponent_fetched (snapshot may be empty = no
# opponents yet) or request_failed. A new call cancels any fetch in flight.
func fetch_opponent(wave: int, power: int, exclude_player_id: String) -> void:
	var cfg_error : String = get_config_error()
	if cfg_error != "":
		request_failed.emit("fetch", cfg_error)
		return
	_fetch_request.cancel_request()
	_fetch_wave = wave
	var exclude : String = "" if allow_self_match else exclude_player_id
	var body : String = JSON.stringify({
		"p_wave":    wave,
		"p_power":   power,
		"p_exclude": exclude,
	})
	var err : Error = _fetch_request.request(
		_rest_url(RPC_PATH), _build_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		request_failed.emit("fetch", "could not start request (error %d)" % err)

func _on_fetch_completed(result: int, response_code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("fetch", "server unreachable (result %d). Free project paused?" % result)
		return
	if response_code != 200:
		request_failed.emit("fetch", _http_error_text(response_code, body))
		return
	# The RPC returns the snapshot object, or JSON null when nothing matches.
	var parsed : Variant = JSON.parse_string(body.get_string_from_utf8())
	var snapshot : Dictionary = {}
	if parsed is Dictionary:
		snapshot = parsed
	opponent_fetched.emit(_fetch_wave, snapshot)

# =========================================================================== #
#  Upload own snapshot
# =========================================================================== #

# Async. Pass the sanitized snapshot from wave_manager.capture_defense_snapshot().
# Empty snapshots are refused here too (they'd hand opponents a free win).
func upload_snapshot(snapshot: Dictionary) -> void:
	var cfg_error : String = get_config_error()
	if cfg_error != "":
		request_failed.emit("upload", cfg_error)
		return
	var units  : Array = snapshot.get("units", [])
	var hired  : Array = snapshot.get("hired_units", [])
	if units.is_empty() and hired.is_empty():
		request_failed.emit("upload", "snapshot is empty, not uploading")
		return
	var wave : int = int(snapshot.get("day", 0))
	if wave < 1:
		request_failed.emit("upload", "snapshot has no wave number")
		return
	var row : Dictionary = {
		"player_id":    str(snapshot.get("player_id", "")),
		"player_name":  str(snapshot.get("player_name", "")),
		"wave":         wave,
		"power":        int(snapshot.get("power", 0)),
		"game_version": str(snapshot.get("game_version", "")),
		"data":         snapshot,
	}
	_upload_wave = wave
	_upload_request.cancel_request()
	var headers : PackedStringArray = _build_headers(PackedStringArray(["Prefer: return=minimal"]))
	var err : Error = _upload_request.request(
		_rest_url(TABLE_PATH), headers, HTTPClient.METHOD_POST, JSON.stringify(row))
	if err != OK:
		request_failed.emit("upload", "could not start request (error %d)" % err)

func _on_upload_completed(result: int, response_code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("upload", "server unreachable (result %d). Free project paused?" % result)
		return
	if response_code != 201 and response_code != 204:
		request_failed.emit("upload", _http_error_text(response_code, body))
		return
	snapshot_uploaded.emit(_upload_wave)

# =========================================================================== #
#  Connection test (settings screen button)
# =========================================================================== #

# Calls the RPC for wave 0, which never has data: a healthy setup answers 200
# with null. Result arrives via connection_tested.
func test_connection() -> void:
	var cfg_error : String = get_config_error()
	if cfg_error != "":
		connection_tested.emit(false, cfg_error)
		return
	_test_request.cancel_request()
	var body : String = JSON.stringify({"p_wave": 0, "p_power": 0, "p_exclude": ""})
	var err : Error = _test_request.request(
		_rest_url(RPC_PATH), _build_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		connection_tested.emit(false, "could not start request (error %d)" % err)

func _on_test_completed(result: int, response_code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		connection_tested.emit(false, "Server unreachable. Check URL, or the free project may be paused.")
		return
	match response_code:
		200:
			connection_tested.emit(true, "Connected.")
		401, 403:
			connection_tested.emit(false, "Key rejected (HTTP %d). Use the publishable key." % response_code)
		404:
			connection_tested.emit(false, "Function not found. Run supabase/schema.sql in the SQL Editor.")
		_:
			connection_tested.emit(false, _http_error_text(response_code, body))
