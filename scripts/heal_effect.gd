# heal_effect.gd
# Spawns on a target, plays the Heal_Effect animation once then frees itself.
# Green tint = heal, red tint = attack.
# Applies the effect (heal or damage) immediately on spawn via init().
extends Node2D

@onready var _sprite : AnimatedSprite2D = $Sprite

func init(target: Node, amount: int, is_heal: bool) -> void:
	CombatAudio.play("buff")
	if is_instance_valid(target):
		if is_heal and target.has_method("receive_heal"):
			target.receive_heal(amount)
		elif not is_heal and target.has_method("take_damage"):
			target.take_damage(amount)

	# Tint: green for heal, red for attack
	modulate = Color(0.4, 1.0, 0.4) if is_heal else Color(1.0, 0.3, 0.3)

func _ready() -> void:
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("play")
