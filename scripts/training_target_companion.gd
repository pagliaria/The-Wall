# Training target spawn and utility functions for main.gd

const TRAINING_TARGET_BASIC_SCENE  := preload("res://scenes/training_target_dummy.tscn")
const TRAINING_TARGET_BASIC_HP     := 300
const TRAINING_TARGET_COMBAT_HP    := 800

# ============================================================================ #
# SPAWN AND UTILITY METHODS
# ============================================================================ #

func spawn_training_target(mode: String = "basic", position: Vector2 = null) -> bool:
	"""
	Spawn a training target at specified position or random town location.
	
	@param mode - "basic" (free practice dummies) or "combat" (costs gold, can attack back)
	@param position - Optional position, otherwise random in town area
	@returns true if spawned successfully
	"""
	if not player_won:
		printerr("Training targets only spawn between waves!")
		return false
	
	# If no position given, pick a valid spot
	if position == null or not _is_valid_position(position):
		if mode == "basic":
			position = get_random_town_position_for_dummy()
		else:
			# Combat dummies spawn near castle for advanced practice
			position = Vector2(
				float((COL_TOWN_START + 8) * TILE_SIZE),
				float((WATER_ROWS + 4) * TILE_SIZE)
			)
	else:
		if not _is_valid_position(position):
			printerr("Invalid spawn position!")
			return false
	
	# Spawn the training target
	var scene := TRAINING_TARGET_BASIC_SCENE.instantiate() as Node2D
	if scene == null:
		printerr("Training target basic scene failed to load!")
		return false
	
	# Setup with appropriate config
	scene.setup(mode, position, _training_target_config(mode))
	add_child(scene)
	main._training_targets.append(scene)
	
	if mode == "basic":
		main._spawned_basic_count += 1
	else:
		main._spawned_combat_count += 1
	
	return true

func _training_target_config(mode: String) -> Dictionary:
	"""Get configuration for training target based on mode."""
	match mode:
		"basic":
			return {
				"max_hp": TRAINING_TARGET_BASIC_HP,
			}
		"combat":
			return {
				"max_hp": TRAINING_TARGET_COMBAT_HP,
			}
		_:
			return {}

func get_random_town_position_for_dummy() -> Vector2:
	"""Get a random valid spawn position in town area, avoiding building zones."""
	var cols := int(3 + randi() % 10)   # Offset from town start (avoid first few rows)
	var rows := int(5 + randi() % 8)    # Rows up from water
	var position := Vector2(
		float((COL_TOWN_START + cols) * TILE_SIZE),
		float((WATER_ROWS + rows) * TILE_SIZE)
	)
	return position

func _is_valid_position(position: Vector2) -> bool:
	"""Check if position is valid for training target spawn."""
	if position.x < float(COL_TOWN_START * TILE_SIZE):
		return false
	if position.x >= float(MAP_COLS * TILE_SIZE):
		return false
	if position.y < float(WATER_ROWS * TILE_SIZE):
		return false
	if position.y >= float(MAP_ROWS * TILE_SIZE):
		return false
	return true

func get_training_target_count() -> int:
	"""Get total number of active training targets."""
	return main._training_targets.size()
