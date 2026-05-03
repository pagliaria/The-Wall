extends Node2D

# Drawbridge controller for "The Wall"
# Animates between bridge_down (open/lowered) and bridge_up (raised/closed)
# Press B to toggle. Bridge starts raised (closed).

@onready var bridge_down   : Sprite2D        = $bridge_down
@onready var bridge_up     : Sprite2D        = $bridge_up
@onready var anim_player   : AnimationPlayer = $AnimationPlayer
@onready var bridge_collision   : CollisionShape2D = $Wall_Collision/bridge_collision

var _is_raised := true   # starts closed/raised

func _ready() -> void:
	# Initial state: bridge raised (closed), down sprite invisible
	bridge_up.modulate.a   = 1.0
	bridge_down.modulate.a = 0.0
	bridge_down.visible    = true   # keep both visible so animation can fade
	bridge_up.visible      = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_toggle()

func _toggle() -> void:
	if anim_player.is_playing():
		return
	if _is_raised:
		anim_player.play("lower")   # raised → lowered  (open the bridge)
		bridge_collision.disabled = true
	else:
		anim_player.play("raise")   # lowered → raised  (close the bridge)
		bridge_collision.disabled = false
	_is_raised = not _is_raised
