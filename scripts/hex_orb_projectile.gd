extends Area2D
# hex_orb_projectile.gd — Hex Shaman's curse orb. Never deals damage. On hit,
# rolls a chance to transform the target into a harmless pig for a few
# seconds (apply_transform_pig, defined on unit_base.gd/enemy_base.gd). A miss
# still plays a small fizzle so the cast doesn't look like it did nothing.

const SPEED : float = 260.0

const PIG_CHANCE    : float = 0.35
const PIG_DURATION  : float = 4.0

const FIZZLE_FX_SCENE : PackedScene = preload("res://scenes/hex_fizzle_fx.tscn")
const POOF_FX_SCENE    : PackedScene = preload("res://scenes/pig_poof_fx.tscn")

var _dir   : Vector2 = Vector2.RIGHT
var _dead  : bool    = false
var _hired : bool    = false

@onready var _sprite : AnimatedSprite2D = $Sprite

func init(target: Node, start_pos: Vector2, fired_by_hired: bool = false) -> void:
	_hired          = fired_by_hired
	global_position = start_pos
	if is_instance_valid(target):
		_dir = (target.global_position - start_pos).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	z_index = 10
	if _sprite.sprite_frames.has_animation("spin"):
		_sprite.play("spin")

func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += _dir * SPEED * delta
	rotation += delta * 10.0

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	# Hex Shaman never deals damage, so the only thing worth checking for is
	# whether this body is a valid curse target at all (same faction rules
	# every other projectile here uses) — no take_damage requirement.
	if not body.has_method("get"):
		return
	var body_faction : String = str(body.get("faction"))
	var body_hired   : bool   = body.get("hired") == true
	if _hired:
		if body_faction != "enemy" or body_hired:
			return
	else:
		if body_faction == "enemy" and not body_hired:
			return
	_dead = true
	var impact_pos : Vector2 = global_position
	if body.has_method("apply_transform_pig") and randf() < PIG_CHANCE:
		body.apply_transform_pig(PIG_DURATION)
		_spawn_fx(POOF_FX_SCENE, body.global_position)
	else:
		_spawn_fx(FIZZLE_FX_SCENE, impact_pos)
	queue_free()

func _spawn_fx(scene: PackedScene, at_pos: Vector2) -> void:
	var fx : Node2D = scene.instantiate()
	fx.global_position = at_pos
	get_tree().current_scene.add_child(fx)

func _on_lifetime_timeout() -> void:
	if not _dead:
		_spawn_fx(FIZZLE_FX_SCENE, global_position)
		queue_free()
