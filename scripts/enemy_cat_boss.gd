extends "res://scripts/enemy_base.gd"
# enemy_cat_boss.gd — Ranged magical enemy.

@export var melee_damage : int   = 5
@export var nade_damage : int   = 15
@export var range_damage : int   = 5
@export var attack_rate   : float = 1
@export var engage_range  : float = 1000
@export var melee_range  : float = 64
@export var nade_range  : float = 500

@onready var gun_timer = $gun_timer

var _attack_anim_flip : bool = false

func _ready() -> void:
	max_hp     = 500
	move_speed = 50.0
	super._ready()

# =========================================================================== #
#  Virtuals
# =========================================================================== #

func _get_engage_range() -> float:
	return engage_range

func _get_disengage_range() -> float:
	return engage_range * 10.0

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	pass

func _on_enter_idle_state() -> void:
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_sprite.play("run")

func _on_enter_attacking_state() -> void:
	pass

# =========================================================================== #
#  Attack
# =========================================================================== #

func _do_attack_tick(_delta: float) -> void:
	_play_attack_anim_and_fire()

func _play_attack_anim_and_fire() -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return

	_sprite.flip_h    = _target.global_position.x < global_position.x
		
	#Do different attacks based on range or randomness
	var dist := position.distance_to(_target.position)
	if dist < melee_range:
		_sprite.play("attack1")
		await _sprite.animation_finished
		_target.take_damage(melee_damage)
	elif dist < nade_range:
		_sprite.play("special")
		await _sprite.animation_finished
		_target.take_damage(nade_damage)
	elif dist < engage_range:
		_sprite.play("attack2")
		var total_frames = _sprite.sprite_frames.get_frame_count("attack2")
		var fps = _sprite.sprite_frames.get_animation_speed("attack2")
		var total_duration = total_frames / fps
		var shoot_time = total_duration / 3.0
	
		# Start timer and stop it after half the duration
		gun_timer.start()
		await get_tree().create_timer(shoot_time).timeout
		gun_timer.stop()
		await _sprite.animation_finished


func _on_gun_timer_timeout() -> void:
	_target.take_damage(range_damage)
