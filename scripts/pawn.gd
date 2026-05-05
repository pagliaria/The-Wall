extends CharacterBody2D

# Pawn -- a player unit spawned by a Castle.
#
# NODE STRUCTURE (pawn.tscn):
#   Pawn (CharacterBody2D)   <- this script
#   |- Sprite (AnimatedSprite2D)
#   |- Collision (CollisionShape2D)
#   |- SelectionCircle (Node2D)
#   +- NavAgent (NavigationAgent2D)

signal died
signal selected_changed(is_selected: bool)
signal resource_delivered(resource_type: String, amount: int)

# -- Selection ----------------------------------------------------------------
var is_selected : bool = false
var has_moved   : bool = false

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

const IDLE_TIME_MIN = 1.0
const IDLE_TIME_MAX = 3.5
const MOVE_TIME_MIN = 0.8
const MOVE_TIME_MAX = 2.0
const MOVE_SPEED    = 50.0
const PUSH_DISTANCE = 50.0
const PUSH_SPEED    = 100.0
const WANDER_RADIUS = 200.0
const ARRIVAL_RADIUS = 12.0  # used only for plain MOVE_TO (ground clicks)

const STUCK_TIMEOUT = 5.0
# Wander bounds (world space) — nav mesh keeps us inside, but we also
# clamp the random target so we never pick a point in water or enemy wilds.
const WANDER_MIN_X := float((COL_TOWN_START + 1) * TILE_SIZE)
const WANDER_MAX_X := float((MAP_COLS - 2)       * TILE_SIZE)
const WANDER_MIN_Y := float((WATER_ROWS + 1)     * TILE_SIZE)
const WANDER_MAX_Y := float((MAP_ROWS - 2)       * TILE_SIZE)

# -- Animation mappings -------------------------------------------------------
const ANIM_TOOL := {
	"gold": "gold",
	"wood": "axe",
	"meat": "knife",
}
const GATHER_TOOL := {
	"gold": "run_pickaxe",
	"wood": "run_axe",
	"meat": "run_knife",
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
var _move_target : Vector2 = Vector2.ZERO  # final destination for MOVE_TO
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

var _previous_pos : Vector2 = Vector2.ZERO

# -- Push ---------------------------------------------------------------------
var _push_target     : Vector2 = Vector2.ZERO
var _is_being_pushed : bool    = false

# -- Gathering ----------------------------------------------------------------
var _resource_node   : Node   = null  # ResourceNode script instance
var _resource_body   : Node   = null  # the StaticBody2D the pawn will physically touch
var _extract_timer   : float  = 0.0
var _carrying        : String = ""
var _carrying_amount : int    = 0

# Injected by castle.gd — the PlacedBuilding StaticBody2D node itself
var home_position : Vector2 = Vector2.ZERO
var home_node     : Node    = null

# -- Node refs ----------------------------------------------------------------
@onready var _sprite           : AnimatedSprite2D  = $Sprite
@onready var _selection_circle : Node2D            = $SelectionCircle
@onready var _nav_agent        : NavigationAgent2D = $NavAgent

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	# Nav mesh isn't ready on the first frame; defer the first state entry.
	call_deferred("_enter_state", State.MOVE)

func _physics_process(delta: float) -> void:
	if _is_being_pushed:
		_do_push_step(delta)
		return

	_state_timer += delta

	match _state:
		State.MOVE:
			_do_nav_move(delta)
			if _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			# stuck....go into idle state
			if _state_timer >= _state_dur and _previous_pos == position:
				_enter_state(State.IDLE)
			_do_nav_move(delta)
			# Final arrival: close enough to the click target
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
			#if position.distance_to(_move_target) <= ARRIVAL_RADIUS:
				#_enter_state(State.IDLE)
		State.IDLE:
			if !has_moved and _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.GATHER:
			_do_nav_move_to_body(delta, _resource_body, _resource_node.world_position, State.EXTRACTING)
		State.EXTRACTING:
			_do_extracting(delta)
		State.RETURN:
			_do_nav_move_to_body(delta, home_node, home_position, State.IDLE)

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
			_sprite.play("idle_" + ANIM_TOOL[_carrying] if _carrying != "" else "idle")
			if _carrying != "":
				_deliver()

		State.MOVE:
			_state_dur = _rng.randf_range(MOVE_TIME_MIN, MOVE_TIME_MAX)
			# Pick a random wander destination, biased back toward spawn
			var to_spawn := _spawn_pos - position
			var dist     := to_spawn.length()
			var angle    := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var wander_dir : Vector2
			if dist > WANDER_RADIUS:
				wander_dir = to_spawn.normalized().rotated(angle * 0.3)
			else:
				wander_dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var wander_dist := _rng.randf_range(64.0, WANDER_RADIUS)
			var raw_target  := position + wander_dir.normalized() * wander_dist
			var wander_target := Vector2(
				clampf(raw_target.x, WANDER_MIN_X, WANDER_MAX_X),
				clampf(raw_target.y, WANDER_MIN_Y, WANDER_MAX_Y)
			)
			_nav_agent.target_position = wander_target
			_sprite.play("run")

		State.MOVE_TO:
			_state_dur = STUCK_TIMEOUT
			_nav_agent.target_position = _move_target
			_sprite.flip_h = (_move_target - position).x < 0
			_sprite.play("run")

		State.GATHER:
			_nav_agent.target_position = _resource_node.world_position
			var dir : Vector2 = (_resource_node.world_position - position)
			_sprite.flip_h = dir.x < 0
			_sprite.play(GATHER_TOOL.get(_resource_node.resource_type, "run"))

		State.EXTRACTING:
			_extract_timer = 0.0
			_sprite.play(ANIM_INTERACT.get(_resource_node.resource_type, "interact_axe"))

		State.RETURN:
			_nav_agent.target_position = home_position
			var dir := (home_position - position)
			_sprite.flip_h = dir.x < 0
			_sprite.play("run_" + _carrying if _carrying != "" else "run")

# =========================================================================== #
#  Navigation movement helpers
# =========================================================================== #

# General nav-steered movement. Moves along the computed path each frame.
# Flips sprite and calls move_and_collide toward the next path point.
func _do_nav_move(delta: float) -> void:
	if _state != State.MOVE:
		has_moved = true
	if _nav_agent.is_navigation_finished():
		return
	var next_point := _nav_agent.get_next_path_position()
	_move_dir      = (next_point - position).normalized()
	_sprite.flip_h = _move_dir.x < 0
	var motion := _move_dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		var collider := collision.get_collider()
		if collider != null and collider != self and collider.has_method("request_push"):
			collider.request_push(_move_dir, PUSH_DISTANCE, position)
			move_and_collide(motion)
		else:
			_move_dir = _move_dir.bounce(collision.get_normal()).normalized()
			move_and_collide(_move_dir * MOVE_SPEED * delta)
			
	# save off position so we can see if we are stuck
	_previous_pos = position

# Nav-steered movement toward a physics body. Uses nav for steering, but
# treats an actual collision with the target body as the arrival signal.
# Also refreshes the nav target each frame so it tracks moving targets (sheep).
func _do_nav_move_to_body(delta: float, target_body: Node, target_pos: Vector2, on_arrive: State) -> void:
	has_moved = true
	# Keep the nav target fresh (important for moving resources like sheep)
	_nav_agent.target_position = target_pos

	if _nav_agent.is_navigation_finished():
		# Nav says we're there — confirm with a generous distance check
		if position.distance_to(target_pos) <= 48.0:
			_enter_state(on_arrive)
		return

	var next_point := _nav_agent.get_next_path_position()
	_move_dir      = (next_point - position).normalized()
	_sprite.flip_h = _move_dir.x < 0
	var motion    := _move_dir * MOVE_SPEED * delta
	var collision := move_and_collide(motion)
	if collision:
		var collider := collision.get_collider()
		# Collision-based arrival: physically touching the target body
		if target_body != null and _is_target(collider, target_body):
			_enter_state(on_arrive)
			return
		if collider != null and collider != self and collider.has_method("request_push"):
			collider.request_push(_move_dir, PUSH_DISTANCE, position)
			move_and_collide(motion)
		else:
			_move_dir = _move_dir.bounce(collision.get_normal()).normalized()
			move_and_collide(_move_dir * MOVE_SPEED * delta)

# Checks collider and its parent chain so children of the target body also match.
func _is_target(collider: Node, target: Node) -> bool:
	if collider == null or target == null:
		return false
	var node := collider
	while node != null:
		if node == target:
			return true
		node = node.get_parent()
	return false

# =========================================================================== #
#  Extracting
# =========================================================================== #

func _do_extracting(delta: float) -> void:
	if not is_instance_valid(_resource_node) or _resource_node.is_depleted():
		_abort_gather()
		return
	_extract_timer += delta
	if _extract_timer < _resource_node.extract_time:
		return
	var got : String = _resource_node.extract_one(self)
	if got == "":
		_abort_gather()
		return
	_carrying        = got
	_carrying_amount = 1
	if _resource_node:
		_resource_node.unregister_gatherer(self)
	_enter_state(State.RETURN)

# =========================================================================== #
#  Delivery
# =========================================================================== #

func _deliver() -> void:
	if _carrying == "":
		return
	emit_signal("resource_delivered", _carrying, _carrying_amount)
	_carrying        = ""
	_carrying_amount = 0
	# Loop back if resource still has stock
	if is_instance_valid(_resource_node) and not _resource_node.is_depleted():
		if _resource_node.register_gatherer(self):
			_enter_state(State.GATHER)
			return
	_resource_node = null
	_resource_body = null
	_enter_state(State.IDLE)

# =========================================================================== #
#  Public API
# =========================================================================== #

func gather_resource(resource_node: Node, resource_body: Node) -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node   = resource_node
	_resource_body   = resource_body
	_carrying        = ""
	_carrying_amount = 0
	if _resource_node.register_gatherer(self):
		_enter_state(State.GATHER)

func on_resource_depleted() -> void:
	_abort_gather()

func _abort_gather() -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node   = null
	_resource_body   = null
	_carrying        = ""
	_carrying_amount = 0
	_enter_state(State.IDLE)

func move_to(target: Vector2) -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node = null
	_resource_body = null
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
