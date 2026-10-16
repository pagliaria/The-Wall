extends "res://scripts/enemy_base.gd"
# Heavy boss troll. It telegraphs each ground slam with a long windup, then
# damages and knocks back every opposing unit close to the impact.

@export var attack_damage : int = 28
@export var splash_damage : int = 18
@export var slam_radius : float = 132.0
@export var attack_rate : float = 3.4
@export var engage_range : float = 82.0
@export var knockback_distance : float = 86.0
@export var knockback_time : float = 0.22

func _ready() -> void:
	max_hp = 650
	move_speed = 38.0
	super._ready()

func _get_engage_range() -> float:
	return engage_range

func _get_attack_rate() -> float:
	return attack_rate

func _on_enter_attacking_state() -> void:
	_attack_timer = 0.0

func _do_attack_tick(_delta: float) -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return
	_sprite.flip_h = _target.global_position.x < global_position.x
	if _sprite.sprite_frames.has_animation("windup"):
		_sprite.play("windup")

func _do_attack_hit() -> void:
	if not is_instance_valid(_target):
		return
	if _sprite.animation == "windup":
		await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite) or _state == State.DEAD:
		return
	if not is_instance_valid(_target) or _target.hp <= 0:
		_sprite.play("idle")
		return
	if _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		var frame_count := _sprite.sprite_frames.get_frame_count("attack")
		var fps := _sprite.sprite_frames.get_animation_speed("attack")
		await get_tree().create_timer(float(frame_count) / fps * 0.5).timeout
	if not is_instance_valid(self) or not is_instance_valid(_sprite) or _state == State.DEAD:
		return
	var impact_center := global_position
	CombatAudio.play(_get_attack_sound())
	for unit in _get_battle_targets():
		if not is_instance_valid(unit) or unit.hp <= 0:
			continue
		var distance := impact_center.distance_to(unit.global_position)
		if distance > slam_radius:
			continue
		unit.take_damage(attack_damage if unit == _target else splash_damage, self)
		if unit.hp > 0:
			var direction : Vector2 = (unit.global_position - impact_center).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT if not _sprite.flip_h else Vector2.LEFT
			var tween : Tween = unit.create_tween()
			tween.tween_property(unit, "global_position", unit.global_position + direction * knockback_distance, knockback_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _sprite.animation == "attack":
		await _sprite.animation_finished
	if not is_instance_valid(self) or not is_instance_valid(_sprite) or _state == State.DEAD:
		return
	if _sprite.sprite_frames.has_animation("recovery"):
		_sprite.play("recovery")
		await _sprite.animation_finished
	if is_instance_valid(self) and is_instance_valid(_sprite) and _state != State.DEAD:
		_sprite.play("idle")

func _on_enter_idle_state() -> void:
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_enter_battle_state() -> void:
	if _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")
