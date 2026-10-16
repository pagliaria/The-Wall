extends "res://scripts/enemy_base.gd"
# Fast flying melee attacker that lunges as it strikes.

@export var attack_damage : int = 5
@export var attack_rate : float = 1.5
@export var engage_range : float = 44.0
@export var lunge_distance : float = 36.0
@export var lunge_time : float = 0.18

func _ready() -> void:
	max_hp = 20
	move_speed = 100.0
	super._ready()

func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if _sprite.sprite_frames.has_animation("attack1"):
		_sprite.play("attack1")
	if is_instance_valid(_target):
		var direction := position.direction_to(_target.position)
		if direction != Vector2.ZERO:
			var tween := create_tween()
			tween.tween_property(self, "position", position + direction * lunge_distance, lunge_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "attack1":
		await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite):
		return
	if is_instance_valid(_target) and _target.hp > 0:
		CombatAudio.play(_get_attack_sound())
		_target.take_damage(attack_damage, self)
	if _sprite.animation == "attack1":
		_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_battle_state() -> void:
	if _sprite.sprite_frames.has_animation("move"):
		_sprite.play("move")
