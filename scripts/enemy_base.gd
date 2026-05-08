extends CharacterBody2D

# enemy_base.gd — Base class for all enemy unit types.

signal died

@export var max_hp        : int   = 18
@export var move_speed    : float = 55.0
@export var patrol_radius : float = 180.0
@export var idle_time_min : float = 1.5
@export var idle_time_max : float = 4.0
@export var move_time_min : float = 1.0
@export var move_time_max : float = 2.5

const SEPARATION_RADIUS := 50.0
const SEPARATION_FORCE  := 5.0

var faction : String = "enemy"
var hp      : int    = 0

enum State { IDLE, BATTLE, ATTACKING, DEAD }

var _state        : State   = State.IDLE
var _state_timer  : float   = 0.0
var _state_dur    : float   = 0.0
var _spawn_pos    : Vector2 = Vector2.ZERO
var _rng          := RandomNumberGenerator.new()
var _battle_ready : bool    = false   # set true once start_battle() is called

var _target       : Node  = null
var _attack_timer : float = 0.0

var _is_striking  : bool = false

@onready var _sprite  : AnimatedSprite2D  = $Sprite
@onready var _nav     : NavigationAgent2D = $NavAgent
@onready var _hp_bar  : Control           = $HpBar
@onready var _hp_fill : TextureRect       = $HpBar/health
@onready var wave_manager := get_tree().current_scene.get_node_or_null("WaveManager")

const HP_FILL_FULL_SCALE_X := 1.3

# =========================================================================== #
#  Lifecycle
# =========================================================================== #

func _ready() -> void:
	_rng.randomize()
	hp = max_hp
	_spawn_pos = position
	# Don't enter MILL yet — wait for start_battle() or a deferred mill start
	# so that wave_manager can call start_battle() before the first state runs.
	call_deferred("_initial_state")

func _initial_state() -> void:
	# If start_battle() already fired before this deferred call, stay in BATTLE.
	if _battle_ready:
		return
	_enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	_state_timer += delta

	match _state:
		State.IDLE:
			_apply_separation(delta)
			return

		State.BATTLE:
			_do_battle(delta)

		State.ATTACKING:
			if _is_striking and _sprite.is_playing() and _sprite.animation.contains("attack"):
				return
			else:
				_is_striking = false
			if not is_instance_valid(_target) or _target.hp <= 0:
				_target = null
				_enter_state(State.BATTLE)
				return
			if position.distance_to(_target.position) > _get_engage_range() * 1.6:
				_enter_state(State.BATTLE)
				return
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				print("striking")
				_is_striking = true
				_attack_timer = _get_attack_rate()
				_do_attack_hit()
				_do_attack_tick(delta)

# =========================================================================== #
#  State transitions
# =========================================================================== #

func _enter_state(new_state: State) -> void:
	_state       = new_state
	_state_timer = 0.0

	match _state:
		State.IDLE:
			_state_dur = _rng.randf_range(idle_time_min, idle_time_max)
			_on_enter_idle_state()

		State.BATTLE:
			_on_enter_battle_state()

		State.ATTACKING:
			_attack_timer = 0.0
			_on_enter_attacking_state()

		State.DEAD:
			_on_enter_dead_state()
			set_physics_process(false)

# =========================================================================== #
#  Battle logic
# =========================================================================== #

func start_battle(player_units: Array) -> void:
	_battle_ready = true
	_pick_target(player_units)
	_enter_state(State.BATTLE)

func update_target(player_units: Array) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_pick_target(player_units)

func _do_battle(delta: float) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		_target = null
		_enter_state(State.BATTLE)
		return

	var dist := position.distance_to(_target.position)
	if dist <= _get_engage_range():
		_enter_state(State.ATTACKING)
		return

	# Drive nav toward target every frame so it tracks movement
	_nav.target_position = _target.position
	_do_nav_move(delta)
	_move()

func _pick_target(units: Array) -> void:
	var best      : Node  = null
	var best_dist : float = INF
	for u in units:
		if not is_instance_valid(u) or u.hp <= 0:
			continue
		var d := position.distance_to(u.position)
		if d < best_dist:
			best_dist = d
			best = u
	_target = best

# =========================================================================== #
#  Navigation
# =========================================================================== #

func _do_nav_move(delta: float) -> void:
	if _state != State.BATTLE and _nav.is_navigation_finished():
		_apply_separation(delta)
		return

	var next   := _nav.get_next_path_position()
	var dir : Vector2
	if next.distance_to(position) < 2.0 and _target != null and is_instance_valid(_target):
		dir = (position.direction_to(_target.position))
	else:
		dir = (next - position).normalized()

	if dir == Vector2.ZERO:
		return

	_sprite.flip_h = dir.x < 0
	move_and_collide(dir * move_speed * delta)
	_apply_separation(delta)

# =========================================================================== #
#  Separation
# =========================================================================== #

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
#  Health
# =========================================================================== #

func take_damage(amount: int) -> void:
	flash_red()
	if _state == State.DEAD:
		return
	hp -= amount
	_update_hp_bar()
	if hp <= 0:
		_enter_state(State.DEAD)

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.visible = ratio < 1.0
	_hp_fill.scale.x = HP_FILL_FULL_SCALE_X * ratio

func die() -> void:
	_state = State.DEAD
	emit_signal("died")
	queue_free()

func _on_enter_dead_state() -> void:
	if _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		await _sprite.animation_finished
		die()
	else:
		die()

func flash_red():
	var original_mod = _sprite.modulate
	# Set the sprite's tint to red
	_sprite.modulate = Color.RED
	
	# Wait for a short duration (0.1 seconds)
	await get_tree().create_timer(0.1).timeout
	
	# Reset back to the original color (white)
	_sprite.modulate = original_mod

# =========================================================================== #
#  Virtual methods
# =========================================================================== #

func _move() -> void:
	print("DEFAULT move")
	pass

func _get_engage_range() -> float:
	print("DEFAULT engage range")
	return 48.0

func _get_attack_rate() -> float:
	print("DEFAULT attack rate")
	return 1.2

func _do_attack_hit() -> void:
	print("DEFAULT attack hit")
	if is_instance_valid(_target):
		_target.take_damage(4)

func _do_attack_tick(_delta: float) -> void:
	print("DEFAULT attack tick")
	pass

func _on_enter_idle_state() -> void:
	print("DEFAULT idle state")
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_mill_state() -> void:
	print("DEFAULT mill state")
	if _sprite.sprite_frames.has_animation("run"):
		_sprite.play("run")

func _on_enter_battle_state() -> void:
	print("DEFAULT battle state")
	if _sprite.sprite_frames.has_animation("run"):
		_sprite.play("run")

func _on_enter_attacking_state() -> void:
	print("DEFAULT attack state")
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")
