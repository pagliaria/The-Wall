# training_target.gd
extends StaticBody2D

signal target_destroyed(target: Node)
signal health_changed(current: int, max: int)
signal spawning_complete

# Configuration
var config_id   : String = "basic"  # "basic" or "combat"
var is_active   : bool   = true
var target_name : String = "Training Dummy"

# Health configuration (overridable per instance)
const BASE_BASIC_HP           : int   = 100
const BASE_COMBAT_HP          : int   = 500
const DAMAGE_REDUCTION_BASIC  : float = 0.5
const DAMAGE_REDUCTION_COMBAT : float = 0.3

# Damage output for combat dummies (can attack back if equipped)
const BASIC_DAMAGE_OUTPUT  : float = 10.0
const COMBAT_DAMAGE_OUTPUT : float = 25.0

# State
var current_hp          : int   = 0
var max_hp              : int   = 0
var damage_taken_today  : int   = 0
var hits_this_session   : int   = 0
var damage_output       : float = BASIC_DAMAGE_OUTPUT
var damage_reduction    : float = DAMAGE_REDUCTION_BASIC

@onready var _sprite           : AnimatedSprite2D = $Sprite2D
@onready var _collision_shape  : CollisionShape2D   = $CollisionShape2D
@onready var _area_hit         : Area2D             = $AreaHit
@onready var _selection_circle : Node2D             = $SelectionCircle
@onready var _combat_numbers   : Node2D             = $DamageNumbers
@onready var _health_bar       : Control            = $HealthBar
@onready var _hp_fill          : Control            = $HealthBar/Background/Fill

# Damage callback for chaining effects (e.g., XP on hit, healing)
var damage_callback : Callable

var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

# =========================================
# INITIALIZATION & SETUP
# =========================================
func _ready() -> void:
	_rng.randomize()
	_setup_initial_config()
	_area_hit.body_entered.connect(_on_attack_attempt)
	add_to_group("training_targets")
	_sprite.play("default")
	if config_id == "combat":
		_sprite.scale   = Vector2(.4, .4)
		_sprite.z_index = 6
	else:
		_sprite.scale   = Vector2(.5, .5)
		_sprite.z_index = 5

func _setup_initial_config() -> void:
	match config_id:
		"basic":
			target_name  = "Training Dummy"
			max_hp       = BASE_BASIC_HP
			current_hp   = max_hp
		"combat":
			target_name  = "Combat Dummy"
			max_hp       = BASE_COMBAT_HP
			current_hp   = max_hp

	damage_reduction = DAMAGE_REDUCTION_BASIC  if config_id == "basic" else DAMAGE_REDUCTION_COMBAT
	damage_output    = BASIC_DAMAGE_OUTPUT     if config_id == "basic" else COMBAT_DAMAGE_OUTPUT

# =========================================
# CONFIGURATION & SPAWN POSITION
# =========================================
func setup(p_config_id: String, p_position: Vector2, config_overrides: Dictionary) -> void:
	config_id = p_config_id
	position  = p_position
	if p_config_id == "basic":
		_setup_basic_dummy(config_overrides)
	else:
		_setup_combat_dummy(config_overrides)

func _setup_basic_dummy(overrides: Dictionary) -> void:
	max_hp     = BASE_BASIC_HP + int(overrides.get("max_hp", 0)) if overrides and overrides.get("max_hp", 0) > 0 else BASE_BASIC_HP
	current_hp = max_hp

func _setup_combat_dummy(overrides: Dictionary) -> void:
	max_hp     = BASE_COMBAT_HP + int(overrides.get("max_hp", 0)) if overrides and overrides.get("max_hp", 0) > 0 else BASE_COMBAT_HP
	current_hp = max_hp

func spawn_at(location: Node2D) -> void:
	position          = location.global_position
	is_active         = true
	damage_taken_today = 0
	hits_this_session = 0
	current_hp        = max_hp
	emit_signal("spawning_complete")

# =========================================
# SPAWN POSITION CALCULATIONS (Town Area)
# =========================================
const TILE_SIZE      := 64
const MAP_COLS       := 48
const MAP_ROWS       := 27
const WATER_ROWS     := 3
const COL_TOWN_START := 20

func _generate_basic_spawn_positions() -> Array:
	var positions : Array = []
	var cols : int = int(MAP_COLS - COL_TOWN_START - 5)
	var rows : int = int(MAP_ROWS - WATER_ROWS - 10)

	for c in range(cols):
		for r in range(rows):
			var x : float = float((COL_TOWN_START + 3 + c) * TILE_SIZE)
			var y : float = float((WATER_ROWS + 5 + r) * TILE_SIZE)
			if is_valid_position(Vector2(x, y)):
				positions.append(Vector2(x, y))

	return positions if not positions.is_empty() else [Vector2(864.0, 736.0)]

func _generate_combat_spawn_positions() -> Array:
	var positions : Array = []
	var cols : int = int(MAP_COLS - COL_TOWN_START - 5)
	var rows : int = int(MAP_ROWS - WATER_ROWS - 8)

	for c in range(cols):
		for r in range(rows):
			var x : float = float((COL_TOWN_START + 7 + c) * TILE_SIZE)
			var y : float = float((WATER_ROWS + 3 + r) * TILE_SIZE)
			if is_valid_position(Vector2(x, y)):
				positions.append(Vector2(x, y))

	return positions if not positions.is_empty() else [Vector2(1040.0, 672.0)]

func is_valid_position(p_position: Vector2) -> bool:
	if p_position.x < float(COL_TOWN_START * TILE_SIZE) or p_position.x >= float(MAP_COLS * TILE_SIZE):
		return false
	if p_position.y < float(WATER_ROWS * TILE_SIZE) or p_position.y >= float(MAP_ROWS * TILE_SIZE):
		return false
	return true

func get_random_spawn_position(mode: String = "basic") -> Vector2:
	var positions : Array = []
	if mode == "basic":
		positions = _generate_basic_spawn_positions()
	else:
		positions = _generate_combat_spawn_positions()

	return positions[_rng.randi_range(0, positions.size() - 1)] if not positions.is_empty() else Vector2.ZERO


# =========================================
# DAMAGE HANDLING
# =========================================
func take_damage(amount: int, _attacker: Node = null) -> bool:
	if not is_active or current_hp <= 0:
		return false

	current_hp         -= amount
	damage_taken_today += amount
	hits_this_session  += 1

	flash_red()

	if is_instance_valid(_combat_numbers) and _combat_numbers.has_method("show_number"):
		_combat_numbers.show_number(global_position, amount, false)

	if config_id == "combat" or amount > 50:
		BloodFx.show_blood(global_position, amount)

	health_changed.emit(current_hp, max_hp)
	_update_hp_bar()

	if current_hp <= 0:
		on_target_destroyed()

	return true

# =========================================
# ATTACK HANDLING (if target can attack back)
# =========================================
func _on_attack_attempt(body: Node) -> void:
	if config_id == "combat":
		if body.has_method("take_damage"):
			body.take_damage(int(calculate_damage(body)), self)
		return

	# Basic dummies: just absorb the hit (take_damage called by attacker directly)

func calculate_damage(attacker: Node) -> float:
	var base : float = attacker.get("damage_output") if attacker.get("damage_output") != null else 0.0
	return base * (1.0 - damage_reduction) + 5.0

func get_attack_damage() -> float:
	return damage_output


# =========================================
# VISUAL EFFECTS
# =========================================
func _update_hp_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	var ratio : float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
	_health_bar.visible = ratio < 1.0
	if is_instance_valid(_hp_fill):
		_hp_fill.scale.x = ratio

func flash_red() -> void:
	if _sprite.is_playing() and _sprite.animation != "default":
		return
	var hit_anim : String = "hit" + str(_rng.randi_range(1, 3))
	_sprite.play(hit_anim)
	await _sprite.animation_finished
	if is_active:
		_sprite.play("default")

# =========================================
# DEATH HANDLING
# =========================================
func on_target_destroyed() -> void:
	is_active = false
	emit_signal("target_destroyed", self)
	queue_free()

# =========================================================================== #
#  SELECTION & UI INTEGRATION
# =========================================
var is_selected : bool = false
func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value

	if is_instance_valid(_selection_circle):
		_selection_circle.visible = value

	if value and current_hp > 0:
		_on_selected()

func _on_selected() -> void:
	pass

func get_display_name() -> String:
	return target_name + " (" + str(current_hp) + "/" + str(max_hp) + ")"

func is_valid_target() -> bool:
	return is_active and current_hp > 0


# =========================================
# BUILDING BONUS SUPPORT
# =========================================
var _building_bonuses : Dictionary = {
	"attack_damage":           0,
	"attack_speed_multiplier": 1.0,
	"move_speed_multiplier":   1.0,
	"hp_bonus":                0,
}

func apply_building_bonuses(bonuses: Dictionary) -> void:
	_building_bonuses["attack_damage"]           = int(bonuses.get("attack_damage", 0))
	_building_bonuses["attack_speed_multiplier"] = float(bonuses.get("attack_speed_multiplier", 1.0))
	_building_bonuses["move_speed_multiplier"]   = float(bonuses.get("move_speed_multiplier", 1.0))
	_building_bonuses["hp_bonus"]                = int(bonuses.get("hp_bonus", 0))

	var hp_bonus : int = int(bonuses.get("hp_bonus", 0))
	if hp_bonus > 0:
		max_hp     += hp_bonus
		current_hp  = min(current_hp, max_hp)
		_update_hp_bar()

func get_building_attack_damage_bonus() -> int:
	return int(_building_bonuses.get("attack_damage", 0))
