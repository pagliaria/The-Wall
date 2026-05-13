# heal_effect.gd
extends Node2D

@onready var _sprite : AnimatedSprite2D = $Sprite

# healer: unit that cast this — receives XP for healing done
func init(target: Node, amount: int, is_heal: bool, healer: Node = null) -> void:
	CombatAudio.play("buff")
	if is_instance_valid(target):
		if is_heal and target.has_method("receive_heal"):
			target.receive_heal(amount, healer)
		elif not is_heal and target.has_method("take_damage"):
			target.take_damage(amount, healer)
	modulate = Color(0.4, 1.0, 0.4) if is_heal else Color(1.0, 0.3, 0.3)

func _ready() -> void:
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("play")
