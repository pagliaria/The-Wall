extends "res://scripts/enemy_base.gd"
# enemy_pengu_boss.gd — Ranged magical enemy.

@export var melee_damage : int   = 20
@export var ray_damage : int   = 10
@export var range_damage : int   = 10
@export var attack_rate   : float = 1
@export var engage_range  : float = 1000
@export var melee_range  : float = 64
@export var ray_range  : float = 500

var _attack_anim_flip : bool = false

func _ready() -> void:
	max_hp     = 500
	move_speed = 50.0
	super._ready()

# =========================================================================== #
#  Virtuals
# =========================================================================== #

func _get_engage_range() -> float:
	return engage_range

func _get_disengage_range() -> float:
	return engage_range * 10.0

func _get_attack_rate() -> float:
	return attack_rate

func _do_attack_hit() -> void:
	pass

func _on_enter_idle_state() -> void:
	_sprite.play("idle")

func _on_enter_battle_state() -> void:
	_sprite.play("run")

func _on_enter_attacking_state() -> void:
	pass

# =========================================================================== #
#  Attack
# =========================================================================== #

func _do_attack_tick(_delta: float) -> void:
	_play_attack_anim_and_fire()

func _play_attack_anim_and_fire() -> void:
	if not is_instance_valid(_target) or _target.hp <= 0:
		return

	_sprite.flip_h    = _target.global_position.x < global_position.x
		
	#Do different attacks based on range or randomness
	var dist := position.distance_to(_target.position)
	if dist < melee_range:
		_sprite.play("attack1")
		await _sprite.animation_finished
		if not is_instance_valid(_target):
			return
		CombatAudio.play("enemy_cat_melee")
		_target.take_damage(melee_damage)
		## Knock target back
		#if is_instance_valid(_target):
			#var kb_dir : Vector2 = (_target.position - position).normalized()
			#var kb_dest : Vector2 = _target.position + kb_dir * 320.0
			#var tw : Tween = _target.create_tween()
			#tw.tween_property(_target, "position", kb_dest, 0.25) \
				#.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	elif dist < ray_range:
		_sprite.play("special")
		print("ray")
		var total_frames = _sprite.sprite_frames.get_frame_count("special")
		var fps = _sprite.sprite_frames.get_animation_speed("special")
		var total_duration = total_frames / fps
		var shoot_time = total_duration / 2.0
	
		await get_tree().create_timer(shoot_time).timeout
		if not is_instance_valid(_target) or _target.hp <= 0:
			return
		CombatAudio.play("enemy_cat_nade")
		_target.take_damage(ray_damage)
		await _sprite.animation_finished
		
	elif dist < engage_range:
		_sprite.play("attack2")
		await _sprite.animation_finished
		if not is_instance_valid(_target) or _target.hp <= 0:
			return
		_target.take_damage(range_damage)
		_spawn_ice_on_target(_target)

func _spawn_ice_on_target(tgt: Node) -> void:
	if not is_instance_valid(tgt):
		return
	const ICE_TEX : Texture2D = preload("res://assets/Enemies/pengu_boss/pengu_fx_ice.png")
	const ICE_FPS : float     = 20.0
	var sprite    : AnimatedSprite2D = AnimatedSprite2D.new()
	var sf        : SpriteFrames     = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("anim")
	sf.set_animation_speed("anim", ICE_FPS)
	sf.set_animation_loop("anim", false)
	var frame_w   : int = 48
	var frame_h   : int = 128
	var count     : int = max(1, ICE_TEX.get_width() / frame_w)
	for i in count:
		var atlas    := AtlasTexture.new()
		atlas.atlas   = ICE_TEX
		atlas.region  = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame("anim", atlas)
	sprite.sprite_frames = sf
	sprite.scale         = Vector2(2.0, 2.0)
	sprite.z_index       = 10
	var fx : Node2D = Node2D.new()
	fx.position = tgt.position + Vector2(0, -80.0)
	fx.z_index  = 10
	fx.add_child(sprite)
	get_tree().current_scene.add_child(fx)
	sprite.play("anim")
	sprite.animation_finished.connect(fx.queue_free)
