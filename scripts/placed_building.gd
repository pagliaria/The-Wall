extends StaticBody2D

# PlacedBuilding — a building that has been placed in the world.
# Generic container: creates its own sprite, collision, and click area.
# For building-specific behaviour (e.g. Castle spawning pawns), a child
# controller node is added based on building_id.

signal building_clicked(building: Node)

const COMBAT_BUILDINGS := ["barracks", "archery", "monastery", "tower"]
const UPGRADE_DEFS := {
	"attack_damage": {
		"description": "Increase unit attack damage by +1 per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 30, "wood": 15}, "time": 10.0, "value": 1},
			{"cost": {"gold": 50, "wood": 25}, "time": 14.0, "value": 1},
			{"cost": {"gold": 75, "wood": 40, "meat": 5}, "time": 18.0, "value": 1},
		],
	},
	"attack_speed": {
		"description": "Train units to attack 12% faster per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 35, "wood": 20}, "time": 10.0, "value": 0.88},
			{"cost": {"gold": 55, "wood": 30}, "time": 14.0, "value": 0.88},
			{"cost": {"gold": 80, "wood": 45, "meat": 5}, "time": 18.0, "value": 0.88},
		],
	},
	"move_speed": {
		"description": "Increase unit move speed by 10% per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 25, "wood": 20}, "time": 8.0, "value": 1.10},
			{"cost": {"gold": 45, "wood": 30}, "time": 12.0, "value": 1.10},
			{"cost": {"gold": 70, "wood": 40, "meat": 4}, "time": 16.0, "value": 1.10},
		],
	},
	"hp": {
		"description": "Increase unit HP by +4 per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 35, "wood": 25}, "time": 10.0, "value": 4},
			{"cost": {"gold": 55, "wood": 35}, "time": 14.0, "value": 4},
			{"cost": {"gold": 80, "wood": 50, "meat": 4}, "time": 18.0, "value": 4},
		],
	},
	"unit_cap": {
		"description": "Increase the building's max unit count by +1 per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 40, "wood": 20, "meat": 3}, "time": 12.0, "value": 1},
			{"cost": {"gold": 60, "wood": 30, "meat": 4}, "time": 16.0, "value": 1},
			{"cost": {"gold": 90, "wood": 45, "meat": 5}, "time": 20.0, "value": 1},
		],
	},
	"production_speed": {
		"description": "Reduce unit production time by 12% per level.",
		"max_level": 3,
		"levels": [
			{"cost": {"gold": 30, "wood": 25}, "time": 10.0, "value": 0.88},
			{"cost": {"gold": 50, "wood": 35}, "time": 14.0, "value": 0.88},
			{"cost": {"gold": 75, "wood": 50, "meat": 4}, "time": 18.0, "value": 0.88},
		],
	},
}

const TILE_SIZE = 64

const BUILDING_TEXTURES := {
	"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
	"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
	"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
	"house1":    "res://assets/Buildings/Black Buildings/House1.png",
	"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
	"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
}

# The building type — readable by UI, other systems, and child controllers.
var building_id : String = ""

# Injected by main.gd so child controllers (e.g. Castle) know where to add units.
var units_layer : Node2D = null

# Cached refs set during setup
var _indicator  : Node2D = null
var _controller : Node   = null
var _upgrade_levels := {
	"attack_damage": 0,
	"attack_speed": 0,
	"move_speed": 0,
	"hp": 0,
	"unit_cap": 0,
	"production_speed": 0,
}
var _active_upgrade_id: String = ""
var _upgrade_time_left: float = 0.0
var _upgrade_total_time: float = 0.0

func setup(id: String, tile: Vector2i, p_units_layer: Node2D) -> void:
	building_id = id
	units_layer = p_units_layer
	name        = "Building_%s_%d_%d" % [id, tile.x, tile.y]
	position    = _tile_center(tile)
	z_index     = 3

	# ── Sprite ────────────────────────────────────────────────────────────────
	var sprite       := Sprite2D.new()
	var tex          := load(BUILDING_TEXTURES[id]) as Texture2D
	sprite.texture    = tex
	add_child(sprite)

	# ── Collision sized to the actual texture ─────────────────────────────────
	# Use the real pixel dimensions of the sprite so large buildings like the
	# castle get a proper-sized box rather than a fixed tile-sized one.
	var tex_size   := tex.get_size() if tex else Vector2(TILE_SIZE, TILE_SIZE)

	var shape_node         := CollisionShape2D.new()
	var rect               := RectangleShape2D.new()
	rect.size               = tex_size - Vector2(64, 128)
	shape_node.shape        = rect
	add_child(shape_node)

	# Expose the tile for child controllers (e.g. spawn-point calculation).
	set_meta("tile", tile)

	# ── Click area sized to match the collision ────────────────────────────────
	var area              := Area2D.new()
	area.name              = "ClickArea"
	var area_shape         := CollisionShape2D.new()
	var area_rect          := RectangleShape2D.new()
	area_rect.size          = tex_size
	area_shape.shape        = area_rect
	area.add_child(area_shape)
	area.input_pickable    = true
	area.input_event.connect(_on_area_input_event)
	add_child(area)

	# ── Building-specific controller ───────────────────────────────────────────
	_attach_controller(id)

	# ── Spawn indicator (only for unit-producing buildings) ───────────────────
	if _controller != null:
		_indicator = Node2D.new()
		_indicator.z_index = 0
		_indicator.set_script(load("res://scripts/building_indicator.gd"))
		_indicator.position = Vector2(0, tex_size.y * 0.5 - 150)
		add_child(_indicator)

	# ── Drop animation ────────────────────────────────────────────────────────
	_play_drop_animation(sprite, tex_size)

func _attach_controller(id: String) -> void:
	match id:
		"castle":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/castle.gd"))
			ctrl.name          = "CastleController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
			_controller        = ctrl
		"barracks":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/barracks.gd"))
			ctrl.name          = "BarracksController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
			_controller        = ctrl
		"archery":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/archery.gd"))
			ctrl.name          = "ArcheryController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
			_controller        = ctrl
		"monastery":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/monastery.gd"))
			ctrl.name          = "MonasteryController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
			_controller        = ctrl
		"tower":
			var ctrl          := Node.new()
			ctrl.set_script(load("res://scripts/tower.gd"))
			ctrl.name          = "TowerController"
			add_child(ctrl)
			ctrl.units_layer   = units_layer
			_controller        = ctrl
		# Future: "house1"

func _process(_delta: float) -> void:
	_process_upgrade(_delta)
	if _indicator == null or _controller == null:
		return
	var live  : int   = 0
	var max_u : int   = 1
	var ratio : float = 0.0
	# Duck-type the controller — all building scripts expose these getters
	if _controller.has_method("get_live_pawns"):
		live  = _controller.get_live_pawns()
		max_u = _controller.get_max_pawns()
		ratio = _controller.get_spawn_timer() / _controller.SPAWN_INTERVAL
	elif _controller.has_method("get_live_warriors"):
		live  = _controller.get_live_warriors()
		max_u = _controller.get_max_warriors()
		ratio = _controller.get_spawn_timer() / _controller.SPAWN_INTERVAL
	elif _controller.has_method("get_live_archers"):
		live  = _controller.get_live_archers()
		max_u = _controller.get_max_archers()
		ratio = _controller.get_spawn_timer() / _controller.SPAWN_INTERVAL
	elif _controller.has_method("get_live_monks"):
		live  = _controller.get_live_monks()
		max_u = _controller.get_max_monks()
		ratio = _controller.get_spawn_timer() / _controller.SPAWN_INTERVAL
	elif _controller.has_method("get_live_lancers"):
		live  = _controller.get_live_lancers()
		max_u = _controller.get_max_lancers()
		ratio = _controller.get_spawn_timer() / _controller.SPAWN_INTERVAL
	ratio = clampf(ratio, 0.0, 1.0)
	var enough_meat := ResourceManager.has_meat(_controller.MEAT_COST)
	_indicator.refresh(live, max_u, ratio, enough_meat)

func _process_upgrade(delta: float) -> void:
	if _active_upgrade_id == "":
		return
	_upgrade_time_left = maxf(0.0, _upgrade_time_left - delta)
	if _upgrade_time_left > 0.0:
		return
	var completed_id := _active_upgrade_id
	_active_upgrade_id = ""
	_upgrade_total_time = 0.0
	_upgrade_levels[completed_id] = int(_upgrade_levels.get(completed_id, 0)) + 1
	_apply_upgrades_to_live_units()

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("building_clicked", self)

func get_nav_footprint() -> Rect2:
	# Returns the world-space rect used to carve the nav mesh for this building.
	# Matches the collision shape size exactly.
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return Rect2(position, Vector2.ZERO)
	var half := (col.shape as RectangleShape2D).size * 0.5
	return Rect2(position - half, (col.shape as RectangleShape2D).size)

func get_controller() -> Node:
	# Returns the building-specific controller child, if any.
	for child in get_children():
		if child.has_method("get_live_pawns"):   # duck-typed for castle
			return child
	return null

func supports_upgrades() -> bool:
	return building_id in COMBAT_BUILDINGS

func get_display_name() -> String:
	return building_id.capitalize() if building_id != "" else "Building"

func get_upgrade_definitions() -> Dictionary:
	return UPGRADE_DEFS

func get_upgrade_level(upgrade_id: String) -> int:
	return int(_upgrade_levels.get(upgrade_id, 0))

func get_active_upgrade_id() -> String:
	return _active_upgrade_id

func can_start_upgrade(upgrade_id: String) -> bool:
	if not supports_upgrades():
		return false
	if _active_upgrade_id != "":
		return false
	if not UPGRADE_DEFS.has(upgrade_id):
		return false
	var current_level := get_upgrade_level(upgrade_id)
	var upgrade_def: Dictionary = UPGRADE_DEFS[upgrade_id]
	var max_level: int = int(upgrade_def.get("max_level", 0))
	if current_level >= max_level:
		return false
	var levels: Array = upgrade_def.get("levels", [])
	if current_level >= levels.size():
		return false
	var cost: Dictionary = levels[current_level].get("cost", {})
	return ResourceManager.gold >= int(cost.get("gold", 0)) \
		and ResourceManager.wood >= int(cost.get("wood", 0)) \
		and ResourceManager.meat >= int(cost.get("meat", 0))

func try_start_upgrade(upgrade_id: String) -> bool:
	if not can_start_upgrade(upgrade_id):
		return false
	var current_level := get_upgrade_level(upgrade_id)
	var level_data: Dictionary = UPGRADE_DEFS[upgrade_id]["levels"][current_level]
	var cost: Dictionary = level_data.get("cost", {})
	if not ResourceManager.spend(cost):
		return false
	_active_upgrade_id = upgrade_id
	_upgrade_total_time = float(level_data.get("time", 0.0))
	_upgrade_time_left = _upgrade_total_time
	return true

func is_upgrade_blocking_production() -> bool:
	return _active_upgrade_id != ""

func get_upgrade_status_text() -> String:
	if _active_upgrade_id == "":
		return "Ready"
	var remaining := int(ceil(_upgrade_time_left))
	return "Upgrading %s (%d s)" % [_active_upgrade_id.replace("_", " ").capitalize(), remaining]

func get_effective_unit_cap(base_cap: int) -> int:
	return base_cap + _sum_upgrade_values("unit_cap")

func get_effective_spawn_interval(base_interval: float) -> float:
	return base_interval * _product_upgrade_values("production_speed")

func get_unit_bonus_bundle() -> Dictionary:
	return {
		"attack_damage": _sum_upgrade_values("attack_damage"),
		"attack_speed_multiplier": _product_upgrade_values("attack_speed"),
		"move_speed_multiplier": _product_upgrade_values("move_speed"),
		"hp_bonus": _sum_upgrade_values("hp"),
	}

func apply_unit_bonuses(unit: Node) -> void:
	if unit != null and unit.has_method("apply_building_bonuses"):
		unit.apply_building_bonuses(get_unit_bonus_bundle())

func _apply_upgrades_to_live_units() -> void:
	if units_layer == null:
		return
	for unit in units_layer.get_children():
		if unit.get("home_node") == self and unit.has_method("apply_building_bonuses"):
			unit.apply_building_bonuses(get_unit_bonus_bundle())

func _sum_upgrade_values(upgrade_id: String) -> int:
	var total := 0
	var level: int = get_upgrade_level(upgrade_id)
	var levels: Array = UPGRADE_DEFS.get(upgrade_id, {}).get("levels", [])
	for idx in range(mini(level, levels.size())):
		total += int(levels[idx].get("value", 0))
	return total

func _product_upgrade_values(upgrade_id: String) -> float:
	var value := 1.0
	var level: int = get_upgrade_level(upgrade_id)
	var levels: Array = UPGRADE_DEFS.get(upgrade_id, {}).get("levels", [])
	for idx in range(mini(level, levels.size())):
		value *= float(levels[idx].get("value", 1.0))
	return value

# =========================================================================== #
#  Drop animation
# =========================================================================== #

func _play_drop_animation(sprite: Sprite2D, tex_size: Vector2) -> void:
	const DROP_HEIGHT  : float = 120.0
	const DROP_TIME    : float = 0.30
	const SQUASH_TIME  : float = 0.07
	const SETTLE_TIME  : float = 0.22

	# Start above with slight tall squish to sell downward speed
	sprite.position = Vector2(0.0, -DROP_HEIGHT)
	sprite.scale    = Vector2(0.88, 1.12)

	var tw : Tween = create_tween()

	# Phase 1 — drop: sprite falls to rest, scale normalises simultaneously
	tw.tween_property(sprite, "position", Vector2.ZERO, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "scale", Vector2.ONE, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Phase 2 — landing: squash + dust fire together the instant sprite hits ground
	tw.tween_property(sprite, "scale", Vector2(1.22, 0.78), SQUASH_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(_spawn_dust.bind(tex_size))

	# Phase 3 — settle: spring back to normal, overlapping the tail of the squash
	tw.tween_property(sprite, "scale", Vector2.ONE, SETTLE_TIME) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

func _spawn_dust(tex_size: Vector2) -> void:
	UiAudio.play("building_land", 0.3)
	var base_y : float = tex_size.y * 0.5 - 8.0
	var top_y  : float = -tex_size.y * 0.5 + 8.0
	var half_w : float = tex_size.x * 0.22
	# Center impact — straight up
	_make_dust_emitter(Vector2(0.0,      base_y),          Vector2(0.0, -1.0),  35.0, 16, 0.6,  false)
	# Sides — up and slightly outward
	_make_dust_emitter(Vector2(-half_w,  base_y),          Vector2(-0.4, -1.0), 25.0, 10, 0.75, false)
	_make_dust_emitter(Vector2( half_w,  base_y),          Vector2( 0.4, -1.0), 25.0, 10, 0.75, false)
	# Back top — rises behind building
	_make_dust_emitter(Vector2(-half_w * 0.3, top_y + 50.0), Vector2(-0.2, -1.0), 20.0, 8, 0.9, true)
	_make_dust_emitter(Vector2( half_w * 0.3, top_y + 50.0), Vector2( 0.2, -1.0), 20.0, 8, 0.9, true)

func _make_dust_emitter(offset: Vector2, dir: Vector2, spread_deg: float, amount: int, lifetime: float, behind: bool) -> void:
	var atlas : AtlasTexture  = AtlasTexture.new()
	atlas.atlas               = load("res://assets/Particle FX/Dust_01.png")
	atlas.region              = Rect2(0, 0, 64, 64)

	var dust : CPUParticles2D = CPUParticles2D.new()
	dust.texture               = atlas
	dust.position              = offset
	dust.set("z_relative", false)
	dust.z_index               = 2 if behind else 10
	dust.amount                = amount
	dust.lifetime              = lifetime
	dust.one_shot              = true
	dust.explosiveness         = 0.95
	dust.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(6.0, 3.0)
	dust.direction             = dir.normalized()
	dust.spread                = spread_deg
	dust.gravity               = Vector2(0.0, 60.0)
	dust.initial_velocity_min  = 50.0
	dust.initial_velocity_max  = 510.0
	dust.scale_amount_min      = 0.4
	dust.scale_amount_max      = 3
	dust.color                 = Color(0.76, 0.65, 0.50, 0.75)
	dust.color_ramp            = _make_dust_gradient()
	add_child(dust)
	dust.restart()
	get_tree().create_timer(lifetime + 0.1).timeout.connect(dust.queue_free)

func _make_dust_gradient() -> Gradient:
	var g : Gradient = Gradient.new()
	g.colors = PackedColorArray([
		Color(0.76, 0.65, 0.50, 0.85),
		Color(0.76, 0.65, 0.50, 0.0),
	])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	return g

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)
