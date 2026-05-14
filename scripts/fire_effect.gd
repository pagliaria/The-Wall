extends Node2D

# fire_effect.gd
# Spawned procedurally across the town during the game over sequence.

enum EffectType { FIRE, EXPLOSION, SMOKE }

const FIRE_TEXTURES : Array = [
	preload("res://assets/Particle FX/Fire_01.png"),
	preload("res://assets/Particle FX/Fire_02.png"),
	preload("res://assets/Particle FX/Fire_03.png"),
]
const EXPLOSION_TEXTURES : Array = [
	preload("res://assets/Particle FX/Explosion_01.png"),
	preload("res://assets/Particle FX/Explosion_02.png"),
]
const SMOKE_TEXTURES : Array = [
	preload("res://assets/Particle FX/Dust_01.png"),
	preload("res://assets/Particle FX/Dust_02.png"),
]

const EFFECT_FPS : float = 12.0

var _effect_type : EffectType       = EffectType.FIRE
var _sprite      : AnimatedSprite2D = null
var _loops       : int              = 0

func setup(type: int, loops: int = 0) -> void:
	_effect_type = type as EffectType
	_loops       = loops

func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)

	var tex    : Texture2D
	var do_loop : bool = _loops > 0

	match _effect_type:
		EffectType.FIRE:
			tex           = FIRE_TEXTURES[randi() % FIRE_TEXTURES.size()]
			_sprite.scale = Vector2(2.0, 2.0)
		EffectType.EXPLOSION:
			tex           = EXPLOSION_TEXTURES[randi() % EXPLOSION_TEXTURES.size()]
			_sprite.scale = Vector2(2.5, 2.5)
		EffectType.SMOKE:
			tex              = SMOKE_TEXTURES[randi() % SMOKE_TEXTURES.size()]
			_sprite.scale    = Vector2(2.0, 2.0)
			_sprite.modulate = Color(0.6, 0.6, 0.6, 0.7)

	# Auto-detect frame count: assume square frames on a single row
	var frame_h     : int = tex.get_height()
	var frame_w     : int = frame_h
	var frame_count : int = max(1, tex.get_width() / frame_w)

	_sprite.sprite_frames = _make_frames(tex, frame_count, frame_w, frame_h, do_loop)
	_sprite.play("anim")

	if not do_loop:
		_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()

func _make_frames(tex: Texture2D, frame_count: int, frame_w: int, frame_h: int, loop: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("anim")
	sf.set_animation_speed("anim", EFFECT_FPS)
	sf.set_animation_loop("anim", loop)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame("anim", atlas)
	return sf
