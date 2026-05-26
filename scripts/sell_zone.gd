extends PanelContainer
# sell_zone.gd
# Drop target in the HUD. Drag an item over it to sell for gold.
# Glows gold when an item is dragged over it.

@onready var _label : Label = $VBox/Label
@onready var _price : Label = $VBox/Price

const COLOR_NORMAL  : Color = Color(0.12, 0.08, 0.04, 0.88)
const COLOR_HOVER   : Color = Color(0.55, 0.40, 0.04, 0.96)
const BORDER_NORMAL : Color = Color(0.45, 0.28, 0.06, 1.0)
const BORDER_HOVER  : Color = Color(1.0,  0.85, 0.2,  1.0)

var _style : StyleBoxFlat = null

func _ready() -> void:
	add_to_group("sell_zone")
	_style                         = StyleBoxFlat.new()
	_style.bg_color                = COLOR_NORMAL
	_style.border_width_left       = 2
	_style.border_width_top        = 2
	_style.border_width_right      = 2
	_style.border_width_bottom     = 2
	_style.border_color            = BORDER_NORMAL
	_style.corner_radius_top_left  = 6
	_style.corner_radius_top_right = 6
	_style.corner_radius_bottom_left  = 6
	_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", _style)

func set_highlighted(on: bool) -> void:
	if _style == null:
		return
	_style.bg_color     = COLOR_HOVER  if on else COLOR_NORMAL
	_style.border_color = BORDER_HOVER if on else BORDER_NORMAL
