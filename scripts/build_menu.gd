extends Control

# Build Menu — popup panel showing all available buildings.
# Emits building_selected(building_id: String) when the player picks one.
# Emits closed when the X button is pressed.

signal building_selected(building_id: String)
signal closed

# Banner.png is 448x448, a 3x3 spritesheet with transparent gaps.
# Cell/gap sizes are detected automatically by scanning pixel alpha.
const BANNER_TOTAL := 448

# Building definitions — cost fields left as -1 (unknown) until designed.
const BUILDINGS := [
	{ "id": "archery",   "name": "Archery Range", "gold": -1, "wood": -1 },
	{ "id": "barracks",  "name": "Barracks",       "gold": -1, "wood": -1 },
	{ "id": "castle",    "name": "Castle",          "gold": -1, "wood": -1 },
	{ "id": "house1",    "name": "House",           "gold": -1, "wood": -1 },
	#{ "id": "house2",    "name": "House II",        "gold": -1, "wood": -1 },
	#{ "id": "house3",    "name": "House III",       "gold": -1, "wood": -1 },
	{ "id": "monastery", "name": "Monastery",       "gold": -1, "wood": -1 },
	{ "id": "tower",     "name": "Tower",           "gold": -1, "wood": -1 },
]

@onready var panel        : NinePatchRect = $Panel
@onready var close_button : TextureButton = $Panel/CloseButton
@onready var grid         : GridContainer = $Panel/MarginContainer/VBox/Grid

var _banner_src : Image  # the raw Banner.png pixels

func _ready() -> void:
	_build_banner_panel()
	close_button.pressed.connect(_on_close_pressed)
	_build_grid()
	# Wait one frame for layout to calculate, then size panel to wrap content
	await get_tree().process_frame
	var margin : MarginContainer = $Panel/MarginContainer
	var cw : float = margin.get_combined_minimum_size().x
	var ch : float = margin.get_combined_minimum_size().y
	panel.size = Vector2(cw, ch)
	offset_left   = -cw / 2.0
	offset_top    = -ch / 2.0
	offset_right  =  cw / 2.0
	offset_bottom =  ch / 2.0
	hide()

func open() -> void:
	show()

func _on_close_pressed() -> void:
	hide()
	emit_signal("closed")

# ── Banner stitching ──────────────────────────────────────────────────────────
# Scans pixel alpha along the horizontal centre row to find where the
# transparent gaps are, then blits all 9 patches into a seamless image.

func _build_banner_panel() -> void:
	var src_tex := load("res://assets/UI Elements/UI Elements/Banners/Banner.png") as Texture2D
	_banner_src = src_tex.get_image()
	_banner_src.convert(Image.FORMAT_RGBA8)

	# Scan the middle row for transparent columns to find gap positions
	var mid_y : int = _banner_src.get_height() / 2
	var width : int = _banner_src.get_width()
	var in_gap := true   # start assuming gap (image may have transparent border)
	var segments : Array = []
	var seg_start := 0
	for x in width:
		var alpha : float = _banner_src.get_pixel(x, mid_y).a
		var is_opaque : bool = alpha >= 0.1
		if in_gap and is_opaque:
			seg_start = x
			in_gap = false
		elif not in_gap and not is_opaque:
			segments.append({"start": seg_start, "end": x - 1})
			in_gap = true
	if not in_gap:
		segments.append({"start": seg_start, "end": width - 1})

	print("Banner segments found: ", segments)

	if segments.size() != 3:
		push_error("Expected 3 banner segments, got %d — check Banner.png" % segments.size())
		return

	# Build per-row segments too (scan middle column)
	var mid_x : int = _banner_src.get_width() / 2
	var height : int = _banner_src.get_height()
	in_gap = true
	var row_segments : Array = []
	var row_start := 0
	for y in height:
		var alpha : float = _banner_src.get_pixel(mid_x, y).a
		var is_opaque : bool = alpha >= 0.1
		if in_gap and is_opaque:
			row_start = y
			in_gap = false
		elif not in_gap and not is_opaque:
			row_segments.append({"start": row_start, "end": y - 1})
			in_gap = true
	if not in_gap:
		row_segments.append({"start": row_start, "end": height - 1})

	print("Banner row segments: ", row_segments)

	# Stitch into a seamless image — each patch blit side by side
	var col_widths  : Array[int] = []
	var row_heights : Array[int] = []
	for s in segments:
		col_widths.append(s["end"] - s["start"] + 1)
	for s in row_segments:
		row_heights.append(s["end"] - s["start"] + 1)

	var out_w : int = col_widths[0] + col_widths[1] + col_widths[2]
	var out_h : int = row_heights[0] + row_heights[1] + row_heights[2]
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)

	var dst_y : int = 0
	for row in 3:
		var dst_x : int = 0
		for col in 3:
			var src_x : int = segments[col]["start"]
			var src_y : int = row_segments[row]["start"]
			var cw   : int = col_widths[col]
			var rh   : int = row_heights[row]
			out.blit_rect(_banner_src, Rect2i(src_x, src_y, cw, rh), Vector2i(dst_x, dst_y))
			dst_x += cw
		dst_y += row_heights[row]

	var stitched := ImageTexture.create_from_image(out)
	panel.texture = stitched
	# Corner size = top-left patch dimensions
	panel.patch_margin_left   = col_widths[0]
	panel.patch_margin_right  = col_widths[2]
	panel.patch_margin_top    = row_heights[0]
	panel.patch_margin_bottom = row_heights[2]
	print("Banner panel built: out=%dx%d  margins L=%d R=%d T=%d B=%d" % [
		out_w, out_h,
		col_widths[0], col_widths[2], row_heights[0], row_heights[2]
	])

# ── Grid ──────────────────────────────────────────────────────────────────────

func _build_grid() -> void:
	for b in BUILDINGS:
		grid.add_child(_make_card(b))

func _make_card(b: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(70, 110)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Building preview image
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(80, 80)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture = _load_building_texture(b["id"])
	vbox.add_child(img)

	# Building name
	var name_label := Label.new()
	name_label.text = b["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	# Cost row
	var cost_label := Label.new()
	var gold_str := "??" if b["gold"] < 0 else str(b["gold"])
	var wood_str := "??" if b["wood"] < 0 else str(b["wood"])
	cost_label.text = "Gold: %s  Wood: %s" % [gold_str, wood_str]
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(cost_label)

	# Build button
	var btn := Button.new()
	btn.text = "Build"
	btn.custom_minimum_size = Vector2(70, 24)
	var id: String = b["id"]
	btn.pressed.connect(func(): _on_build_pressed(id))
	vbox.add_child(btn)

	return card

func _load_building_texture(id: String) -> Texture2D:
	var map := {
		"archery":   "res://assets/Buildings/Black Buildings/Archery.png",
		"barracks":  "res://assets/Buildings/Black Buildings/Barracks.png",
		"castle":    "res://assets/Buildings/Black Buildings/Castle.png",
		"house1":    "res://assets/Buildings/Black Buildings/House1.png",
		#"house2":    "res://assets/Buildings/Black Buildings/House2.png",
		#"house3":    "res://assets/Buildings/Black Buildings/House3.png",
		"monastery": "res://assets/Buildings/Black Buildings/Monastery.png",
		"tower":     "res://assets/Buildings/Black Buildings/Tower.png",
	}
	return load(map[id]) as Texture2D

func _on_build_pressed(id: String) -> void:
	emit_signal("building_selected", id)
	hide()
