extends Node2D

signal selection_changed(units: Array)

# UnitSelection -- handles single-click and drag-box selection of units.
#
# Attach to a Node2D in main.tscn.
# Set `units_layer` from main.gd after _ready().
# Set `disabled = true` while placement mode or other exclusive modes are active.

# -- Tuning -------------------------------------------------------------------
const DRAG_THRESHOLD = 6.0   # px of mouse travel before it counts as a drag

# -- Cursors ------------------------------------------------------------------
const CURSOR_DEFAULT := preload("res://assets/UI Elements/UI Elements/Cursors/Cursor_01.png")
const CURSOR_GATHER  := preload("res://assets/UI Elements/UI Elements/Cursors/Cursor_02.png")
const CURSOR_HOTSPOT := Vector2(20, 18)

# -- State --------------------------------------------------------------------
var disabled       : bool  = false
var selected_units : Array = []

var _pressing     : bool    = false
var _press_screen : Vector2 = Vector2.ZERO
var _drag_active  : bool    = false
var _drag_end     : Vector2 = Vector2.ZERO

var _gather_cursor_active : bool = false

var current_formation : int = FormationManager.Formation.LINE
var current_spacing   : int = FormationManager.Spacing.NORMAL

# RMB formation drag state
var _rmb_down         : bool    = false
var _rmb_drag_active  : bool    = false
var _rmb_press_screen : Vector2 = Vector2.ZERO
var _rmb_anchor_world : Vector2 = Vector2.ZERO
var _rmb_live_units   : Array   = []
var _rmb_slots        : Array   = []

var _last_click_time   : float   = -1.0
var _last_click_screen : Vector2 = Vector2.ZERO
const DOUBLE_CLICK_TIME : float  = 0.35
const DOUBLE_CLICK_DIST : float  = 12.0

# Injected by main.gd
var units_layer     : Node2D   = null
var camera          : Camera2D = null
var selection_panel : Node     = null   # SelectionPanel CanvasLayer

# -- Lifecycle ----------------------------------------------------------------

func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

# -- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if disabled:
		_reset_cursor()
		return
	if _is_mouse_over_ui(event):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_lmb_down(event.position)
			else:
				_on_lmb_up(event.position, event.shift_pressed)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_on_rmb_down(event.position)
			else:
				_on_rmb_up(event.position)

	elif event is InputEventMouseMotion:
		if _pressing:
			_drag_end = event.position
			if event.position.distance_to(_press_screen) >= DRAG_THRESHOLD:
				_drag_active = true
			_get_overlay().queue_redraw()
		if _rmb_down and event.position.distance_to(_rmb_press_screen) >= DRAG_THRESHOLD:
			_rmb_drag_active = true
			_on_rmb_drag(event.position)
		_update_cursor(event.position)

func _is_mouse_over_ui(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return false
	return get_viewport().gui_get_hovered_control() != null

func _on_lmb_down(screen_pos: Vector2) -> void:
	# Don't start selection drag if an item is being picked up
	for item in get_tree().get_nodes_in_group("ground_items"):
		if item.get("_dragging") == true:
			return
	_pressing     = true
	_drag_active  = false
	_press_screen = screen_pos
	_drag_end     = screen_pos

func _on_rmb_down(screen_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	_rmb_down         = true
	_rmb_drag_active  = false
	_rmb_press_screen = screen_pos
	_rmb_anchor_world = _screen_to_world(screen_pos)
	_rmb_live_units   = selected_units.filter(
		func(u): return is_instance_valid(u) and not _is_in_battle(u)
	)
	_rmb_slots = []

func _on_rmb_drag(screen_pos: Vector2) -> void:
	if _rmb_live_units.is_empty():
		return
	var mouse_world : Vector2 = _screen_to_world(screen_pos)
	var dir : Vector2 = (mouse_world - _rmb_anchor_world).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0, -1)
	_rmb_slots = FormationManager.get_slots(
		_rmb_live_units, _rmb_anchor_world, dir,
		current_formation, current_spacing
	)
	if _rmb_live_units.size() > 1:
		_get_overlay().show_formation_markers(_rmb_slots)
	_get_overlay().show_formation_drag(_rmb_press_screen, screen_pos)
	_get_overlay().queue_redraw()

func _on_rmb_up(screen_pos: Vector2) -> void:
	if not _rmb_down:
		return
	_rmb_down = false
	_get_overlay().hide_formation_drag()
	if _rmb_drag_active:
		# Commit the formation drag
		_rmb_drag_active = false
		if not _rmb_live_units.is_empty() and not _rmb_slots.is_empty():
			for i in _rmb_live_units.size():
				_rmb_live_units[i].move_to(_rmb_slots[i])
			_get_overlay().show_ping(screen_pos)
	else:
		# Plain click — original behaviour
		if selected_units.size() > 0:
			var world_pos : Vector2 = _screen_to_world(screen_pos)
			var resource  : Node    = _resource_at(world_pos)
			if resource != null:
				_issue_gather_order(resource, screen_pos)
			else:
				_issue_move_order(screen_pos)

func _on_lmb_up(screen_pos: Vector2, additive: bool) -> void:
	if not _pressing:
		return
	_pressing = false
	_get_overlay().queue_redraw()

	if _drag_active:
		_drag_active = false
		_do_box_select(additive)
	else:
		_do_point_select(screen_pos, additive)

# -- Orders -------------------------------------------------------------------

func _is_in_battle(unit: Node) -> bool:
	if not is_instance_valid(unit):
		return false
	var target = unit.get("_target")
	return target != null and is_instance_valid(target)

func _issue_gather_order(resource_node: Node, screen_pos: Vector2) -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("gather_resource"):
			unit.gather_resource(resource_node, resource_node.collision_body)
	_get_overlay().show_ping(screen_pos)

func contains_pawns() -> bool:
	for unit in selected_units:
		if unit.name.contains("Pawn"):
			return true
	return false

func _issue_move_order(screen_pos: Vector2) -> void:
	var world_target : Vector2 = _screen_to_world(screen_pos)
	var live_units   : Array   = selected_units.filter(
		func(u): return is_instance_valid(u) and not _is_in_battle(u)
	)
	if live_units.is_empty():
		return
	# Compute move direction from group centroid to target
	var centroid : Vector2 = Vector2.ZERO
	for u in live_units:
		centroid += u.position
	centroid /= live_units.size()
	var dir : Vector2 = (world_target - centroid).normalized()
	var slots : Array = FormationManager.get_slots(
		live_units, world_target, dir,
		current_formation, current_spacing
	)
	for i in live_units.size():
		live_units[i].move_to(slots[i])
	if live_units.size() > 1:
		_get_overlay().show_formation_markers(slots)
	_get_overlay().show_ping(screen_pos)

func set_formation(formation: int) -> void:
	current_formation = formation

func set_spacing(spacing: int) -> void:
	current_spacing = spacing

# -- Cursor -------------------------------------------------------------------

func _update_cursor(screen_pos: Vector2) -> void:
	if selected_units.size() == 0:
		_reset_cursor()
		return
	var world_pos := _screen_to_world(screen_pos)
	if contains_pawns() and _is_over_resource(world_pos):
		if not _gather_cursor_active:
			Input.set_custom_mouse_cursor(CURSOR_GATHER, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
			_gather_cursor_active = true
	else:
		_reset_cursor()

func _reset_cursor() -> void:
	if _gather_cursor_active:
		Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
		_gather_cursor_active = false

func _is_over_resource(world_pos: Vector2) -> bool:
	return _resource_at(world_pos) != null

func _resource_at(world_pos: Vector2) -> Node:
	for area in get_tree().get_nodes_in_group("resource_hover"):
		if not area is Area2D:
			continue
		var circle := area.shape_owner_get_shape(0, 0) as CircleShape2D
		if circle == null:
			continue
		if world_pos.distance_to(area.global_position) > circle.radius:
			continue
		var root := area.get_parent()
		var rn   := root.get_node_or_null("ResourceNode")
		if rn != null and not rn.is_depleted():
			return rn
	return null

# -- Selection ----------------------------------------------------------------

func _do_point_select(screen_pos: Vector2, additive: bool) -> void:
	var world_pos : Vector2 = _screen_to_world(screen_pos)
	var hit       : Node    = null
	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
				continue
			if _is_in_battle(unit):
				continue
			if unit.position.distance_to(world_pos) <= 32.0:
				hit = unit
				break
	# Double-click detection
	var now          : float = Time.get_ticks_msec() / 1000.0
	var is_double    : bool  = hit != null \
		and (now - _last_click_time) <= DOUBLE_CLICK_TIME \
		and screen_pos.distance_to(_last_click_screen) <= DOUBLE_CLICK_DIST
	_last_click_time   = now
	_last_click_screen = screen_pos
	if is_double:
		_select_all_of_type(hit)
		return
	if not additive:
		_deselect_all()
	if hit:
		if additive and hit.is_selected:
			_deselect_unit(hit)
		else:
			_select_unit(hit)

func _unit_type_key(unit: Node) -> String:
	var script : Script = unit.get_script()
	if script:
		return script.resource_path.get_file().get_basename().to_lower()
	return ""

func _select_all_of_type(reference_unit: Node) -> void:
	var type_key : String = _unit_type_key(reference_unit)
	if type_key == "":
		return
	_deselect_all()
	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
				continue
			if _is_in_battle(unit):
				continue
			if _unit_type_key(unit) == type_key:
				_select_unit(unit)

func _do_box_select(additive: bool) -> void:
	var rect_screen := Rect2(_press_screen, _drag_end - _press_screen).abs()
	if not additive:
		_deselect_all()
	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
				continue
			if _is_in_battle(unit):
				continue
			if rect_screen.has_point(_world_to_screen(unit.position)):
				_select_unit(unit)

func _select_unit(unit: Node) -> void:
	if unit in selected_units:
		return
	selected_units.append(unit)
	unit.set_selected(true)
	if not unit.died.is_connected(_on_unit_died.bind(unit)):
		unit.died.connect(_on_unit_died.bind(unit))
	_notify_panel()

func _deselect_unit(unit: Node) -> void:
	selected_units.erase(unit)
	unit.set_selected(false)
	_notify_panel()

func _deselect_all() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	_reset_cursor()
	_notify_panel()

func clear_selection() -> void:
	_deselect_all()

func deselect_battling_units() -> void:
	var to_deselect : Array = selected_units.filter(func(u): return _is_in_battle(u))
	for unit in to_deselect:
		_deselect_unit(unit)

func _on_unit_died(unit: Node) -> void:
	selected_units.erase(unit)
	if selected_units.is_empty():
		_reset_cursor()
	_notify_panel()

# -- Panel notify -------------------------------------------------------------

func _notify_panel() -> void:
	if selection_panel != null and selection_panel.has_method("refresh"):
		# Strip dead instances before passing
		var live : Array = selected_units.filter(func(u): return is_instance_valid(u))
		selection_panel.refresh(live)
		emit_signal("selection_changed", live)

# -- Coordinate helpers -------------------------------------------------------

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

# -- Overlay ------------------------------------------------------------------

func _get_overlay() -> Node:
	return get_node("Overlay/Draw")

# -- Public -------------------------------------------------------------------

func get_selected() -> Array:
	return selected_units
