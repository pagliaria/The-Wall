extends Area2D
# harpoon_projectile.gd — thrown harpoon for enemy_harpoon_shark.gd.
# Straight-line travel like gnoll_bone.gd, but on hit also applies the Wet
# status (apply_wet, defined on unit_base.gd/enemy_base.gd) to whatever it
# connects with, slowing its movement and attack speed for a few seconds.

const SPEED : float = 360.0

# Harpoon.png's default facing angle in the art is unverified from here — if
# it points the wrong way once previewed, adjust this one constant rather
# than touching the rotation logic below.
const SPRITE_FACING_OFFSET : float = 0.0

# "A little" slow, per the Wet status's own semantics (see apply_wet's
# comment in unit_base.gd): speed_mult < 1.0 slows movement, attack_mult > 1.0
# slows attacks (it multiplies a time duration, not a speed).
const WET_SPEED_MULT  : float = 0.82
const WET_ATTACK_MULT : float = 1.2
const WET_DURATION    : float = 3.0

var damage  : int     = 5
var _dir    : Vector2 = Vector2.RIGHT
var _dead   : bool    = false
var _hired  : bool    = false

@onready var _sprite : Sprite2D = $Sprite

func init(target: Node, dmg: int, start_pos: Vector2, fired_by_hired: bool = false) -> void:
	damage          = dmg
	_hired          = fired_by_hired
	global_position = start_pos
	if is_instance_valid(target):
		_dir = (target.global_position - start_pos).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT
	rotation = _dir.angle() + SPRITE_FACING_OFFSET

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	z_index = 10

func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += _dir * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if not body.has_method("take_damage"):
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
	body.take_damage(damage)
	if body.has_method("apply_wet"):
		body.apply_wet(WET_SPEED_MULT, WET_ATTACK_MULT, WET_DURATION)
	queue_free()

func _on_lifetime_timeout() -> void:
	if not _dead:
		queue_free()
