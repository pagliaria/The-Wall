extends Node2D

# GoldStone resource node
# Shows a static base sprite with an occasional animated shimmer on top.
# The highlight animation plays once every few seconds to simulate a glint.

const BASE_TEXTURE      = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png")
const HIGHLIGHT_TEXTURE = preload("res://assets/Terrain/Resources/Gold/Gold Stones/Gold Stone 3_Highlight.png")

const HIGHLIGHT_FRAMES = 6
const HIGHLIGHT_FPS    = 10.0

# Seconds between each glint — randomised per instance so they don't sync
const GLINT_INTERVAL_MIN = 2.0
const GLINT_INTERVAL_MAX = 6.0

@onready var highlight: AnimatedSprite2D = $Highlight

var _glint_timer := 0.0
var _next_glint  := 0.0

func _ready() -> void:
	_next_glint = randf_range(GLINT_INTERVAL_MIN, GLINT_INTERVAL_MAX)
	highlight.visible = false
	highlight.animation_finished.connect(_on_glint_finished)

func _process(delta: float) -> void:
	_glint_timer += delta
	if _glint_timer >= _next_glint and not highlight.is_playing():
		highlight.visible = true
		highlight.play("glint")
		_glint_timer = 0.0
		_next_glint  = randf_range(GLINT_INTERVAL_MIN, GLINT_INTERVAL_MAX)

func _on_glint_finished() -> void:
	highlight.visible = false
