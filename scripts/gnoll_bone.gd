extends Area2D
# gnoll_bone.gd — thrown bone projectile for enemy_gnoll.gd.
# Unlike badger_orb.gd (a homing magic orb), this is a thrown physical object:
# travels in a straight line, no homing, just spins in flight.

const SPEED : float = 320.0

var damage  : int     = 4
var _dir    : Vector2 = Vector2.RIGHT
var _dead   : bool    = false
var _hired  : bool    = false

@onready var _sprite : AnimatedSprite2D = $Sprite

func init(target: Node, dmg: int, start_pos: Vector2, fired_by_hired: bool = false) -> void:
	damage          = dmg
	_hired          = fired_by_hired
	global_position = start_pos
	if is_instance_valid(target):
		_dir = (target.global_position - start_pos).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	z_index = 10
	if is_instance_valid(_sprite) and _sprite.sprite_frames.has_animation("spin"):
		_sprite.play("spin")

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
		# Fired by a hired unit — only hit real enemies (not hired, not player)
		if body_faction != "enemy" or body_hired:
			return
	else:
		# Fired by an enemy — hit player units and hired units, not other enemies
		if body_faction == "enemy" and not body_hired:
			return
	_dead = true
	body.take_damage(damage)
	queue_free()

# A thrown bone that hits nothing eventually leaves the battlefield. Rather
# than tracking map bounds here, a lifetime timer is simplest and matches how
# short-lived this projectile's flight actually is.
func _on_lifetime_timeout() -> void:
	if not _dead:
		queue_free()
