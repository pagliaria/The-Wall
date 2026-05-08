# unit_base.gd
# Base class for all player-controlled units.
# Subclasses override _process_state() and _enter_state() for their own
# state machines, and define their own `enum State` + unique constants.
extends CharacterBody2D

# =========================================================================== #
#  Signals
# =========================================================================== #

signal died
signal selected_changed(is_selected: bool)

# =========================================================================== #
#  Selection / identity
# =========================================================================== #

var is_selected : bool   = false
var has_moved   : bool   = false
var faction     : String = "player"

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	emit_signal("selected_changed", value)

# =========================================================================== #
#  Map constants (shared by all units)
# =========================================================================== #

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const WANDER_MIN_X := float((COL_TOWN_START + 1) * TILE_SIZE)
const WANDER_MAX_X := float((MAP_COLS - 2)        * TILE_SIZE)
const WANDER_MIN_Y := float((WATER_ROWS + 1)      * TILE_SIZE)
const WANDER_MAX_Y := float((MAP_ROWS - 2)        * TILE_SIZE)

# =========================================================================== #
#  Shared timing constants
# =========================================================================== #

const IDLE_TIME_MIN = 1.5
const IDLE_TIME_MAX = 4.0
const MOVE_TIME_MIN = 1.0
const MOVE_TIME_MAX = 2.5
const STUCK_TIMEOUT = 5.0

# =========================================================================== #
#  Separation
# =========================================================================== #

const SEPARATION_RADIUS := 50.0
const SEPARATION_FORCE  := 5.0

# =========================================================================== #
#  Health
# =========================================================================== #

const HP_FILL_FULL_SCALE_X := 1.3

var max_hp : int = 10
var hp     : int = 10

# =========================================================================== #
#  State machine (generic fields — subclass defines its own enum State)
# =========================================================================== #

var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_target : Vector2 = Vector2.ZERO
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

# =========================================================================== #
#  Home (set by spawning building)
# =========================================================================== #

var home_position : Vector2 = Vector2.ZERO
var home_node     : Node    = null

# =========================================================================== #
#  Node refs
# =========================================================================== #

@onready var _sprite           : AnimatedSprite2D  = $Sprite
@onready var _selection_circle : Node2D            = $SelectionCircle
@onready var _nav_agent        : NavigationAgent2D = $NavAgent
@onready var _hp_bar           : Control           = $HpBar
@onready var _hp_fill          : TextureRect       = $HpBar/health

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	call_deferred("_on_unit_ready")

# Override in subclass to run deferred setup (e.g. call_deferred enter_state).
func _on_unit_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	_state_timer += delta
	_process_state(delta)

# Override in subclass to drive the state machine.
func _process_state(_delta: float) -> void:
	pass

# =========================================================================== #
#  Navigation
# =========================================================================== #

# Move along the nav path. Call _apply_separation() each frame automatically.
func _do_nav_move(delta: float, move_speed: float) -> void:
	has_moved = true
	if _nav_agent.is_navigation_finished():
		_apply_separation(delta)
		return
	var next_point := _nav_agent.get_next_path_position()
	var move_dir   := (next_point - position).normalized()
	_sprite.flip_h  = move_dir.x < 0
	move_and_collide(move_dir * move_speed * delta)
	_apply_separation(delta)

# Soft repulsion from nearby CharacterBody2D siblings.
func _apply_separation(delta: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sep := Vector2.ZERO
	for sibling in parent.get_children():
		if sibling == self or not sibling is CharacterBody2D:
			continue
		var diff : Vector2 = position - sibling.position
		var dist := diff.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			sep += diff.normalized() * (SEPARATION_RADIUS - dist)
	if sep != Vector2.ZERO:
		move_and_collide(sep.normalized() * SEPARATION_FORCE * delta)

# =========================================================================== #
#  Public API
# =========================================================================== #

func move_to(target: Vector2) -> void:
	_move_target = target
	_on_move_to()

# Override to handle move_to in the subclass state machine.
func _on_move_to() -> void:
	pass

func end_battle() -> void:
	_on_end_battle()

# Override to return to idle after a wave ends.
func _on_end_battle() -> void:
	pass

# =========================================================================== #
#  Health
# =========================================================================== #

func take_damage(amount: int) -> void:
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		_on_die()

func receive_heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	_update_hp_bar()

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.visible = ratio < 1.0
	_hp_fill.scale.x = HP_FILL_FULL_SCALE_X * ratio

func die() -> void:
	emit_signal("died")
	print("freeing")
	queue_free()

# Override for cleanup before queue_free (e.g. pawn unregisters from resource).
func _on_die() -> void:
	if _sprite.sprite_frames.has_animation("death"):
		print("death")
		_sprite.play("death")
		await _sprite.animation_finished
		print("death finish")
		die()
	else:
		die()
