func _build_wall() -> void:
	var texture    : Texture2D = load(WALL_TEXTURE)
	var total_rows : int       = MAP_ROWS - WATER_ROWS
	# Stone style occupies sheet columns 4-5 (x = 128..191), width = 64px.
	# Sheet rows are 32px each. We scale the 64x32 slice to fill a 64x64 game tile.
	# Sheet row mapping:
	#   row 0 → top cap
	#   row 2 → body (middle)
	#   row 6 → bottom cap
	for i in range(total_rows):
		var row : int   = WATER_ROWS + i
		var x   : float = WALL_COL * TILE_SIZE
		var y   : float = row * TILE_SIZE

		var sheet_y : int
		if i == 0:
			sheet_y = 0 * WALL_TILE_PX    # top cap
		elif i == total_rows - 1:
			sheet_y = 6 * WALL_TILE_PX    # bottom cap
		else:
			sheet_y = 2 * WALL_TILE_PX    # body

		var sprite           := Sprite2D.new()
		sprite.texture        = texture
		sprite.region_enabled = true
		sprite.region_rect    = Rect2(4 * WALL_TILE_PX, sheet_y, 2 * WALL_TILE_PX, WALL_TILE_PX)
		sprite.centered       = false
		sprite.position       = Vector2(x, y)
		sprite.scale          = Vector2(1.0, TILE_SIZE / float(WALL_TILE_PX))
		wall_layer.add_child(sprite)

		# Collision
		var body  := StaticBody2D.new()
		body.position = Vector2(x + TILE_SIZE * 0.5, y + TILE_SIZE * 0.5)
		var shape := CollisionShape2D.new()
		var box   := RectangleShape2D.new()
		box.size   = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = box
		body.add_child(shape)
		wall_layer.add_child(body)
