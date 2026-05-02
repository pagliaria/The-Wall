extends Node2D

# Main game controller for "The Wall"
# Manages game state, camera, and coordinates between systems

# World is 32 x 18 tiles @ 64px = 2048 x 1152 px
const WORLD_WIDTH  = 2048
const WORLD_HEIGHT = 1152

const TOWN_ZONE_LEFT    = WORLD_WIDTH * 0.625
const ENEMY_SPAWN_LEFT  = 0
const ENEMY_SPAWN_RIGHT = WORLD_WIDTH * 0.34

@onready var camera: Camera2D = $Camera2D
@onready var terrain: Node2D  = $Terrain

func _ready() -> void:
	_fit_camera_to_screen()
	print("The Wall – world initialised  (%d × %d px)" % [WORLD_WIDTH, WORLD_HEIGHT])

func _fit_camera_to_screen() -> void:
	# Calculate zoom so the entire world fits within the current window,
	# with no distortion — use whichever axis is the tighter fit.
	var screen  := Vector2(DisplayServer.window_get_size())
	var zoom_x  := screen.x / float(WORLD_WIDTH)
	var zoom_y  := screen.y / float(WORLD_HEIGHT)
	var zoom    := minf(zoom_x, zoom_y)

	camera.zoom     = Vector2(zoom, zoom)
	camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)

	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = WORLD_WIDTH
	camera.limit_bottom = WORLD_HEIGHT

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Wait one frame for the window to finish resizing before recalculating
	await get_tree().process_frame
	_fit_camera_to_screen()
