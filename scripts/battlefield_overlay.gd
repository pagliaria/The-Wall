extends Node2D

const ENEMY_LEFT := 0.0
const ENEMY_RIGHT := 640.0
const FRIENDLY_LEFT := 640.0
const FRIENDLY_RIGHT := 1280.0
const FIELD_TOP := 192.0
const FIELD_BOTTOM := 1728.0

@onready var enemy_zone: Polygon2D = $EnemyZone
@onready var friendly_zone: Polygon2D = $FriendlyZone

func _ready() -> void:
	enemy_zone.polygon = PackedVector2Array([
		Vector2(ENEMY_LEFT, FIELD_TOP),
		Vector2(ENEMY_RIGHT, FIELD_TOP),
		Vector2(ENEMY_RIGHT, FIELD_BOTTOM),
		Vector2(ENEMY_LEFT, FIELD_BOTTOM),
	])
	friendly_zone.polygon = PackedVector2Array([
		Vector2(FRIENDLY_LEFT, FIELD_TOP),
		Vector2(FRIENDLY_RIGHT, FIELD_TOP),
		Vector2(FRIENDLY_RIGHT, FIELD_BOTTOM),
		Vector2(FRIENDLY_LEFT, FIELD_BOTTOM),
	])
