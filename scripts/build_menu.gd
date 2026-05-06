extends Control

signal building_selected(building_id: String)
signal closed

# ---------------------------------------------------------------------------
# Building costs  { building_id: { gold, wood, meat } }
# Single source of truth — building_placer.gd and main.gd both reference this.
# ---------------------------------------------------------------------------
const BUILDING_COSTS: Dictionary = {
	"castle":    { "gold": 100,   "wood": 50,  "meat": 0  },
	"barracks":  { "gold": 80,  "wood": 40, "meat": 0  },
	"archery":   { "gold": 60,  "wood": 60, "meat": 0  },
	"monastery": { "gold": 50,  "wood": 30, "meat": 0 },
	"house1":    { "gold": 20,  "wood": 30, "meat": 0  },
	"tower":     { "gold": 100, "wood": 20, "meat": 0  },
}

@onready var panel: NinePatchRect = $Panel
@onready var close_button: TextureButton = $Panel/CloseButton
@onready var build_buttons: Array[Button] = [
	$Panel/MarginContainer/VBox/Grid/ArcheryCard/VBox/BuildButton,
	$Panel/MarginContainer/VBox/Grid/BarracksCard/VBox/BuildButton,
	$Panel/MarginContainer/VBox/Grid/CastleCard/VBox/BuildButton,
	$Panel/MarginContainer/VBox/Grid/HouseCard/VBox/BuildButton,
	$Panel/MarginContainer/VBox/Grid/MonasteryCard/VBox/BuildButton,
	$Panel/MarginContainer/VBox/Grid/TowerCard/VBox/BuildButton,
]
@onready var cost_labels: Array[Label] = [
	$Panel/MarginContainer/VBox/Grid/ArcheryCard/VBox/Cost,
	$Panel/MarginContainer/VBox/Grid/BarracksCard/VBox/Cost,
	$Panel/MarginContainer/VBox/Grid/CastleCard/VBox/Cost,
	$Panel/MarginContainer/VBox/Grid/HouseCard/VBox/Cost,
	$Panel/MarginContainer/VBox/Grid/MonasteryCard/VBox/Cost,
	$Panel/MarginContainer/VBox/Grid/TowerCard/VBox/Cost,
]

var _banner_src: Image

# Current player resources — updated by main.gd via hud.gd before the menu opens.
var _gold: int = 0
var _wood: int = 0
var _meat: int = 0

func _ready() -> void:
	_build_banner_panel()
	close_button.pressed.connect(_on_close_pressed)
	_wire_buttons()
	_populate_cost_labels()
	await get_tree().process_frame
	var margin: MarginContainer = $Panel/MarginContainer
	var content_size := margin.get_combined_minimum_size()
	panel.size = content_size
	offset_left = -content_size.x / 2.0
	offset_top = -content_size.y / 2.0
	offset_right = content_size.x / 2.0
	offset_bottom = content_size.y / 2.0
	hide()

func open() -> void:
	_refresh_affordability()
	show()

# Called by hud.gd (which gets it from main.gd) whenever resources change.
func set_resources(gold: int, wood: int, meat: int) -> void:
	_gold = gold
	_wood = wood
	_meat = meat
	if visible:
		_refresh_affordability()

func _on_close_pressed() -> void:
	hide()
	emit_signal("closed")

func _wire_buttons() -> void:
	for button in build_buttons:
		var building_id := String(button.get_meta("building_id", ""))
		if building_id.is_empty():
			continue
		button.pressed.connect(func(): _on_build_pressed(building_id))

func _populate_cost_labels() -> void:
	for i in build_buttons.size():
		var id := String(build_buttons[i].get_meta("building_id", ""))
		if id.is_empty() or not BUILDING_COSTS.has(id):
			continue
		var cost: Dictionary = BUILDING_COSTS[id]
		cost_labels[i].text = _format_cost(cost)

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if cost.get("gold", 0) > 0:
		parts.append("G:%d" % cost["gold"])
	if cost.get("wood", 0) > 0:
		parts.append("W:%d" % cost["wood"])
	if cost.get("meat", 0) > 0:
		parts.append("M:%d" % cost["meat"])
	if parts.is_empty():
		return "Free"
	return "  ".join(parts)

func _refresh_affordability() -> void:
	for i in build_buttons.size():
		var id := String(build_buttons[i].get_meta("building_id", ""))
		var affordable := _can_afford(id)
		build_buttons[i].disabled = not affordable
		# Dim the cost label red when unaffordable.
		if affordable:
			cost_labels[i].modulate = Color.WHITE
		else:
			cost_labels[i].modulate = Color(1.0, 0.4, 0.4)

func _can_afford(building_id: String) -> bool:
	if not BUILDING_COSTS.has(building_id):
		return true
	var cost: Dictionary = BUILDING_COSTS[building_id]
	return (
		_gold >= cost.get("gold", 0) and
		_wood >= cost.get("wood", 0) and
		_meat >= cost.get("meat", 0)
	)

func _build_banner_panel() -> void:
	var src_tex := load("res://assets/UI Elements/UI Elements/Banners/Banner.png") as Texture2D
	_banner_src = src_tex.get_image()
	_banner_src.convert(Image.FORMAT_RGBA8)

	var mid_y: int = _banner_src.get_height() / 2
	var width: int = _banner_src.get_width()
	var in_gap := true
	var segments: Array = []
	var seg_start := 0
	for x in width:
		var alpha: float = _banner_src.get_pixel(x, mid_y).a
		var is_opaque: bool = alpha >= 0.1
		if in_gap and is_opaque:
			seg_start = x
			in_gap = false
		elif not in_gap and not is_opaque:
			segments.append({"start": seg_start, "end": x - 1})
			in_gap = true
	if not in_gap:
		segments.append({"start": seg_start, "end": width - 1})

	if segments.size() != 3:
		push_error("Expected 3 banner segments, got %d - check Banner.png" % segments.size())
		return

	var mid_x: int = _banner_src.get_width() / 2
	var height: int = _banner_src.get_height()
	in_gap = true
	var row_segments: Array = []
	var row_start := 0
	for y in height:
		var alpha: float = _banner_src.get_pixel(mid_x, y).a
		var is_opaque: bool = alpha >= 0.1
		if in_gap and is_opaque:
			row_start = y
			in_gap = false
		elif not in_gap and not is_opaque:
			row_segments.append({"start": row_start, "end": y - 1})
			in_gap = true
	if not in_gap:
		row_segments.append({"start": row_start, "end": height - 1})

	var col_widths: Array[int] = []
	var row_heights: Array[int] = []
	for s in segments:
		col_widths.append(s["end"] - s["start"] + 1)
	for s in row_segments:
		row_heights.append(s["end"] - s["start"] + 1)

	var out_w: int = col_widths[0] + col_widths[1] + col_widths[2]
	var out_h: int = row_heights[0] + row_heights[1] + row_heights[2]
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)

	var dst_y := 0
	for row in 3:
		var dst_x := 0
		for col in 3:
			var src_x: int = segments[col]["start"]
			var src_y: int = row_segments[row]["start"]
			var cw: int = col_widths[col]
			var rh: int = row_heights[row]
			out.blit_rect(_banner_src, Rect2i(src_x, src_y, cw, rh), Vector2i(dst_x, dst_y))
			dst_x += cw
		dst_y += row_heights[row]

	panel.texture = ImageTexture.create_from_image(out)
	panel.patch_margin_left = col_widths[0]
	panel.patch_margin_right = col_widths[2]
	panel.patch_margin_top = row_heights[0]
	panel.patch_margin_bottom = row_heights[2]

func _on_build_pressed(id: String) -> void:
	emit_signal("building_selected", id)
	hide()
