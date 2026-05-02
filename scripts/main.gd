extends Node2D

# Main game controller for "The Wall"
# Manages game state, camera, and coordinates between systems

# World is 48 x 27 tiles @ 64px = 3072 x 1728 px
const WORLD_WIDTH  = 3072
const WORLD_HEIGHT = 1728

const TOWN_ZONE_LEFT    = WORLD_WIDTH * 0.625
const ENEMY_SPAWN_LEFT  = 0
const ENEMY_SPAWN_RIGHT = WORLD_WIDTH * 0.34

# ── Zoom ──────────────────────────────────────────────────────────────────────
const ZOOM_STEP    = 0.1    # how much each scroll tick zooms
const ZOOM_MAX     = 2.0    # closest in
# ZOOM_MIN is calculated dynamically in _fit_camera_to_screen()
# so the map can never appear smaller than the window
var zoom_min       := 0.1   # updated at runtime — don't set this manually

# ── Edge pan ──────────────────────────────────────────────────────────────────
const EDGE_MARGIN  = 24     # px from screen edge that triggers panning
const EDGE_SPEED   = 600.0  # px/sec at base zoom 1.0

# ── Middle-mouse pan ──────────────────────────────────────────────────────────
var _panning          := false
var _pan_start_mouse  := Vector2.ZERO
var _pan_start_cam    := Vector2.ZERO

@onready var camera          : Camera2D  = $Camera2D
@onready var terrain         : Node2D    = $Terrain
@onready var resource_layer  : Node2D    = $ResourceLayer

func _ready() -> void:
	_fit_camera_to_screen()
	# Terrain fills its TileMapLayer in its own _ready(), which runs before
	# this call, so the ground_layer is fully painted by the time we spawn.
	resource_layer.spawn($Terrain/GroundLayer)
	print("The Wall – world initialised  (%d × %d px)" % [WORLD_WIDTH, WORLD_HEIGHT])
	
# ── Camera fit ────────────────────────────────────────────────────────────────
func _fit_camera_to_screen() -> void:
	var screen := Vector2(DisplayServer.window_get_size())
	var zoom_x := screen.x / float(WORLD_WIDTH)
	var zoom_y := screen.y / float(WORLD_HEIGHT)
	# The fit-zoom is whichever axis is tighter — this becomes our minimum.
	# At this zoom the world exactly fills the window on its tightest axis,
	# so zooming out any further would show empty space outside the map.
	zoom_min = maxf(zoom_x, zoom_y)

	camera.zoom     = Vector2(zoom_min, zoom_min)
	camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
	_apply_camera_limits()

func _apply_camera_limits() -> void:
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = WORLD_WIDTH
	camera.limit_bottom = WORLD_HEIGHT

# ── Per-frame update ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_handle_edge_pan(delta)
	_handle_middle_mouse_pan()

func _handle_edge_pan(delta: float) -> void:
	if _panning:
		return
	var mouse  := get_viewport().get_mouse_position()
	var screen := Vector2(DisplayServer.window_get_size())
	var move   := Vector2.ZERO
	var speed  := EDGE_SPEED / camera.zoom.x * delta

	if mouse.x < EDGE_MARGIN:
		move.x = -speed
	elif mouse.x > screen.x - EDGE_MARGIN:
		move.x =  speed
	if mouse.y < EDGE_MARGIN:
		move.y = -speed
	elif mouse.y > screen.y - EDGE_MARGIN:
		move.y =  speed

	camera.position = _clamped(camera.position + move)

func _handle_middle_mouse_pan() -> void:
	if not _panning:
		return
	var offset      := get_viewport().get_mouse_position() - _pan_start_mouse
	var world_delta := offset / camera.zoom.x
	camera.position = _clamped(_pan_start_cam - world_delta)

func _clamped(pos: Vector2) -> Vector2:
	var half := Vector2(
		get_viewport_rect().size.x * 0.5 / camera.zoom.x,
		get_viewport_rect().size.y * 0.5 / camera.zoom.y
	)
	return Vector2(
		clampf(pos.x, half.x, WORLD_WIDTH  - half.x),
		clampf(pos.y, half.y, WORLD_HEIGHT - half.y)
	)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_toward_mouse(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_toward_mouse(-ZOOM_STEP)
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_panning         = true
					_pan_start_mouse = get_viewport().get_mouse_position()
					_pan_start_cam   = camera.position
				else:
					_panning = false

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()

func _zoom_toward_mouse(step: float) -> void:
	var old_zoom := camera.zoom.x
	var new_zoom := clampf(old_zoom + step, zoom_min, ZOOM_MAX)
	if new_zoom == old_zoom:
		return

	var mouse_screen    := get_viewport().get_mouse_position()
	var viewport_centre := get_viewport_rect().size * 0.5
	var mouse_offset    := (mouse_screen - viewport_centre) / old_zoom

	camera.zoom     = Vector2(new_zoom, new_zoom)
	camera.position = _clamped(camera.position + mouse_offset * (1.0 - old_zoom / new_zoom))

# ── Fullscreen ────────────────────────────────────────────────────────────────

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().process_frame
	_fit_camera_to_screen()
