extends CharacterBody2D

# Sheep behaviour — state machine with idle, graze, and move states.
# The sheep wanders within the town zone, occasionally stopping to eat or rest.
#
# NODE STRUCTURE (sheep.tscn):
#   Sheep (CharacterBody2D)  ← this script
#   ├── Sprite (AnimatedSprite2D)
#   └── Collision (CollisionShape2D)  — small circle at foot level
#
# COLLISION:
#   Uses Godot's built-in physics. move_and_collide() handles bouncing off any
#   StaticBody2D in the scene — tree stumps, future buildings, walls, etc.
#   No manual obstacle lists needed.
#
# Z index is fixed at Z_UNITS (3) — set by resource_spawner.gd at spawn.

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const IDLE_TIME_MIN  = 1.5
const IDLE_TIME_MAX  = 4.0
const GRAZE_TIME_MIN = 2.0
const GRAZE_TIME_MAX = 5.0
const MOVE_TIME_MIN  = 1.0
const MOVE_TIME_MAX  = 2.5

const MOVE_SPEED     = 25.0   # px/sec

enum State { IDLE, GRAZE, MOVE , DEAD}

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_dir    : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

@onready var _sprite : AnimatedSprite2D = $Sprite

func _ready() -> void:
	_rng.randomize()
	#_enter_state(_pick_random_state())

func die():
	_enter_state(State.DEAD)

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_state_timer += delta
	if _state == State.MOVE:
		_do_move(delta)
	if _state_timer >= _state_dur:
		_enter_state(_pick_random_state())

func _pick_random_state() -> State:
	var r := _rng.randf()
	if r < 0.4:   return State.IDLE
	elif r < 0.8: return State.GRAZE
	else:         return State.MOVE

func _enter_state(new_state: State) -> void:
	if _state == State.DEAD:
		return
	_state       = new_state
	_state_timer = 0.0
	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			_sprite.play("idle")
		State.GRAZE:
			_state_dur = _rng.randf_range(GRAZE_TIME_MIN, GRAZE_TIME_MAX)
			_sprite.play("graze")
		State.MOVE:
			_state_dur  = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var angle   := _rng.randf_range(-PI * 0.4, PI * 0.4)
			var sign_x  := 1.0 if _rng.randf() > 0.5 else -1.0
			_move_dir    = Vector2(cos(angle) * sign_x, sin(angle)).normalized()
			_sprite.flip_h = _move_dir.x < 0
			_sprite.play("move")
		State.DEAD:
			_sprite.scale = Vector2(.3,.3)
			_sprite.play("death")

func _do_move(delta: float) -> void:
	# ─ Map boundary bounce ───────────────────────────────────────────────────
	var min_x := (COL_TOWN_START + 1) * TILE_SIZE + TILE_SIZE * 0.5
	var max_x := (MAP_COLS - 2)       * TILE_SIZE + TILE_SIZE * 0.5
	var min_y := (WATER_ROWS + 1)     * TILE_SIZE + TILE_SIZE * 0.5
	var max_y := (MAP_ROWS - 2)       * TILE_SIZE + TILE_SIZE * 0.5

	if position.x < min_x or position.x > max_x:
		_move_dir.x    *= -1.0
		_sprite.flip_h  = _move_dir.x < 0
	if position.y < min_y or position.y > max_y:
		_move_dir.y *= -1.0

	# ─ Physics move — collides with any StaticBody2D automatically ───────────
	var motion    := _move_dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		# Reflect off whatever surface was hit and keep moving.
		_move_dir      = _move_dir.bounce(collision.get_normal()).normalized()
		_sprite.flip_h = _move_dir.x < 0
		move_and_collide(_move_dir * MOVE_SPEED * delta)
		
	get_node("ResourceNode").world_position = global_position
