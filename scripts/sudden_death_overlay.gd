# sudden_death_overlay.gd
# Cosmetic only — no collision, no damage. Covers the battlefield (same rect
# battlefield_overlay.gd draws) with a drifting plague fog and a light rain of
# falling arrows while sudden death is active. Toggled by
# WaveManager.sudden_death_changed (active bool only — warning countdown is
# ignored here, banner handles that).
extends Node2D

const BATTLE_LEFT   : float = 0.0
const BATTLE_RIGHT  : float = 1280.0
const BATTLE_TOP    : float = 192.0
const BATTLE_BOTTOM : float = 1728.0

# ── Rain of arrows ───────────────────────────────────────────────────────────
const ARROW_TEXTURE    : Texture2D = preload("res://assets/Units/Black Units/Archer/Arrow.png")
const ARROW_SPAWN_RATE : float     = 0.12
const ARROW_FALL_TIME  : float     = 0.7

# ── Plague fog ────────────────────────────────────────────────────────────────
# Fog is a handful of big soft blobs (procedural radial-gradient texture, no
# image asset needed) that slowly drift and individually pulse alpha, so
# overlapping blobs give uneven, rolling density instead of one flat tint.
const FOG_BLOB_COUNT     : int   = 20
const FOG_BLOB_MIN_SCALE : float = 260.0
const FOG_BLOB_MAX_SCALE : float = 480.0
const FOG_DRIFT_SPEED    : float = 14.0   # px/sec, per blob
# Old range (0.05-0.22) with a grass-green tint was invisible in practice —
# blended straight into the battlefield floor and the existing zone-tint
# overlay. Pushed way up and shifted toward sickly purple-green for contrast.
const FOG_ALPHA_MIN      : float = 0.22
const FOG_ALPHA_MAX      : float = 0.55
const FOG_PULSE_SPEED    : float = 0.5    # radians/sec, per blob (own phase)
const FOG_COLOR          : Color = Color(0.40, 0.42, 0.34)
const FOG_TEXTURE_SIZE   : int   = 256
# Blobs wander outside the rect a bit before wrapping so drift never looks
# like it snaps at a hard edge.
const FOG_WRAP_MARGIN    : float = 200.0

var _active      : bool  = false
var _spawn_timer : float = 0.0
var _rng         := RandomNumberGenerator.new()

class FogBlob:
	var sprite : Sprite2D
	var vel    : Vector2
	var phase  : float

var _blobs : Array[FogBlob] = []

func _ready() -> void:
	_rng.randomize()
	visible = false
	_build_fog_blobs()

func _build_fog_blobs() -> void:
	var tex : Texture2D = _make_fog_texture()
	for i in FOG_BLOB_COUNT:
		var blob := FogBlob.new()
		blob.sprite = Sprite2D.new()
		blob.sprite.texture   = tex
		blob.sprite.modulate  = Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 0.0)
		blob.sprite.position  = Vector2(
			_rng.randf_range(BATTLE_LEFT, BATTLE_RIGHT),
			_rng.randf_range(BATTLE_TOP, BATTLE_BOTTOM)
		)
		var scale_amt : float = _rng.randf_range(FOG_BLOB_MIN_SCALE, FOG_BLOB_MAX_SCALE) / float(FOG_TEXTURE_SIZE)
		blob.sprite.scale = Vector2(scale_amt, scale_amt)
		var dir : float = _rng.randf_range(0.0, TAU)
		blob.vel   = Vector2(cos(dir), sin(dir)) * FOG_DRIFT_SPEED * _rng.randf_range(0.5, 1.0)
		blob.phase = _rng.randf_range(0.0, TAU)
		add_child(blob.sprite)
		_blobs.append(blob)

# Soft white circle fading to transparent at the edge — tinted per-blob via
# Sprite2D.modulate, so one shared texture works for every blob.
func _make_fog_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient  = gradient
	tex.width     = FOG_TEXTURE_SIZE
	tex.height    = FOG_TEXTURE_SIZE
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	return tex

# Bound to WaveManager.sudden_death_changed(active, seconds_left). Godot
# requires the callable's arg count to match the signal's, so seconds_left
# must be declared even though only active is used here.
func set_active(active: bool, _seconds_left: float = 0.0) -> void:
	if _active == active:
		return
	_active = active
	visible = active
	if active:
		_spawn_timer = 0.0
	else:
		for blob : FogBlob in _blobs:
			blob.sprite.modulate.a = 0.0

func _process(delta: float) -> void:
	if not _active:
		return
	_update_fog(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = ARROW_SPAWN_RATE
		_spawn_falling_arrow()

func _update_fog(delta: float) -> void:
	var t : float = float(Time.get_ticks_msec()) / 1000.0
	for blob : FogBlob in _blobs:
		blob.sprite.position += blob.vel * delta
		blob.sprite.position.x = _wrap(blob.sprite.position.x, BATTLE_LEFT, BATTLE_RIGHT)
		blob.sprite.position.y = _wrap(blob.sprite.position.y, BATTLE_TOP, BATTLE_BOTTOM)
		var pulse : float = (sin(t * FOG_PULSE_SPEED + blob.phase) + 1.0) * 0.5
		blob.sprite.modulate.a = lerpf(FOG_ALPHA_MIN, FOG_ALPHA_MAX, pulse)

# Wraps v into [min - FOG_WRAP_MARGIN, max + FOG_WRAP_MARGIN] so a blob drifts
# a bit past the battlefield edge before reappearing on the opposite side.
func _wrap(v: float, lo: float, hi: float) -> float:
	var lo_m : float = lo - FOG_WRAP_MARGIN
	var hi_m : float = hi + FOG_WRAP_MARGIN
	var span : float = hi_m - lo_m
	return lo_m + fposmod(v - lo_m, span)

func _spawn_falling_arrow() -> void:
	var x        : float = _rng.randf_range(BATTLE_LEFT + 20.0, BATTLE_RIGHT - 20.0)
	var end_y    : float = _rng.randf_range(BATTLE_TOP + 60.0, BATTLE_BOTTOM)
	var start_y  : float = BATTLE_TOP - 80.0

	var arrow : Sprite2D = Sprite2D.new()
	arrow.texture  = ARROW_TEXTURE
	arrow.scale    = Vector2(0.45, 0.45)
	arrow.rotation = deg_to_rad(100.0) + _rng.randf_range(-0.15, 0.15)
	arrow.position = Vector2(x, start_y)
	add_child(arrow)

	var dur : float = ARROW_FALL_TIME + _rng.randf_range(-0.1, 0.15)
	var tw  : Tween = create_tween()
	tw.tween_property(arrow, "position:y", end_y, dur).set_trans(Tween.TRANS_LINEAR)
	tw.parallel().tween_property(arrow, "modulate:a", 0.0, 0.15).set_delay(dur - 0.15)
	tw.tween_callback(arrow.queue_free)
