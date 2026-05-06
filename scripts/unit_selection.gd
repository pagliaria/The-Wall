extends Node2D

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

# Injected by main.gd
var units_layer : Node2D   = null
var camera      : Camera2D = null

# -- Lifecycle ----------------------------------------------------------------

func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_DEFAULT, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

# -- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if disabled:
		_reset_cursor()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_lmb_down(event.position)
			else:
				_on_lmb_up(event.position, event.shift_pressed)

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_units.size() > 0:
				var world_pos := _screen_to_world(event.position)
				var resource  := _resource_at(world_pos)
				if resource != null:
					_issue_gather_order(resource, event.position)
				else:
					_issue_move_order(event.position)

	elif event is InputEventMouseMotion:
		if _pressing:
			_drag_end = event.position
			if event.position.distance_to(_press_screen) >= DRAG_THRESHOLD:
				_drag_active = true
			_get_overlay().queue_redraw()
		_update_cursor(event.position)

func _on_lmb_down(screen_pos: Vector2) -> void:
	_pressing     = true
	_drag_active  = false
	_press_screen = screen_pos
	_drag_end     = screen_pos

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

func _issue_gather_order(resource_node: Node, screen_pos: Vector2) -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("gather_resource"):
			unit.gather_resource(resource_node, resource_node.collision_body)
	_get_overlay().show_ping(screen_pos)

func contains_pawns() -> bool:
	for unit in selected_units:
		print(unit.name)
		if unit.name.contains("Pawn"):
			return true
	return false

func _issue_move_order(screen_pos: Vector2) -> void:
	var world_target := _screen_to_world(screen_pos)
	var count        := selected_units.size()
	const SPACING   := 42.0
	const ROW_WIDTH := 4
	for i in range(count):
		var unit : Node = selected_units[i]
		if not is_instance_valid(unit):
			continue
		var col    := i % ROW_WIDTH
		var row    := i / ROW_WIDTH
		var row_width : Variant = min(count - row * ROW_WIDTH, ROW_WIDTH)
		var row_shift := SPACING * 0.5 if row % 2 == 1 else 0.0
		var offset := Vector2(
			(col - (row_width - 1) * 0.5) * SPACING + row_shift,
			row * SPACING
		)
		unit.move_to(world_target + offset)
	_get_overlay().show_ping(screen_pos)

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

# Returns the ResourceNode (not the Area2D) if world_pos is inside any hover
# area, or null if not.
func _resource_at(world_pos: Vector2) -> Node:
	for area in get_tree().get_nodes_in_group("resource_hover"):
		if not area is Area2D:
			continue
		var circle := area.shape_owner_get_shape(0, 0) as CircleShape2D
		if circle == null:
			continue
		if world_pos.distance_to(area.global_position) > circle.radius:
			continue
		# Walk up to the root Node2D of the resource and find its ResourceNode
		var root := area.get_parent()
		var rn   := root.get_node_or_null("ResourceNode")
		if rn != null and not rn.is_depleted():
			return rn
	return null

# -- Selection ----------------------------------------------------------------

func _do_point_select(screen_pos: Vector2, additive: bool) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var hit : Node = null
	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
				continue
			if unit.position.distance_to(world_pos) <= 32.0:
				hit = unit
				break
	if not additive:
		_deselect_all()
	if hit:
		if additive and hit.is_selected:
			_deselect_unit(hit)
		else:
			_select_unit(hit)

func _do_box_select(additive: bool) -> void:
	var rect_screen := Rect2(_press_screen, _drag_end - _press_screen).abs()
	if not additive:
		_deselect_all()
	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
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

func _deselect_unit(unit: Node) -> void:
	selected_units.erase(unit)
	unit.set_selected(false)

func _deselect_all() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	_reset_cursor()

func _on_unit_died(unit: Node) -> void:
	selected_units.erase(unit)
	if selected_units.is_empty():
		_reset_cursor()

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
