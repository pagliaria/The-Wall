# pawn.gd
# Player worker unit spawned by a Castle. Gathers resources and returns them.
#
# NODE STRUCTURE (pawn.tscn):
#   Pawn (CharacterBody2D)
#   |- Sprite (AnimatedSprite2D)
#   |- Collision (CollisionShape2D)
#   |- SelectionCircle (Node2D)
#   +- NavAgent (NavigationAgent2D)
extends "res://scripts/unit_base.gd"

signal resource_delivered(resource_type: String, amount: int)

# =========================================================================== #
#  Constants
# =========================================================================== #

const MOVE_SPEED    = 50.0
const WANDER_RADIUS = 160.0
const ARRIVAL_RADIUS = 12.0

# Animation mappings keyed by resource type
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

const IMPACT_SOUND := {
	"gold": "impact_gold",
	"wood": "impact_wood",
	"meat": "impact_meat",
}

# =========================================================================== #
#  State machine
# =========================================================================== #

enum State { IDLE, MOVE, MOVE_TO, GATHER, EXTRACTING, RETURN }

var _state     : State  = State.IDLE
var _move_dir  : Vector2 = Vector2.ZERO

# =========================================================================== #
#  Gathering
# =========================================================================== #

var _resource_node   : Node   = null
var _resource_body   : Node   = null
var _extract_timer   : float  = 0.0
var _carrying        : String = ""
var _carrying_amount : int    = 0
var _carrying_sound  : String = ""

var home_radius : float = 28.0

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _on_unit_ready() -> void:
	max_hp = 10
	hp     = 10
	_sprite.frame_changed.connect(_on_frame_changed)
	_enter_state(State.MOVE)

func _process_state(delta: float) -> void:
	match _state:
		State.MOVE:
			_do_nav_move(delta, MOVE_SPEED)
			if _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.MOVE_TO:
			_do_nav_move(delta, MOVE_SPEED)
			if _nav_agent.is_navigation_finished():
				_enter_state(State.IDLE)
		State.IDLE:
			_apply_separation(delta)
			if not has_moved and _state_timer >= _state_dur:
				_enter_state(_pick_next_wander_state())
		State.GATHER:
			_do_nav_move_to_body(
				delta,
				_resource_body,
				_resource_node.interact_position,
				_resource_node.interact_radius,
				State.EXTRACTING
			)
		State.EXTRACTING:
			_do_extracting(delta)
		State.RETURN:
			_do_nav_move_to_body(delta, home_node, home_position, home_radius, State.IDLE)

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
			var to_spawn   := _spawn_pos - position
			var dist       := to_spawn.length()
			var angle      := _rng.randf_range(-PI * 0.5, PI * 0.5)
			var wander_dir : Vector2
			if dist > WANDER_RADIUS:
				wander_dir = to_spawn.normalized().rotated(angle * 0.3)
			else:
				wander_dir = Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
			var wander_dist   := _rng.randf_range(64.0, WANDER_RADIUS)
			var raw_target    := position + wander_dir.normalized() * wander_dist
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
			_nav_agent.target_position = _resource_node.interact_position
			var dir : Vector2 = _resource_node.interact_position - position
			_sprite.flip_h = dir.x < 0
			_sprite.play(GATHER_TOOL.get(_resource_node.resource_type, "run"))
		State.EXTRACTING:
			_extract_timer = 0.0
			_carrying_sound = IMPACT_SOUND.get(_resource_node.resource_type, "")
			_sprite.play(ANIM_INTERACT.get(_resource_node.resource_type, "interact_axe"))
		State.RETURN:
			_nav_agent.target_position = home_position
			var dir := home_position - position
			_sprite.flip_h = dir.x < 0
			_sprite.play("run_" + _carrying if _carrying != "" else "run")

# =========================================================================== #
#  Navigation helpers (pawn-specific: body-targeted movement)
# =========================================================================== #

func _do_nav_move_to_body(delta: float, target_body: Node, target_pos: Vector2, arrival_radius: float, on_arrive: State) -> void:
	has_moved = true
	_nav_agent.target_position = target_pos

	if position.distance_to(target_pos) <= arrival_radius:
		_enter_state(on_arrive)
		return

	if _nav_agent.is_navigation_finished():
		if position.distance_to(target_pos) <= arrival_radius:
			_enter_state(on_arrive)
		return

	var next_point := _nav_agent.get_next_path_position()
	_move_dir      = (next_point - position).normalized()
	_sprite.flip_h = _move_dir.x < 0
	var collision  := move_and_collide(_move_dir * MOVE_SPEED * delta)
	if collision:
		var collider := collision.get_collider()
		if target_body != null and _is_target(collider, target_body):
			_enter_state(on_arrive)
			return
	_apply_separation(delta)

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

func _on_frame_changed() -> void:
	if _state != State.EXTRACTING or _carrying_sound == "":
		return
	var anim      : String = _sprite.animation
	var last_frame : int   = _sprite.sprite_frames.get_frame_count(anim) - 1
	if _sprite.frame == last_frame:
		CombatAudio.play(_carrying_sound)

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
	CombatAudio.play(_carrying)
	emit_signal("resource_delivered", _carrying, _carrying_amount)
	_carrying        = ""
	_carrying_amount = 0
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
	if _state == State.RETURN:
		return
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node   = resource_node
	_resource_body   = resource_body
	_carrying        = ""
	_carrying_amount = 0
	if _resource_node.register_gatherer(self):
		CombatAudio.play("gather")
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
	_carrying_sound  = ""
	_enter_state(State.IDLE)

# =========================================================================== #
#  Base overrides
# =========================================================================== #

func _on_move_to() -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	_resource_node = null
	_resource_body = null
	_enter_state(State.MOVE_TO)

func _on_end_battle() -> void:
	_enter_state(State.IDLE)

func _on_die() -> void:
	if is_instance_valid(_resource_node):
		_resource_node.unregister_gatherer(self)
	super._on_die()
