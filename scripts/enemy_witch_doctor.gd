extends "res://scripts/enemy_base.gd"
# enemy_witch_doctor.gd
# Ranged magical enemy. Immediately summons a skeleton on battle start,
# then re-summons every SUMMON_COOLDOWN seconds. Fires purple orbs between summons.

@export var attack_damage : int   = 2
@export var attack_rate   : float = 1.5
@export var engage_range  : float = 1000
@export var min_range     : float = 80.0

const ORB_SCENE      : PackedScene = preload("res://scenes/badger_orb.tscn")
const SKELETON_SCENE : PackedScene = preload("res://scenes/enemy_skeleton.tscn")
const SUMMON_COOLDOWN : float = 5.0

var _attack_anim_flip : bool  = false
var _retreating       : bool  = false
var _summon_timer     : float = 0.0
var _summoning        : bool  = false

func _ready() -> void:
	max_hp     = 28
	move_speed = 45.0
	super._ready()

# =========================================================================== #
#  Virtuals
# =========================================================================== #

func _get_engage_range()    -> float: return engage_range
func _get_disengage_range() -> float: return engage_range * 10.0
func _get_attack_rate()     -> float: return attack_rate
func _do_attack_hit()       -> void:  pass

func _do_attacking_move(delta: float) -> void:
	if not is_instance_valid(_target):
		_retreating = false
		return
	var dist : float = position.distance_to(_target.position)
	if dist < min_range:
		if not _retreating:
			_retreating = true
			_sprite.play("run")
		var away : Vector2 = (position - _target.position).normalized()
		_sprite.flip_h = away.x < 0
		move_and_collide(away * move_speed * delta)
	else:
		if _retreating:
			_retreating = false
			_sprite.play("idle")

func _on_enter_idle_state() -> void:
	_retreating = false
	_summoning  = false
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_retreating = false
	_summoning  = false
	if _sprite.sprite_frames.has_animation("run"):
		_sprite.play("run")
	else:
		_sprite.play("idle")

func _on_enter_attacking_state() -> void:
	# Immediately summon a skeleton on first engagement
	_summon_skeleton()
	_summon_timer = SUMMON_COOLDOWN
	_play_attack_anim_and_fire()

# =========================================================================== #
#  Physics — tick summon timer
# =========================================================================== #

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == State.ATTACKING or _state == State.BATTLE:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = SUMMON_COOLDOWN
			_do_summon_sequence()

# =========================================================================== #
#  Summon
# =========================================================================== #

func _do_summon_sequence() -> void:
	if _summoning or _state == State.DEAD:
		return
	_summoning = true
	_sprite.play("special" if _sprite.sprite_frames.has_animation("special") else "attack1")
	await _sprite.animation_finished
	if _state == State.DEAD:
		_summoning = false
		return
	_summon_skeleton()
	_summoning = false
	if _state != State.DEAD:
		_sprite.play("idle")

func _summon_skeleton() -> void:
	var wm : Node = get_tree().current_scene.get_node_or_null("WaveManager")
	if wm == null or not wm.has_method("register_enemy"):
		return
	if wm.get("_phase") != null and str(wm._phase) == "0":
		return  # not in battle phase
	var skeleton : CharacterBody2D = SKELETON_SCENE.instantiate()
	# Spawn near the witch doctor with a small random offset
	var rng    := RandomNumberGenerator.new()
	rng.randomize()
	var offset : Vector2 = Vector2(
		rng.randf_range(-60.0, 60.0),
		rng.randf_range(-40.0, 40.0)
	)
	skeleton.position = position + offset
	wm.register_enemy(skeleton)
	# Visual summon flash
	_sprite.modulate = Color(0.7, 0.3, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.4)

# =========================================================================== #
#  Attack — purple orbs
# =========================================================================== #

func _do_attack_tick(_delta: float) -> void:
	if _retreating or _summoning:
		return
	_play_attack_anim_and_fire()

func _play_attack_anim_and_fire() -> void:
	if _retreating or _summoning:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		return
	_sprite.flip_h    = _target.global_position.x < global_position.x
	_attack_anim_flip = not _attack_anim_flip
	var anim : String = "attack1" if _attack_anim_flip else "attack2"
	if not _sprite.sprite_frames.has_animation(anim):
		anim = "attack1"
	_sprite.play(anim)
	_fire_after_anim()

func _fire_after_anim() -> void:
	await _sprite.animation_finished
	if _state == State.DEAD or _retreating or _summoning:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		_sprite.play("idle")
		return
	_launch_orb()
	_sprite.play("idle")

func _launch_orb() -> void:
	if not is_instance_valid(_target):
		return
	var orb    : Area2D  = ORB_SCENE.instantiate()
	var offset : Vector2 = (_target.global_position - global_position).normalized() * 24.0
	get_tree().current_scene.add_child(orb)
	orb.init(_target, attack_damage, global_position + offset)
	# Recolor orb to purple
	orb.modulate = Color(0.8, 0.2, 1.0)
