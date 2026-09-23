# unit_base.gd
extends CharacterBody2D

signal died
signal selected_changed(is_selected: bool)
signal leveled_up(new_level: int)

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

const SEPARATION_RADIUS    := 50.0
const SEPARATION_FORCE     := 5.0
const HP_FILL_FULL_SCALE_X := 1.3

const MAX_LEVEL   : int   = 5
const XP_BASE     : float = 100.0
const XP_EXPONENT : float = 1.4
const XP_PER_HEAL : float = 2.0

var xp    : int = 0
var level : int = 1

func _get_level_up_stats() -> Dictionary:
	return {}

func xp_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(XP_BASE * pow(level, XP_EXPONENT))

func grant_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	if _get_level_up_stats().is_empty():
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		_do_level_up()

func _do_level_up() -> void:
	level += 1
	_apply_level_stats()
	if is_instance_valid(_badge):
		_badge.refresh(level)
	_play_level_up_effect()
	CombatNumbers.show_number(global_position, level, false, true)
	emit_signal("leveled_up", level)

# Fast-forwards a freshly spawned unit straight to target_level, applying every
# level's stat gains via the normal path (_apply_level_stats) but skipping the
# per-level fanfare (VFX/floating number/badge refresh) that _do_level_up()
# plays — firing that N times in a row on spawn would look and sound wrong.
# Used for mirroring another player's leveled units in as enemies.
func set_level_directly(target_level: int) -> void:
	target_level = clampi(target_level, 1, MAX_LEVEL)
	while level < target_level:
		level += 1
		_apply_level_stats()
	if is_instance_valid(_badge):
		_badge.refresh(level)

func _apply_level_stats() -> void:
	var stats := _get_level_up_stats()
	if stats.is_empty():
		return
	var hp_gain : int = int(stats.get("hp", 0))
	_level_hp_bonus += hp_gain
	_recalc_max_hp()
	_on_level_up_stats(stats)

func _on_level_up_stats(_stats: Dictionary) -> void:
	pass

func _play_level_up_effect() -> void:
	var effect := Node2D.new()
	effect.set_script(load("res://scripts/level_up_effect.gd"))
	# Must be in the scene tree before play() calls get_tree()
	get_tree().current_scene.add_child(effect)
	effect.play(global_position)

var max_hp : int = 10
var hp     : int = 10
# Total HP gained from leveling up so far — tracked separately so it survives
# a later building-bonus recalculation instead of getting overwritten by it.
var _level_hp_bonus : int = 0
const MAX_ITEMS     : int  = 3
var _item_bonuses   : Dictionary = {}
var _equipped_items : Array      = []  # Array of {type, rarity, stats, name}

func _init_item_bonuses() -> void:
	_item_bonuses = {
		"attack_damage":           0,
		"attack_speed_multiplier": 1.0,
		"move_speed_multiplier":   1.0,
		"hp_bonus":                0,
		"range_bonus":             0.0,
	}

func can_equip_item(item: Node) -> bool:
	if _equipped_items.size() >= MAX_ITEMS:
		return false
	# No duplicate item types
	var item_type : int = int(item.get("item_type"))
	for equipped in _equipped_items:
		if int(equipped["type"]) == item_type:
			return false
	return true

func apply_item(item: Node) -> void:
	if not can_equip_item(item):
		return
	var s : Dictionary = item.stats
	_item_bonuses["attack_damage"]           += int(s.get("attack_damage", 0))
	_item_bonuses["hp_bonus"]                += int(s.get("hp_bonus", 0))
	_item_bonuses["range_bonus"]             += float(s.get("range_bonus", 0.0))
	var spd_bonus : float = float(s.get("attack_speed_multiplier", 0.0))
	if spd_bonus != 0.0:
		_item_bonuses["attack_speed_multiplier"] += spd_bonus
	var mv_bonus : float = float(s.get("move_speed_multiplier", 0.0))
	if mv_bonus != 0.0:
		_item_bonuses["move_speed_multiplier"] += mv_bonus
	var hp_gain : int = int(s.get("hp_bonus", 0))
	if hp_gain > 0:
		_recalc_max_hp()
	# Track equipped item
	_equipped_items.append({
		"type":   int(item.get("item_type")),
		"rarity": int(item.get("rarity")),
		"stats":  s.duplicate(),
		"name":   item.call("_get_display_name") if item.has_method("_get_display_name") else "Item",
	})
	# Show primary stat as combat number
	var show_val : int = 0
	if s.has("attack_damage"): show_val = int(s["attack_damage"])
	elif s.has("hp_bonus"):    show_val = int(s["hp_bonus"])
	elif s.has("range_bonus"): show_val = int(s["range_bonus"])
	else:                       show_val = 1
	CombatNumbers.show_number(global_position, show_val, true, false)

func remove_item(index: int) -> void:
	if index < 0 or index >= _equipped_items.size():
		return
	var equipped : Dictionary = _equipped_items[index]
	var s        : Dictionary = equipped["stats"]
	# Reverse all bonuses
	_item_bonuses["attack_damage"]           -= int(s.get("attack_damage", 0))
	_item_bonuses["hp_bonus"]                -= int(s.get("hp_bonus", 0))
	_item_bonuses["range_bonus"]             -= float(s.get("range_bonus", 0.0))
	var spd_bonus : float = float(s.get("attack_speed_multiplier", 0.0))
	if spd_bonus != 0.0:
		_item_bonuses["attack_speed_multiplier"] -= spd_bonus
	var mv_bonus : float = float(s.get("move_speed_multiplier", 0.0))
	if mv_bonus != 0.0:
		_item_bonuses["move_speed_multiplier"] -= mv_bonus
	# Reverse HP if applicable
	var hp_loss : int = int(s.get("hp_bonus", 0))
	if hp_loss > 0:
		_recalc_max_hp()
	_equipped_items.remove_at(index)

func get_item_attack_damage_bonus()     -> int:   return int(_item_bonuses.get("attack_damage", 0))
func get_item_attack_speed_multiplier() -> float: return float(_item_bonuses.get("attack_speed_multiplier", 1.0))
func get_item_move_speed_multiplier()   -> float: return float(_item_bonuses.get("move_speed_multiplier", 1.0))
func get_item_range_bonus()             -> float: return float(_item_bonuses.get("range_bonus", 0.0))

# Single source of truth for max_hp: base + every level-up + every equipped
# item's hp_bonus + the current building hp_bonus, all added together.
# Call this any time one of those inputs changes instead of touching max_hp
# directly, so no source can ever clobber another's contribution.
func _recalc_max_hp() -> void:
	var old_max_hp : int = max_hp
	max_hp = maxi(1, _get_base_max_hp() + _level_hp_bonus + int(_item_bonuses.get("hp_bonus", 0)) + get_building_hp_bonus())
	if old_max_hp > 0:
		hp = mini(hp + (max_hp - old_max_hp), max_hp)
	else:
		hp = max_hp
	_update_hp_bar()

var _building_bonuses := {
	"attack_damage": 0,
	"attack_speed_multiplier": 1.0,
	"move_speed_multiplier": 1.0,
	"hp_bonus": 0,
	"range_bonus": 0.0,
	"gather_speed_multiplier": 1.0,
	"turn_in_bonus": 0,
}

var _state_timer  : float   = 0.0
var _state_dur    : float   = 0.0
var _move_target  : Vector2 = Vector2.ZERO
var _spawn_pos    : Vector2 = Vector2.ZERO
var _rng          := RandomNumberGenerator.new()

var home_position : Vector2 = Vector2.ZERO
var home_node     : Node    = null

@onready var _sprite           : AnimatedSprite2D  = $Sprite
@onready var _selection_circle : Node2D            = $SelectionCircle
@onready var _nav_agent        : NavigationAgent2D = $NavAgent
@onready var _hp_bar           : Control           = $HpBar
@onready var _hp_fill          : TextureRect       = $HpBar/health
@onready var wave_manager := get_tree().current_scene.get_node_or_null("WaveManager")

const LEVEL_BADGE_SCENE := preload("res://scenes/level_badge.tscn")
var _badge : Node2D = null

const HP_FILL_BLUE : Texture2D = preload("res://assets/UI Elements/UI Elements/Bars/SmallBar_Fill_blue.png")

func _ready() -> void:
	_rng.randomize()
	_spawn_pos = position
	_badge     = LEVEL_BADGE_SCENE.instantiate()
	add_child(_badge)
	# Only real player-owned units join this group — a unit_base subclass spawned
	# as a mirrored hostile "enemy" (faction == "enemy") must never show up here,
	# or item drag-and-drop would let the attacking player equip loot onto it.
	if faction == "player":
		add_to_group("player_units")
	_init_item_bonuses()
	_hp_fill.texture = HP_FILL_BLUE
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
	# After battle, seek nearest training dummy if one exists
	var dummy : Node = _find_training_target()
	if dummy != null:
		start_training(dummy)

func _on_end_battle() -> void:
	pass

func _find_training_target() -> Node:
	var best     : Node  = null
	var best_dist: float = INF
	for t in get_tree().get_nodes_in_group("training_targets"):
		if not is_instance_valid(t):
			continue
		var active = t.get("is_active")
		if active == null or not active:
			continue
		var d : float = position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best      = t
	return best

func start_training(dummy: Node) -> void:
	_on_start_training(dummy)

func _on_start_training(_dummy: Node) -> void:
	pass

# Shared melee training loop — warrior and lancer call this from _do_training
func _do_training_melee(delta: float, dummy: Node, attack_rate: float, melee_range: float, get_dmg: Callable, get_spd: Callable) -> Node:
	# Returns updated dummy (may have changed) or null if should idle
	if not is_instance_valid(dummy) or not dummy.get("is_active"):
		var next : Node = _find_training_target()
		if next != null:
			return next
		_enter_training_idle()
		return null
	var dist : float = position.distance_to(dummy.global_position)
	if dist <= melee_range:
		_sprite.flip_h = dummy.global_position.x < position.x
		var striking : bool = get("_is_striking")
		if striking:
			return dummy
		var timer : float = get("_attack_timer") - delta
		set("_attack_timer", timer)
		if timer > 0.0:
			return dummy
		set("_is_striking", true)
		set("_attack_timer", attack_rate)
		var sf     : SpriteFrames = _sprite.sprite_frames
		var has_a1 : bool = sf.has_animation("attack1")
		var has_a2 : bool = sf.has_animation("attack2")
		var anim   : String
		if has_a1 and has_a2:
			anim = "attack1" if _rng.randf() > 0.5 else "attack2"
		elif has_a1:
			anim = "attack1"
		elif has_a2:
			anim = "attack2"
		else:
			if is_instance_valid(dummy) and dummy.get("is_active"):
				var dmg : int = get_dmg.call()
				dummy.take_damage(dmg, self)
				grant_xp(int(dmg * 0.5))
			set("_is_striking", false)
			return dummy
		var frames   : int   = sf.get_frame_count(anim)
		var fps      : float = sf.get_animation_speed(anim)
		var anim_dur : float = frames / fps
		_sprite.speed_scale = maxf(1.0, anim_dur / attack_rate)
		_sprite.play(anim)
		await _sprite.animation_finished
		_sprite.speed_scale = 1.0
		if is_instance_valid(dummy) and dummy.get("is_active"):
			var dmg : int = get_dmg.call()
			dummy.take_damage(dmg, self)
			grant_xp(int(dmg * 0.5))
		if sf.has_animation("idle"):
			_sprite.play("idle")
		set("_is_striking", false)
	else:
		if _sprite.animation != "run":
			_sprite.play("run")
		_nav_agent.target_position = dummy.global_position
		_do_nav_move(delta, get_spd.call())
	return dummy if is_instance_valid(dummy) else null

func _enter_training_idle() -> void:
	pass  # overridden per unit to call _enter_state(State.IDLE)

func apply_building_bonuses(bonuses: Dictionary) -> void:
	_building_bonuses["attack_damage"]           = int(bonuses.get("attack_damage", 0))
	_building_bonuses["attack_speed_multiplier"] = float(bonuses.get("attack_speed_multiplier", 1.0))
	_building_bonuses["move_speed_multiplier"]   = float(bonuses.get("move_speed_multiplier", 1.0))
	_building_bonuses["hp_bonus"]                = int(bonuses.get("hp_bonus", 0))
	_building_bonuses["range_bonus"]             = float(bonuses.get("range_bonus", 0.0))
	_building_bonuses["gather_speed_multiplier"] = float(bonuses.get("gather_speed_multiplier", 1.0))
	_building_bonuses["turn_in_bonus"]           = int(bonuses.get("turn_in_bonus", 0))
	_recalc_max_hp()

func get_building_attack_damage_bonus()     -> int:   return int(_building_bonuses.get("attack_damage", 0))
func get_building_attack_speed_multiplier() -> float: return float(_building_bonuses.get("attack_speed_multiplier", 1.0))
func get_building_move_speed_multiplier()   -> float: return float(_building_bonuses.get("move_speed_multiplier", 1.0))
func get_building_hp_bonus()                -> int:   return int(_building_bonuses.get("hp_bonus", 0))
func get_building_range_bonus()             -> float: return float(_building_bonuses.get("range_bonus", 0.0))
func get_building_gather_speed_multiplier() -> float: return float(_building_bonuses.get("gather_speed_multiplier", 1.0))
func get_building_turn_in_bonus()           -> int:   return int(_building_bonuses.get("turn_in_bonus", 0))

# Fallback target list used when a subclass's own combat loop needs to
# self-refresh targets outside the normal start_battle/update_battle_target
# flow (e.g. after its current target dies mid-frame). Faction-aware so a
# mirrored hostile copy of a normally-friendly unit type (faction == "enemy")
# correctly falls back to the real player's units instead of accidentally
# pulling the NPC wave's own enemy roster.
# Alias so a mirrored hostile copy of a unit_base subclass (faction ==
# "enemy", sitting in wave_manager's _enemies list) responds correctly to the
# same update_target(...) call real enemy_base.gd enemies get every retarget
# tick. Subclasses only implement update_battle_target (the player-unit-side
# name) — this just forwards to whichever one the concrete unit defines.
func update_target(targets: Array) -> void:
	if has_method("update_battle_target"):
		call("update_battle_target", targets)

func _get_default_battle_targets() -> Array:
	if wave_manager == null:
		return []
	if faction == "player":
		# Real player unit — unchanged from original behavior, fight the NPC wave
		return wave_manager.get_enemies() if wave_manager.has_method("get_enemies") else []
	# faction == "enemy" (covers a mirrored hostile copy of what's normally a
	# player-side unit type) — fight the real attacking player's side instead
	var targets : Array = []
	if wave_manager.has_method("get_player_units"):
		targets.append_array(wave_manager.get_player_units())
	if wave_manager.has_method("get_hired_units"):
		targets.append_array(wave_manager.get_hired_units())
	return targets

# attacker is accepted for call-signature compatibility with enemy_base.gd's
# take_damage(amount, attacker) — a real player unit's attack code always
# passes itself as attacker, and now that a mirrored hostile unit_base-derived
# enemy can legitimately be on the receiving end of that same call, this needs
# to accept it too or the call fails outright. Deliberately unused otherwise:
# no XP-on-damage or friendly-fire logic here, just enough to not crash.
func take_damage(amount: int, _attacker: Node = null) -> void:
	CombatAudio.play("hurt")
	flash_red()
	hp -= amount
	_update_hp_bar()
	BloodFx.show_blood(global_position, amount)
	CombatNumbers.show_number(global_position, amount, false)
	if hp <= 0:
		_on_die()

func flash_red() -> void:
	var original_mod := _sprite.modulate
	_sprite.modulate  = Color.RED
	await get_tree().create_timer(0.1).timeout
	_sprite.modulate  = original_mod
	if _sprite.modulate == Color.RED:
		_sprite.modulate = Color.WHITE

func receive_heal(amount: int, healer: Node = null) -> void:
	hp = mini(hp + amount, max_hp)
	_update_hp_bar()
	CombatNumbers.show_number(global_position, amount, true)
	if healer != null and is_instance_valid(healer) and healer.has_method("grant_xp"):
		healer.grant_xp(int(amount * XP_PER_HEAL))

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_bar):
		return
	var ratio        := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.visible   = ratio < 1.0
	_hp_fill.scale.x  = HP_FILL_FULL_SCALE_X * ratio

func die() -> void:
	emit_signal("died")
	queue_free()

func _on_die() -> void:
	var anim_name := "death"
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
