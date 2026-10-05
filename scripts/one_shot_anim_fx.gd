extends Node2D
# one_shot_anim_fx.gd — plays a single non-looping SpriteFrames animation once
# at its spawn position, then frees itself. Shared by hex_fizzle_fx.tscn (the
# "hit but nothing happened" fizzle) and pig_poof_fx.tscn (the transformation
# burst), so neither needs its own throwaway script.

@onready var _sprite : AnimatedSprite2D = $Sprite

func _ready() -> void:
	z_index = 12
	_sprite.animation_finished.connect(queue_free)
	_sprite.play()
