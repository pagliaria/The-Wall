extends Node2D

# Draws:
#   1. The drag-selection rectangle in screen space.
#   2. A move-order ping ripple at the RMB click point (world space, converted to screen).
# Parent must be a CanvasLayer so it renders on top of everything.

# ── Ping tuning ───────────────────────────────────────────────────────────────
const PING_DURATION   := 0.55   # seconds the ripple lasts
const PING_RADIUS_MAX := 28.0   # px at full expansion
const PING_COLOR      := Color(0.3, 1.0, 0.45)   # green-ish to match valid placement

# ── Ping state ────────────────────────────────────────────────────────────────
var _ping_active  : bool    = false
var _ping_screen  : Vector2 = Vector2.ZERO   # screen-space position
var _ping_elapsed : float   = 0.0

# ── Called by unit_selection.gd when a move order is issued ──────────────────
func show_ping(screen_pos: Vector2) -> void:
	_ping_screen  = screen_pos
	_ping_elapsed = 0.0
	_ping_active  = true
	set_process(true)

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not _ping_active:
		return
	_ping_elapsed += delta
	if _ping_elapsed >= PING_DURATION:
		_ping_active = false
		set_process(false)
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_drag_box()
	if _ping_active:
		_draw_ping()

func _draw_drag_box() -> void:
	var sel : Node = get_parent().get_parent()   # Draw → Overlay → UnitSelection
	if not sel._pressing or not sel._drag_active:
		return
	var rect := Rect2(sel._press_screen, sel._drag_end - sel._press_screen).abs()
	draw_rect(rect, Color(0.3, 0.85, 1.0, 0.08), true)
	draw_rect(rect, Color(0.3, 0.85, 1.0, 0.70), false, 1.5)

func _draw_ping() -> void:
	# t goes 0 → 1 over the duration
	var t       := _ping_elapsed / PING_DURATION
	var ease_t  := 1.0 - pow(1.0 - t, 2.0)   # ease-out quad

	# Two concentric rings: one that grows outward, one slightly delayed
	_draw_ring(_ping_screen, ease_t, 0.0)
	if t > 0.15:
		_draw_ring(_ping_screen, (t - 0.15) / 0.85, 0.5)

func _draw_ring(center: Vector2, t: float, alpha_offset: float) -> void:
	var radius := PING_RADIUS_MAX * t
	var alpha  := (1.0 - t) * (1.0 - alpha_offset)
	if alpha <= 0.0:
		return
	var col := Color(PING_COLOR.r, PING_COLOR.g, PING_COLOR.b, alpha)
	draw_arc(center, radius, 0.0, TAU, 32, col, 2.0)

	# Small filled dot at the centre that fades quickly
	if t < 0.35:
		var dot_alpha := (1.0 - t / 0.35) * 0.9
		draw_circle(center, 4.0, Color(PING_COLOR.r, PING_COLOR.g, PING_COLOR.b, dot_alpha))
