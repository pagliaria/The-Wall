extends Node2D

# GoldStone behaviour — occasional one-shot glint on the highlight layer.

const GLINT_INTERVAL_MIN = 2.0
const GLINT_INTERVAL_MAX = 6.0

@onready var highlight: AnimatedSprite2D = $Highlight

var _glint_timer := 0.0
var _next_glint  := 0.0

func _ready() -> void:
	_next_glint       = randf_range(GLINT_INTERVAL_MIN, GLINT_INTERVAL_MAX)
	highlight.visible = false
	highlight.animation_finished.connect(_on_glint_finished)

func _process(delta: float) -> void:
	_glint_timer += delta
	if _glint_timer >= _next_glint and not highlight.is_playing():
		highlight.visible = true
		highlight.play("anim")
		_glint_timer = 0.0
		_next_glint  = randf_range(GLINT_INTERVAL_MIN, GLINT_INTERVAL_MAX)

func _on_glint_finished() -> void:
	highlight.visible = false
