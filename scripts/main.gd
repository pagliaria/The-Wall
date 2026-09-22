extends Node2D

const FIRE_EFFECT_SCRIPT : GDScript = preload("res://scripts/fire_effect.gd")
const GAME_OVER_SCENE   : PackedScene = preload("res://scenes/game_over.tscn")
const CHEST_SCENE       : PackedScene = preload("res://scenes/chest.tscn")
const TRAINING_TARGET_BASIC_SCENE  : PackedScene = preload("res://scenes/training_target_dummy.tscn")

# Training target configuration
const TRAINING_TARGET_BASIC_HP := 300
const TRAINING_TARGET_COMBAT_HP := 800

var _training_targets : Array = []
var _spawned_basic_count : int = 0
var _spawned_combat_count : int = 0

const MAX_TRAINING_BASIC := 4
const MAX_TRAINING_COMBAT := 2

# Town zone bounds — full map width including wall and battlefield
const TOWN_LEFT   : float = 400.0
const TOWN_RIGHT  : float = 3072.0
const TOWN_TOP    : float = 200.0
const TOWN_BOTTOM : float = 1500.0

const WORLD_WIDTH  = 3072
const WORLD_HEIGHT = 1728

const TILE_SIZE := 64
const MAP_COLS := 48
const MAP_ROWS := 27
const WATER_ROWS := 3
const COL_TOWN_START := 20

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

var _castle_placed := false

@onready var camera           : Camera2D           = $Camera2D
@onready var terrain          : Node2D             = $Terrain
@onready var resource_layer   : Node2D             = $ResourceLayer
@onready var hud              : CanvasLayer         = $HUD
@onready var building_placer  : Node2D             = $BuildingPlacer
@onready var buildings_layer  : Node2D             = $BuildingsLayer
@onready var units_layer      : Node2D             = $UnitsLayer
@onready var unit_selection   : Node2D             = $UnitSelection
@onready var nav_region       : NavigationRegion2D = $NavRegion
@onready var drawbridge       : Node2D             = $wall
@onready var battle_seperator : CollisionShape2D   = $wall/Wall_Collision/BattleSeperator
@onready var wave_timer       : Timer              = $wave_timer
@onready var settings_screen  : CanvasLayer        = $SettingsScreen
@onready var selection_panel  : CanvasLayer        = $HUD/SelectionPanel
@onready var building_upgrade_panel : CanvasLayer  = $HUD/BuildingUpgradePanel

var _castle_prompt    : CanvasLayer = null
var _wave_manager     : Node        = null
var _selected_building : Node       = null

func _ready() -> void:
	_fit_camera_to_screen()
	resource_layer.buildings_layer = buildings_layer
	resource_layer.spawn()
	resource_layer.resource_depleted.connect(_on_resource_depleted)

	building_placer.ground_layer = $Terrain/GroundLayer

	unit_selection.units_layer     = units_layer
	unit_selection.camera          = camera
	unit_selection.selection_panel = selection_panel
	unit_selection.selection_changed.connect(_on_unit_selection_changed)
	selection_panel.set_unit_selection(unit_selection)

	hud.build_pressed.connect(_on_build_pressed)
	hud.building_selected.connect(_on_building_selected)
	hud.settings_pressed.connect(settings_screen.open)
	hud.rush_pressed.connect(_on_rush_pressed)
	settings_screen.display_changed.connect(_fit_camera_to_screen)
	settings_screen.debug_spawn_chest_requested.connect(_on_debug_spawn_chest_requested)
	settings_screen.debug_max_resources_requested.connect(_on_debug_max_resources_requested)
	building_placer.building_placed.connect(_on_building_placed)
	building_placer.placement_cancelled.connect(_on_placement_cancelled)

	_push_resources()
	ResourceManager.resources_changed.connect(_on_resources_changed)
	hud.set_build_button_enabled(false)
	_show_castle_prompt()
	_setup_wave_manager()
	MusicManager.play_chill()

	# Apply any saved gameplay settings
	var start_res : Dictionary = settings_screen.get_start_resources()
	ResourceManager.gold = start_res.get("gold", 100)
	ResourceManager.wood = start_res.get("wood", 50)
	ResourceManager.meat = start_res.get("meat", 10)
	_push_resources()
	wave_timer.wait_time = settings_screen.get_wave_interval()

# =========================================================================== #
#  Wave manager
# =========================================================================== #

func _setup_wave_manager() -> void:
	_wave_manager = Node.new()
	_wave_manager.set_script(load("res://scripts/wave_manager.gd"))
	_wave_manager.name = "WaveManager"
	add_child(_wave_manager)

	_wave_manager.units_layer = units_layer
	_wave_manager.drawbridge  = drawbridge

	_wave_manager.wave_countdown_changed.connect(_on_wave_countdown_changed)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_ended.connect(_on_wave_ended)

func _on_rush_pressed() -> void:
	if _wave_manager == null or not _wave_manager.is_in_prep():
		return
	var reward : Dictionary = _wave_manager.rush_wave()
	for resource in reward:
		ResourceManager.add(resource, reward[resource])
	_push_resources()
	hud.hide_rush_button()

func _on_wave_countdown_changed(seconds: float) -> void:
	hud.set_wave_countdown(seconds)
	if _wave_manager.is_in_prep():
		hud.update_rush_button(_wave_manager.calc_rush_reward(seconds))
	if seconds > 0.0 and _castle_placed and not hud.is_rush_button_visible():
		hud.show_rush_button()
	if seconds <= 90.0 and seconds > 0.0:
		if MusicManager.current_zone != MusicManager.Zone.BATTLE:
			MusicManager.play_battle()
			MusicManager.play_horn()

func _on_wave_started(wave_number: int) -> void:
	_cleanup_training_targets()
	hud.set_wave_active(wave_number)
	hud.hide_rush_button()
	unit_selection.deselect_battling_units()
	UiAudio.play_trimmed("deep_thumps", 0.0, 1.0)
	_clear_building_selection()
	unit_selection.clear_selection()
	unit_selection.disabled = true
	battle_seperator.disabled = true
	call_deferred("_rebake_nav")

func _on_wave_ended(player_won: bool) -> void:
	hud.set_wave_ended(player_won)
	hud.hide_rush_button()
	UiAudio.play_trimmed("deep_thumps", 3.0, 4.0)
	CombatAudio.play("victory" if player_won else "defeat")
	BloodFx.clear_splats()
	if player_won:
		MusicManager.play_chill()
		_cleanup_training_targets()
		_setup_training_targets()
		if not building_placer.is_placing():
			unit_selection.disabled = false
		battle_seperator.disabled = false
		wave_timer.start()
		call_deferred("_rebake_nav")
	else:
		MusicManager.stop()
		_trigger_defeat()

func _cleanup_training_targets() -> void:
	"""Clear all training targets between waves."""
	for target in _training_targets.duplicate(true):
		if is_instance_valid(target):
			target.queue_free()
	_training_targets.clear()
	_spawned_basic_count = 0
	_spawned_combat_count = 0

# Fire effect type constants matching fire_effect.gd EffectType enum
const FX_FIRE      : int = 0
const FX_EXPLOSION : int = 1
const FX_SMOKE     : int = 2

func _trigger_defeat() -> void:
	unit_selection.disabled = true
	battle_seperator.disabled = false
	_spawn_defeat_effects()
	var town_center : Vector2 = Vector2(
		(TOWN_LEFT + TOWN_RIGHT) * 0.5,
		(TOWN_TOP  + TOWN_BOTTOM) * 0.5
	)
	var tw : Tween = create_tween()
	tw.tween_property(camera, "position", town_center, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(3.8).timeout.connect(_show_game_over)

func _spawn_defeat_effects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Spawn all effects immediately with staggered start_delay via Tween
	for i in 20:
		_spawn_fire_at(
			rng.randf_range(TOWN_LEFT, TOWN_RIGHT),
			rng.randf_range(TOWN_TOP, TOWN_BOTTOM),
			FX_EXPLOSION, 0, rng.randf_range(0.0, 2.0)
		)
	for i in 35:
		_spawn_fire_at(
			rng.randf_range(TOWN_LEFT, TOWN_RIGHT),
			rng.randf_range(TOWN_TOP, TOWN_BOTTOM),
			FX_FIRE, 99, rng.randf_range(0.5, 3.0)
		)
	for i in 15:
		_spawn_fire_at(
			rng.randf_range(TOWN_LEFT, TOWN_RIGHT),
			rng.randf_range(TOWN_TOP, TOWN_BOTTOM),
			FX_SMOKE, 99, rng.randf_range(1.0, 3.5)
		)

func _spawn_fire_at(x: float, y: float, type: int, loops: int, delay: float) -> void:
	if delay <= 0.0:
		_spawn_fire_effect(x, y, type, loops)
		return
	var tw : Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: _spawn_fire_effect(x, y, type, loops))

func _spawn_fire_effect(x: float, y: float, type: int, loops: int) -> void:
	var fx : Node2D = Node2D.new()
	fx.set_script(FIRE_EFFECT_SCRIPT)
	fx.position = Vector2(x, y)
	fx.z_index  = 10
	fx.call("setup", type, loops)
	add_child(fx)

func _show_game_over() -> void:
	var go : CanvasLayer = GAME_OVER_SCENE.instantiate()
	add_child(go)
	# Fade in the overlay
	var overlay : ColorRect = go.get_node_or_null("Overlay")
	if overlay != null:
		var tw : Tween = create_tween()
		tw.tween_property(overlay, "color", Color(0.04, 0.02, 0.01, 0.82), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# =========================================================================== #
#  Castle prompt
# =========================================================================== #

func _show_castle_prompt() -> void:
	var scene := load("res://scenes/castle_prompt.tscn") as PackedScene
	_castle_prompt = scene.instantiate()
	add_child(_castle_prompt)
	_castle_prompt.castle_placement_requested.connect(_on_castle_placement_requested)

func _on_castle_placement_requested() -> void:
	_clear_building_selection()
	building_placer.start_placement("castle")
	unit_selection.disabled = true

# =========================================================================== #
#  Building events
# =========================================================================== #

func _on_build_pressed() -> void:
	_clear_building_selection()

func _on_building_selected(building_id: String) -> void:
	_clear_building_selection()
	building_placer.start_placement(building_id)
	unit_selection.disabled = true

func _on_placement_cancelled() -> void:
	unit_selection.disabled = false
	_clear_building_selection()
	if not _castle_placed:
		_castle_prompt.show()

func _on_building_placed(building_id: String, tile: Vector2i) -> void:
	unit_selection.disabled = false

	if building_id == "castle" and not _castle_placed:
		_castle_placed = true
		hud.set_build_button_enabled(true)
		#hud.show_rush_button()
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
	ResourceManager.spend(costs[building_id])
	_push_resources()

func _push_resources() -> void:
	hud.update_resources(ResourceManager.gold, ResourceManager.wood, ResourceManager.meat)

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
	if _building == null or not is_instance_valid(_building):
		return
	# Defer the decision to idle time so it runs after this frame's unit
	# selection has fully resolved, whichever handler fired first.
	call_deferred("_resolve_building_click", _building)

func _resolve_building_click(building: Node) -> void:
	if not is_instance_valid(building):
		return
	# Units always take priority — if this click (or the drag it was part of)
	# left any unit selected, leave that alone and ignore the building entirely.
	if not unit_selection.selected_units.is_empty():
		return
	if not building.supports_upgrades():
		_clear_building_selection()
		return
	_show_building_upgrades(building)

func _show_building_upgrades(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		return
	# Deselect previous
	if _selected_building != null and is_instance_valid(_selected_building):
		_selected_building.set_selected(false)
	_selected_building = building
	building.set_selected(true)
	building_upgrade_panel.show_building(building)

func _clear_building_selection() -> void:
	if _selected_building != null and is_instance_valid(_selected_building):
		_selected_building.set_selected(false)
		_selected_building = null
	if building_upgrade_panel != null and building_upgrade_panel.has_method("hide_panel"):
		building_upgrade_panel.hide_panel()

func _on_unit_selection_changed(_units: Array) -> void:
	_clear_building_selection()

# =========================================================================== #
#  Resource delivery
# =========================================================================== #

func _on_resource_delivered(resource_type: String, amount: int) -> void:
	ResourceManager.add(resource_type, amount)
	_push_resources()

func _on_resources_changed(_gold: int, _wood: int, _meat: int) -> void:
	_push_resources()

func _on_resource_depleted() -> void:
	_rebake_nav()

# =========================================================================== #
#  Training Targets (Inter-wave activities)
# =========================================================================== #

func _setup_training_targets() -> void:
	_add_child_training_target("basic", _training_target_config())
	_add_child_training_target("basic", _training_target_config())
	_add_child_training_target("basic", _training_target_config())
	_add_child_training_target("basic", _training_target_config())

func _add_child_training_target(type: String, config_overrides: Dictionary) -> Node2D:
	var scene : Node2D = TRAINING_TARGET_BASIC_SCENE.instantiate()
	if scene == null:
		printerr("Training target basic scene failed to load!")
		return null
	
	# Setup the training target at random town position
	scene.setup(type, get_random_town_position_for_dummy(), config_overrides)
	add_child(scene)
	_training_targets.append(scene)
	if type == "basic":
		_spawned_basic_count += 1  
	else:
		_spawned_combat_count += 1
	
	return scene

func get_random_town_position_for_dummy() -> Vector2:
	# Spawn near town center but not overlapping buildings, resource nodes, or
	# their placement-blocker zones.
	var cols := int(5 + randi() % 8)  # Offset from town start
	var rows := int(5 + randi() % 8)  # Rows up
	var preferred := Vector2(
		float((COL_TOWN_START + cols) * TILE_SIZE),
		float((WATER_ROWS + rows) * TILE_SIZE)
	)
	return _find_clear_dummy_spot(preferred)

# Dummy footprint clearance — covers the dummy's own collision box (36x66) plus
# a bit of breathing room so it doesn't visually clip into whatever it's next to.
const DUMMY_CLEARANCE_RADIUS : float = 48.0

func _is_dummy_position_clear(pos: Vector2) -> bool:
	# Same technique building_placer.gd uses to validate building placement:
	# a physics shape query against real colliders, so it automatically respects
	# every building's actual footprint and every resource's PlacementBlocker
	# area, rather than us having to hand-track their sizes separately.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = DUMMY_CLEARANCE_RADIUS
	query.shape             = circle
	query.transform         = Transform2D(0.0, pos)
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	return space_state.intersect_shape(query, 1 | 16).is_empty()

func _find_clear_dummy_spot(preferred: Vector2) -> Vector2:
	# Nudge away from anything occupying the spot by spiraling outward — same
	# idea used for chest and item-drop placement elsewhere in this file.
	const MAX_ATTEMPTS : int = 30
	var candidate : Vector2 = preferred
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt in MAX_ATTEMPTS:
		if _is_valid_position(candidate) and _is_dummy_position_clear(candidate):
			return candidate
		var extra_radius : float = DUMMY_CLEARANCE_RADIUS * 0.8 * float(attempt + 1)
		var jitter_angle  : float = rng.randf() * TAU
		candidate = preferred + Vector2(cos(jitter_angle), sin(jitter_angle)) * extra_radius
		candidate.x = clampf(candidate.x, float(COL_TOWN_START * TILE_SIZE), float((MAP_COLS - 1) * TILE_SIZE))
		candidate.y = clampf(candidate.y, float(WATER_ROWS * TILE_SIZE), float((MAP_ROWS - 1) * TILE_SIZE))
	return candidate  # best effort — still on-map even if a touch tight

func _training_target_config(mode: String = "basic") -> Dictionary:
	match mode:
		"combat":
			return { "max_hp": TRAINING_TARGET_COMBAT_HP }
		_:
			return { "max_hp": TRAINING_TARGET_BASIC_HP }

func _is_valid_position(p_position: Vector2) -> bool:
	if p_position.x < float(COL_TOWN_START * TILE_SIZE):
		return false
	if p_position.x >= float(MAP_COLS * TILE_SIZE):
		return false
	if p_position.y < float(WATER_ROWS * TILE_SIZE):
		return false
	if p_position.y >= float(MAP_ROWS * TILE_SIZE):
		return false
	return true

# =========================================================================== #
#  Wave Manager Integration
# =========================================================================== #

func _on_debug_spawn_chest_requested() -> void:
	var chest : Node2D = CHEST_SCENE.instantiate()
	chest.call("setup", 0)
	chest.position = camera.global_position
	add_child(chest)

func _on_debug_max_resources_requested() -> void:
	ResourceManager.gold = 1000
	ResourceManager.wood = 1000
	ResourceManager.meat = 1000
	_push_resources()

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

# =========================================================================== #
#  Training Target Utility Methods
# =========================================================================== #

func spawn_training_target(mode: String = "basic", p_position: Vector2 = Vector2.ZERO) -> bool:
	# Spawn training target at p_position or random town spot. Zero = auto-pick.
	if _wave_manager != null and not _wave_manager.is_in_prep():
		printerr("Training targets only spawn between waves!")
		return false

	var spawn_pos : Vector2
	if p_position == Vector2.ZERO or not _is_valid_position(p_position):
		if mode == "basic":
			spawn_pos = get_random_town_position_for_dummy()
		else:
			spawn_pos = _find_clear_dummy_spot(Vector2(
				float((COL_TOWN_START + 8) * TILE_SIZE),
				float((WATER_ROWS + 4) * TILE_SIZE)
			))
	else:
		spawn_pos = _find_clear_dummy_spot(p_position)

	var scene : Node2D = TRAINING_TARGET_BASIC_SCENE.instantiate()
	if scene == null:
		printerr("Training target basic scene failed to load!")
		return false

	scene.setup(mode, spawn_pos, _training_target_config(mode))
	add_child(scene)
	_training_targets.append(scene)

	if mode == "basic":
		_spawned_basic_count += 1
	else:
		_spawned_combat_count += 1

	return true

func get_training_target_count() -> int:
	return _training_targets.size()
