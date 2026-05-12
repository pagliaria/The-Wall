# unit_base.gd
extends CharacterBody2D

signal died
signal selected_changed(is_selected: bool)

var is_selected : bool   = false
var has_moved   : bool   = false
var faction     : String = "player"

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value
	if value:
		_on_selected()
	emit_signal("selected_changed", value)

func _on_selected() -> void:
	pass

const TILE_SIZE      = 64
const MAP_COLS       = 48
const MAP_ROWS       = 27
const WATER_ROWS     = 3
const COL_TOWN_START = 20

const WANDER_MIN_X := float((COL_TOWN_START + 1) * TILE_SIZE)
const WANDER_MAX_X := float((MAP_COLS - 2)        * TILE_SIZE)
const WANDER_MIN_Y := float((WATER_ROWS + 1)      * TILE_SIZE)
const WANDER_MAX_Y := float((MAP_ROWS - 2)        * TILE_SIZE)

const IDLE_TIME_MIN = 1.5
const IDLE_TIME_MAX = 4.0
const MOVE_TIME_MIN = 1.0
const MOVE_TIME_MAX = 2.5
const STUCK_TIMEOUT = 5.0

const SEPARATION_RADIUS := 50.0
const SEPARATION_FORCE  := 5.0

const HP_FILL_FULL_SCALE_X := 1.3

var max_hp : int = 10
var hp     : int = 10
var _building_bonuses := {
	"attack_damage": 0,
	"attack_speed_multiplier": 1.0,
	"move_speed_multiplier": 1.0,
	"hp_bonus": 0,
	"range_bonus": 0.0,
	"gather_speed_multiplier": 1.0,
	"turn_in_bonus": 0,
}

var _state_timer : float   = 0.0
var _state_dur   : float   = 0.0
var _move_target : Vector2 = Vector2.ZERO
var _spawn_pos   : Vector2 = Vector2.ZERO
var _rng         := RandomNumberGenerator.new()

var home_position : Vector2 = Vector2.ZERO
var home_node     : Node    = null

@onready var _sprite           : AnimatedSprite2D  = $Sprite
@onready var _selection_circle : Node2D            = $SelectionCircle
@onready var _nav_agent        : NavigationAgent2D = $NavAgent
@onready var _hp_bar           : Control           = $HpBar
@onready var _hp_fill          : TextureRect       = $HpBar/health
@onready var wave_manager := get_tree().current_scene.get_node_or_null("WaveManager")

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	call_deferred("_on_unit_ready")

func _on_unit_ready() -> void:
	pass

func _get_base_max_hp() -> int:
	return 10

func _physics_process(delta: float) -> void:
	_state_timer += delta
	_process_state(delta)

func _process_state(_delta: float) -> void:
	pass

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

func move_to(target: Vector2) -> void:
	_move_target = target
	_on_move_to()

func _on_move_to() -> void:
	pass

func end_battle() -> void:
	_on_end_battle()

func _on_end_battle() -> void:
	pass

func apply_building_bonuses(bonuses: Dictionary) -> void:
	_building_bonuses["attack_damage"] = int(bonuses.get("attack_damage", 0))
	_building_bonuses["attack_speed_multiplier"] = float(bonuses.get("attack_speed_multiplier", 1.0))
	_building_bonuses["move_speed_multiplier"] = float(bonuses.get("move_speed_multiplier", 1.0))
	_building_bonuses["hp_bonus"] = int(bonuses.get("hp_bonus", 0))
	_building_bonuses["range_bonus"] = float(bonuses.get("range_bonus", 0.0))
	_building_bonuses["gather_speed_multiplier"] = float(bonuses.get("gather_speed_multiplier", 1.0))
	_building_bonuses["turn_in_bonus"] = int(bonuses.get("turn_in_bonus", 0))

	var old_max_hp := max_hp
	max_hp = _get_base_max_hp() + get_building_hp_bonus()
	if hp > 0:
		if old_max_hp <= 0:
			hp = max_hp
		else:
			hp = mini(hp + (max_hp - old_max_hp), max_hp)
	_update_hp_bar()

func get_building_attack_damage_bonus() -> int:
	return int(_building_bonuses.get("attack_damage", 0))

func get_building_attack_speed_multiplier() -> float:
	return float(_building_bonuses.get("attack_speed_multiplier", 1.0))

func get_building_move_speed_multiplier() -> float:
	return float(_building_bonuses.get("move_speed_multiplier", 1.0))

func get_building_hp_bonus() -> int:
	return int(_building_bonuses.get("hp_bonus", 0))

func get_building_range_bonus() -> float:
	return float(_building_bonuses.get("range_bonus", 0.0))

func get_building_gather_speed_multiplier() -> float:
	return float(_building_bonuses.get("gather_speed_multiplier", 1.0))

func get_building_turn_in_bonus() -> int:
	return int(_building_bonuses.get("turn_in_bonus", 0))

func take_damage(amount: int) -> void:
	CombatAudio.play("hurt")
	flash_red()
	hp -= amount
	_update_hp_bar()
	CombatNumbers.show_number(global_position, amount, false)
	if hp <= 0:
		_on_die()

func flash_red() -> void:
	var original_mod = _sprite.modulate
	_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	_sprite.modulate = original_mod
	if _sprite.modulate == Color.RED:
		_sprite.modulate = Color.WHITE

func receive_heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	_update_hp_bar()
	CombatNumbers.show_number(global_position, amount, true)

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar):
		return
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.visible = ratio < 1.0
	_hp_fill.scale.x = HP_FILL_FULL_SCALE_X * ratio

func die() -> void:
	emit_signal("died")
	queue_free()

func _on_die() -> void:
	var anim_name : String = "death"
	if _sprite.sprite_frames.has_animation(anim_name):
		CombatAudio.play("death")
		_sprite.play(anim_name)
		var frames         := _sprite.sprite_frames.get_frame_count(anim_name)
		var fps            := _sprite.sprite_frames.get_animation_speed(anim_name)
		var total_duration := frames / fps
		await get_tree().create_timer(total_duration).timeout
		die()
	else:
		die()
