extends CharacterBody2D

# Pawn — a player unit spawned by a Castle.
# Currently: wanders near spawn point with idle/move states.
# Future: will respond to player commands, fight enemies, gather resources.
#
# NODE STRUCTURE (pawn.tscn):
#   Pawn (CharacterBody2D)   ← this script
#   ├── Sprite (AnimatedSprite2D)
#   └── Collision (CollisionShape2D)

signal died
signal selected_changed(is_selected: bool)

# ── Selection ─────────────────────────────────────────────────────────────────
var is_selected : bool = false

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	emit_signal("selected_changed", value)

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const IDLE_TIME_MIN  = 1.0
const IDLE_TIME_MAX  = 3.5
const MOVE_TIME_MIN  = 0.8
const MOVE_TIME_MAX  = 2.0
const MOVE_SPEED     = 35.0   # px/sec — slightly faster than sheep

# How far a pawn will wander from its spawn point
const WANDER_RADIUS  = 200.0

var max_hp    : int = 10
var hp        : int = 10

enum State { IDLE, MOVE }

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_dir    : Vector2 = Vector2.ZERO
var _spawn_pos   : Vector2 = Vector2.ZERO   # set on first frame
var _rng         := RandomNumberGenerator.new()

@onready var _sprite            : AnimatedSprite2D = $Sprite
@onready var _selection_circle  : Node2D           = $SelectionCircle

# ── Sprite sheet constants ────────────────────────────────────────────────────
const IDLE_TEX  = preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const RUN_TEX   = preload("res://assets/Units/Blue Units/Pawn/Pawn_Run.png")
# Tiny Swords unit sheets: 192×192 px per frame, 8 frames wide
const FRAME_W   = 192
const FRAME_H   = 192
const IDLE_FRAMES = 6   # Pawn_Idle has 6 frames
const RUN_FRAMES  = 8   # Pawn_Run  has 8 frames
const ANIM_FPS    = 8.0

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	_enter_state(State.MOVE)

func _physics_process(delta: float) -> void:
	_state_timer += delta
	if _state == State.MOVE:
		_do_move(delta)
	if _state_timer >= _state_dur:
		_enter_state(_pick_next_state())

# ── State machine ─────────────────────────────────────────────────────────────

func _pick_next_state() -> State:
	return State.MOVE if _rng.randf() > 0.45 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0
	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")
		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			# Pick a direction that trends back toward spawn if too far away
			var to_spawn  := _spawn_pos - position
			var dist      := to_spawn.length()
			var angle     := _rng.randf_range(-PI * 0.5, PI * 0.5)
			if dist > WANDER_RADIUS:
				# Bias strongly toward home
				_move_dir = to_spawn.normalized().rotated(angle * 0.3)
			else:
				_move_dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			_move_dir       = _move_dir.normalized()
			_sprite.flip_h  = _move_dir.x < 0
			_sprite.play("run")

func _do_move(delta: float) -> void:
	# Map boundary clamp
	var min_x := float((COL_TOWN_START + 1) * TILE_SIZE)
	var max_x := float((MAP_COLS - 2)       * TILE_SIZE)
	var min_y := float((WATER_ROWS + 1)     * TILE_SIZE)
	var max_y := float((MAP_ROWS - 2)       * TILE_SIZE)

	if position.x < min_x or position.x > max_x:
		_move_dir.x   *= -1.0
		_sprite.flip_h = _move_dir.x < 0
	if position.y < min_y or position.y > max_y:
		_move_dir.y *= -1.0

	var motion    := _move_dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		_move_dir      = _move_dir.bounce(collision.get_normal()).normalized()
		_sprite.flip_h = _move_dir.x < 0
		move_and_collide(_move_dir * MOVE_SPEED * delta)

# ── Combat / health ───────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	emit_signal("died")
	queue_free()
