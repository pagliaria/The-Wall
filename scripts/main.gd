extends Node2D

const WORLD_WIDTH  = 3072
const WORLD_HEIGHT = 1728

const TOWN_ZONE_LEFT    = WORLD_WIDTH * 0.625
const ENEMY_SPAWN_LEFT  = 0
const ENEMY_SPAWN_RIGHT = WORLD_WIDTH * 0.34

const ZOOM_STEP = 0.1
const ZOOM_MAX  = 2.0
var zoom_min    := 0.1

const EDGE_MARGIN = 24
const EDGE_SPEED  = 600.0

var _panning         := false
var _pan_start_mouse := Vector2.ZERO
var _pan_start_cam   := Vector2.ZERO

var _gold : int = 100
var _wood : int = 50
var _meat : int = 10

var _gold_multiplier = 10
var _wood_multiplier = 10
var _meat_multiplier = 1

var _castle_placed := false

@onready var camera          : Camera2D           = $Camera2D
@onready var terrain         : Node2D             = $Terrain
@onready var resource_layer  : Node2D             = $ResourceLayer
@onready var hud             : CanvasLayer         = $HUD
@onready var building_placer : Node2D             = $BuildingPlacer
@onready var buildings_layer : Node2D             = $BuildingsLayer
@onready var units_layer     : Node2D             = $UnitsLayer
@onready var unit_selection  : Node2D             = $UnitSelection
@onready var nav_region      : NavigationRegion2D = $NavRegion
@onready var drawbridge      : Node2D             = $wall
@onready var battle_seperator: CollisionShape2D   = $wall/Wall_Collision/BattleSeperator
@onready var wave_timer      : Timer              = $wave_timer

var _castle_prompt : CanvasLayer = null
var _wave_manager  : Node        = null

func _ready() -> void:
	_fit_camera_to_screen()
	resource_layer.spawn()
	resource_layer.resource_depleted.connect(_on_resource_depleted)

	building_placer.ground_layer = $Terrain/GroundLayer

	unit_selection.units_layer = units_layer
	unit_selection.camera      = camera

	hud.build_pressed.connect(_on_build_pressed)
	hud.building_selected.connect(_on_building_selected)
	building_placer.building_placed.connect(_on_building_placed)
	building_placer.placement_cancelled.connect(_on_placement_cancelled)

	_push_resources()
	hud.set_build_button_enabled(false)
	_show_castle_prompt()
	_setup_wave_manager()

# =========================================================================== #
#  Wave manager
# =========================================================================== #

func _setup_wave_manager() -> void:
	_wave_manager = Node.new()
	_wave_manager.set_script(load("res://scripts/wave_manager.gd"))
	_wave_manager.name = "WaveManager"
	add_child(_wave_manager)

	# wave_manager loads its own scenes via WAVE_COMPOSITIONS — just inject
	# the shared references it needs to spawn into and control.
	_wave_manager.units_layer = units_layer
	_wave_manager.drawbridge  = drawbridge

	_wave_manager.wave_countdown_changed.connect(_on_wave_countdown_changed)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_ended.connect(_on_wave_ended)

func _on_wave_countdown_changed(seconds: float) -> void:
	hud.set_wave_countdown(seconds)

func _on_wave_started(wave_number: int) -> void:
	hud.set_wave_active(wave_number)
	unit_selection.clear_selection()
	unit_selection.disabled = true
	battle_seperator.disabled = true
	call_deferred("_rebake_nav")

func _on_wave_ended(player_won: bool) -> void:
	hud.set_wave_ended(player_won)
	if not building_placer.is_placing():
		unit_selection.disabled = false
	battle_seperator.disabled = false
	wave_timer.start()
	call_deferred("_rebake_nav")

# =========================================================================== #
#  Castle prompt
# =========================================================================== #

func _show_castle_prompt() -> void:
	var scene := load("res://scenes/castle_prompt.tscn") as PackedScene
	_castle_prompt = scene.instantiate()
	add_child(_castle_prompt)
	_castle_prompt.castle_placement_requested.connect(_on_castle_placement_requested)

func _on_castle_placement_requested() -> void:
	building_placer.start_placement("castle")
	unit_selection.disabled = true

# =========================================================================== #
#  Building events
# =========================================================================== #

func _on_build_pressed() -> void:
	pass

func _on_building_selected(building_id: String) -> void:
	building_placer.start_placement(building_id)
	unit_selection.disabled = true

func _on_placement_cancelled() -> void:
	unit_selection.disabled = false
	if not _castle_placed:
		_castle_prompt.show()

func _on_building_placed(building_id: String, tile: Vector2i) -> void:
	unit_selection.disabled = false

	if building_id == "castle" and not _castle_placed:
		_castle_placed = true
		hud.set_build_button_enabled(true)
		if _castle_prompt != null:
			_castle_prompt.queue_free()
			_castle_prompt = null

	_spend_building_cost(building_id)

	var building := StaticBody2D.new()
	building.set_script(load("res://scripts/placed_building.gd"))
	buildings_layer.add_child(building)
	building.setup(building_id, tile, units_layer)
	building.building_clicked.connect(_on_building_clicked)

	if building_id == "castle":
		var ctrl : Node = building.get_controller()
		if ctrl != null and ctrl.has_signal("pawn_delivered_resource"):
			ctrl.connect("pawn_delivered_resource", _on_resource_delivered)

	_rebake_nav()

func _spend_building_cost(building_id: String) -> void:
	var costs: Dictionary = load("res://scripts/build_menu.gd").BUILDING_COSTS
	if not costs.has(building_id):
		return
	var cost: Dictionary = costs[building_id]
	_gold -= cost.get("gold", 0)
	_wood -= cost.get("wood", 0)
	_meat -= cost.get("meat", 0)
	_push_resources()

func _push_resources() -> void:
	hud.update_resources(_gold, _wood, _meat)

func _rebake_nav() -> void:
	var poly := nav_region.navigation_polygon
	if poly == null:
		return
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	poly.agent_radius = 32.0
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(poly, source_geometry, self)
	NavigationServer2D.bake_from_source_geometry_data(poly, source_geometry, _on_nav_bake_complete)

func _on_nav_bake_complete() -> void:
	NavigationServer2D.region_set_navigation_polygon(
		nav_region.get_region_rid(), nav_region.navigation_polygon
	)

func _on_building_clicked(_building: Node) -> void:
	pass

# =========================================================================== #
#  Resource delivery
# =========================================================================== #

func _on_resource_delivered(resource_type: String, amount: int) -> void:
	match resource_type:
		"gold": _gold += amount * _gold_multiplier
		"wood": _wood += amount * _wood_multiplier
		"meat": _meat += amount * _meat_multiplier
	_push_resources()

func _on_resource_depleted() -> void:
	_rebake_nav()

# =========================================================================== #
#  Camera
# =========================================================================== #

func _fit_camera_to_screen() -> void:
	var screen := Vector2(DisplayServer.window_get_size())
	var zoom_x := screen.x / float(WORLD_WIDTH)
	var zoom_y := screen.y / float(WORLD_HEIGHT)
	zoom_min = maxf(zoom_x, zoom_y)
	camera.zoom     = Vector2(zoom_min, zoom_min)
	camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
	_apply_camera_limits()

func _apply_camera_limits() -> void:
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = WORLD_WIDTH
	camera.limit_bottom = WORLD_HEIGHT

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
	if mouse.x < EDGE_MARGIN:               move.x = -speed
	elif mouse.x > screen.x - EDGE_MARGIN:  move.x =  speed
	if mouse.y < EDGE_MARGIN:               move.y = -speed
	elif mouse.y > screen.y - EDGE_MARGIN:  move.y =  speed
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _zoom_toward_mouse(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _zoom_toward_mouse(-ZOOM_STEP)
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

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().process_frame
	_fit_camera_to_screen()


func _on_wave_timer_timeout() -> void:
	_wave_manager._prepare_next_wave()
