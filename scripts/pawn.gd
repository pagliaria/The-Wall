extends CharacterBody2D

# Pawn -- a player unit spawned by a Castle.
#
# NODE STRUCTURE (pawn.tscn):
#   Pawn (CharacterBody2D)   <- this script
#   |- Sprite (AnimatedSprite2D)
#   |- Collision (CollisionShape2D)
#   +- SelectionCircle (Node2D)

signal died
signal selected_changed(is_selected: bool)
# Emitted when a pawn delivers resources to the castle.
# main.gd listens to this to update the HUD.
signal resource_delivered(resource_type: String, amount: int)

# -- Selection ----------------------------------------------------------------
var is_selected : bool = false

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	emit_signal("selected_changed", value)

# -- Constants ----------------------------------------------------------------
const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const IDLE_TIME_MIN  = 1.0
const IDLE_TIME_MAX  = 3.5
const MOVE_TIME_MIN  = 0.8
const MOVE_TIME_MAX  = 2.0
const MOVE_SPEED     = 50.0
const PUSH_DISTANCE  = 10.0
const PUSH_SPEED     = 10.0
const WANDER_RADIUS  = 200.0
const ARRIVAL_RADIUS = 50.0

# -- Animation tool suffixes by resource type ---------------------------------
const ANIM_TOOL := {
	"gold": "gold",
	"wood": "axe",
	"meat": "meat",
}
const ANIM_INTERACT := {
	"gold": "interact_pickaxe",
	"wood": "interact_axe",
	"meat": "interact_knife",
}

# -- Health -------------------------------------------------------------------
var max_hp : int = 10
var hp     : int = 10

# -- State machine ------------------------------------------------------------
enum State { IDLE, MOVE, MOVE_TO, GATHER, EXTRACTING, RETURN }

var _state       : State   = State.IDLE
var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_dir    : Vector2 = Vector2.ZERO
var _move_target : Vector2 = Vector2.ZERO
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

# -- Push ---------------------------------------------------------------------
var _push_target     : Vector2 = Vector2.ZERO
var _is_being_pushed : bool    = false

# -- Gathering ----------------------------------------------------------------
# Set by gather_resource(); cleared when resource is depleted or task cancelled.
var _resource_node    : Node    = null   # the ResourceNode being gathered
var _extract_timer    : float   = 0.0   # counts up toward extract_time
var _carrying         : String  = ""    # resource type currently held ("" = empty-handed)
var _carrying_amount  : int     = 0     # always 1 for now; future: upgradeable

# Injected by castle.gd after spawning so the pawn knows where to return.
var home_position : Vector2 = Vector2.ZERO

# -- Node refs ----------------------------------------------------------------
@onready var _sprite           : AnimatedSprite2D = $Sprite
@onready var _selection_circle : Node2D           = $SelectionCircle

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	_enter_state(State.MOVE)

func _physics_process(delta: float) -> void:
	if _is_being_pushed:
		_do_push_step(delta)
		return

	_state_timer += delta

	match _state:
		State.MOVE:
			_do_move(delta)
			if _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_move_to_target(delta, _move_target, State.IDLE)
		State.IDLE:
			if _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.GATHER:
			_do_move_to_target(delta, _resource_node.world_position, State.EXTRACTING)
		State.EXTRACTING:
			_do_extracting(delta)
		State.RETURN:
			_do_move_to_target(delta, home_position, State.IDLE)

# =========================================================================== #
#  State transitions
# =========================================================================== #

func _pick_next_wander_state() -> State:
	return State.MOVE if _rng.randf() > 0.45 else State.IDLE

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
			# If carrying something, play the appropriate idle anim
			if _carrying != "":
				_sprite.play("idle_" + ANIM_TOOL[_carrying])
			else:
				_sprite.play("idle")
			# If we just returned home, deliver the goods
			if _carrying != "" and position.distance_to(home_position) < ARRIVAL_RADIUS * 3.0:
				_deliver()

		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			var to_spawn := _spawn_pos - position
			var dist     := to_spawn.length()
			var angle    := _rng.randf_range(-PI * 0.5, PI * 0.5)
			if dist > WANDER_RADIUS:
				_move_dir = to_spawn.normalized().rotated(angle * 0.3)
			else:
				_move_dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			_move_dir      = _move_dir.normalized()
			_sprite.flip_h = _move_dir.x < 0
			_sprite.play("run")

		State.MOVE_TO:
			_move_dir      = (_move_target - position).normalized()
			_sprite.flip_h = _move_dir.x < 0
			_sprite.play("run")

		State.GATHER:
			# Walk to the resource carrying nothing
			_move_dir      = (_resource_node.world_position - position).normalized()
			_sprite.flip_h = _move_dir.x < 0
			_sprite.play("run")

		State.EXTRACTING:
			_extract_timer = 0.0
			var interact_anim : String = ANIM_INTERACT.get(_resource_node.resource_type, "interact_axe")
			_sprite.play(interact_anim)

		State.RETURN:
			# Walk back to castle carrying the resource
			_move_dir      = (home_position - position).normalized()
			_sprite.flip_h = _move_dir.x < 0
			var tool_suffix : String = ANIM_TOOL.get(_carrying, "")
			_sprite.play("run_" + tool_suffix if tool_suffix != "" else "run")

# =========================================================================== #
#  Per-state logic
# =========================================================================== #

func _do_move_to_target(delta: float, target: Vector2, on_arrive: State) -> void:
	if position.distance_to(target) <= ARRIVAL_RADIUS:
		_enter_state(on_arrive)
		return
	_move_dir      = (target - position).normalized()
	_sprite.flip_h = _move_dir.x < 0
	var motion    := _move_dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		var collider := collision.get_collider()
		if collider != null and collider != self and collider.has_method("request_push"):
			collider.request_push(_move_dir, PUSH_DISTANCE, position)
			move_and_collide(motion)
		else:
			_move_dir = _move_dir.bounce(collision.get_normal()).normalized()
			move_and_collide(_move_dir * MOVE_SPEED * delta)

func _do_extracting(delta: float) -> void:
	# Sanity: if resource was freed under us, abort
	if not is_instance_valid(_resource_node) or _resource_node.is_depleted():
		_abort_gather()
		return

	_extract_timer += delta
	if _extract_timer < _resource_node.extract_time:
		return

	# One chunk extracted
	var got : String = _resource_node.extract_one(self)
	if got == "":
		# Someone else depleted it just now
		_abort_gather()
		return

	_carrying        = got
	_carrying_amount = 1
	_resource_node.unregister_gatherer(self)
	_enter_state(State.RETURN)

func _do_move(delta: float) -> void:
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

# =========================================================================== #
#  Delivery
# =========================================================================== #

func _deliver() -> void:
	if _carrying == "":
		return
	emit_signal("resource_delivered", _carrying, _carrying_amount)
	_carrying        = ""
	_carrying_amount = 0

	# If the resource still has stock, go back for another round
	if is_instance_valid(_resource_node) and not _resource_node.is_depleted():
		if _resource_node.register_gatherer(self):
			_enter_state(State.GATHER)
			return

	# Resource gone or full — go idle and forget the task
	_resource_node = null
	_enter_state(State.IDLE)

# =========================================================================== #
#  Public API
# =========================================================================== #

# Called by unit_selection.gd when the player RMB-clicks a resource
func gather_resource(resource_node: Node) -> void:
	# Cancel any previous task cleanly
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node   = resource_node
	_carrying        = ""
	_carrying_amount = 0
	if _resource_node.register_gatherer(self):
		_enter_state(State.GATHER)

# Called by ResourceNode when the resource runs out mid-gather
func on_resource_depleted() -> void:
	_abort_gather()

func _abort_gather() -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node   = null
	_carrying        = ""
	_carrying_amount = 0
	_enter_state(State.IDLE)

# Standard move order (used by unit_selection for plain RMB on ground)
func move_to(target: Vector2) -> void:
	# Cancel any gather task first
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node = null
	_move_target   = target
	_enter_state(State.MOVE_TO)

func request_push(direction: Vector2, distance: float, requester_pos: Vector2 = Vector2.ZERO) -> void:
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		return
	var side_a    := Vector2(-forward.y, forward.x)
	var side_b    := -side_a
	var preferred := side_a
	if requester_pos != Vector2.ZERO:
		var to_self := position - requester_pos
		if to_self.dot(side_b) > to_self.dot(side_a):
			preferred = side_b
	_push_target     = position + preferred * distance
	_is_being_pushed = true

func _do_push_step(delta: float) -> void:
	var to_target := _push_target - position
	if to_target.length() <= 2.0:
		position         = _push_target
		_is_being_pushed = false
		return
	var step := to_target.normalized() * PUSH_SPEED * delta
	if step.length() > to_target.length():
		step = to_target
	var collision := move_and_collide(step)
	if collision:
		_is_being_pushed = false

# -- Combat / health ----------------------------------------------------------

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	emit_signal("died")
	queue_free()
