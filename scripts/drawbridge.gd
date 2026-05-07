extends Node2D

# Drawbridge controller for "The Wall"
# Animates between bridge_down (open/lowered) and bridge_up (raised/closed).
# Press B to toggle manually. Bridge starts lowered (open).
# WaveManager calls force_raise() / force_lower() at wave start/end.

@onready var bridge_down       : Sprite2D          = $bridge_down
@onready var bridge_up         : Sprite2D          = $bridge_up
@onready var anim_player       : AnimationPlayer   = $AnimationPlayer
@onready var bridge_collision  : CollisionShape2D  = $Wall_Collision/bridge_collision

var _is_raised := false

func _ready() -> void:
	bridge_up.modulate.a   = 0.0
	bridge_down.modulate.a = 1.0
	bridge_down.visible    = true
	bridge_up.visible      = true
	bridge_collision.disabled = true

func force_raise() -> void:
	if _is_raised:
		return
	_do_raise()

func force_lower() -> void:
	if not _is_raised:
		return
	_do_lower()

func _do_raise() -> void:
	anim_player.play("raise")
	bridge_collision.disabled = false
	_is_raised = true

func _do_lower() -> void:
	anim_player.play("lower")
	bridge_collision.disabled = true
	_is_raised = false
