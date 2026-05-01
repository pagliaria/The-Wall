extends Node2D

# Main game controller for "The Wall"
# Manages game state, camera, and coordinates between systems

# World is 32 x 18 tiles @ 64px = 2048 x 1152 px
# Viewport is 1280 x 720 — zoom ~0.625 fits the full world on screen
const WORLD_WIDTH  = 2048
const WORLD_HEIGHT = 1152
const CAMERA_ZOOM  = 0.625   # 1280 / 2048 ≈ 0.625

const TOWN_ZONE_LEFT    = WORLD_WIDTH * 0.625
const ENEMY_SPAWN_LEFT  = 0
const ENEMY_SPAWN_RIGHT = WORLD_WIDTH * 0.34

@onready var camera: Camera2D = $Camera2D
@onready var terrain: Node2D  = $Terrain

func _ready() -> void:
	_setup_camera()
	print("The Wall – world initialised  (%d × %d px)" % [WORLD_WIDTH, WORLD_HEIGHT])

func _setup_camera() -> void:
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	# Centre the camera on the world so everything is visible
	camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
	# Hard limits so the camera never drifts outside the map
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = WORLD_WIDTH
	camera.limit_bottom = WORLD_HEIGHT
