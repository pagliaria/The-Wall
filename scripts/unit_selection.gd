extends Node2D

# UnitSelection — handles single-click and drag-box selection of units.
#
# Attach to a Node2D in main.tscn.
# Set `units_layer` from main.gd after _ready().
# Set `disabled = true` while placement mode or other exclusive modes are active.

# ── Tuning ────────────────────────────────────────────────────────────────────
const DRAG_THRESHOLD = 6.0   # px of mouse travel before it counts as a drag

# ── Drag box visual ───────────────────────────────────────────────────────────
const BOX_FILL    = Color(0.3, 0.85, 1.0, 0.08)
const BOX_BORDER  = Color(0.3, 0.85, 1.0, 0.70)
const BOX_WIDTH   = 1.5

# ── State ─────────────────────────────────────────────────────────────────────
var disabled       : bool    = false
var selected_units : Array   = []   # Array[Node] — currently selected pawns

var _pressing      : bool    = false
var _press_screen  : Vector2 = Vector2.ZERO   # screen coords where LMB went down
var _drag_active   : bool    = false
var _drag_end      : Vector2 = Vector2.ZERO   # current mouse screen pos while dragging

# Injected by main.gd
var units_layer    : Node2D  = null
var camera         : Camera2D = null

# ── Draw (drag rectangle, screen space) ───────────────────────────────────────
# We use a CanvasLayer child for screen-space drawing — see UnitSelectionOverlay.

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_lmb_down(event.position)
			else:
				_on_lmb_up(event.position, event.shift_pressed)

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_units.size() > 0:
				_issue_move_order(event.position)
			else:
				_deselect_all()

	elif event is InputEventMouseMotion and _pressing:
		_drag_end = event.position
		var travelled : float = event.position.distance_to(_press_screen)
		if travelled >= DRAG_THRESHOLD:
			_drag_active = true
		# Tell the overlay to redraw
		_get_overlay().queue_redraw()

func _on_lmb_down(screen_pos: Vector2) -> void:
	_pressing     = true
	_drag_active  = false
	_press_screen = screen_pos
	_drag_end     = screen_pos

func _on_lmb_up(screen_pos: Vector2, additive: bool) -> void:
	if not _pressing:
		return
	_pressing = false
	_get_overlay().queue_redraw()   # clear the box

	if _drag_active:
		_drag_active = false
		_do_box_select(additive)
	else:
		_do_point_select(screen_pos, additive)

# ── Selection logic ───────────────────────────────────────────────────────────

func _do_point_select(screen_pos: Vector2, additive: bool) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var hit       : Node = null

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
	# Build a world-space rect from the two screen-space corners
	var rect_screen := Rect2(_press_screen, _drag_end - _press_screen).abs()

	if not additive:
		_deselect_all()

	if units_layer:
		for unit in units_layer.get_children():
			if not unit.has_method("set_selected"):
				continue
			var unit_screen := _world_to_screen(unit.position)
			if rect_screen.has_point(unit_screen):
				_select_unit(unit)

func _select_unit(unit: Node) -> void:
	if unit in selected_units:
		return
	selected_units.append(unit)
	unit.set_selected(true)
	# Clean up if the unit dies
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

func _on_unit_died(unit: Node) -> void:
	selected_units.erase(unit)

func _issue_move_order(screen_pos: Vector2) -> void:
	var world_target := _screen_to_world(screen_pos)
	var count        := selected_units.size()
	# Spread units in a small grid so they don't all pile on the same pixel.
	# Row width: up to 4 units side by side, 32px apart.
	const SPACING    := 32.0
	const ROW_WIDTH  := 4
	for i in range(count):
		var unit : Node = selected_units[i]
		if not is_instance_valid(unit):
			continue
		var col    := i % ROW_WIDTH
		var row    := i / ROW_WIDTH
		var offset := Vector2(
			(col - (min(count, ROW_WIDTH) - 1) * 0.5) * SPACING,
			row * SPACING
		)
		unit.move_to(world_target + offset)

	# Show move-order ping at the click position
	_get_overlay().show_ping(screen_pos)

# ── Coordinate helpers ────────────────────────────────────────────────────────

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

# ── Overlay accessor ──────────────────────────────────────────────────────────

func _get_overlay() -> Node:
	return get_node("Overlay/Draw")

# ── Public ────────────────────────────────────────────────────────────────────

func get_selected() -> Array:
	return selected_units
