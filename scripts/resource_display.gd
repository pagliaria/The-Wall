extends Control

# Resource Display — single horizontal ribbon showing gold, wood, and meat.
# Call set_resources(gold, wood, meat) or individual setters from main.gd.

@onready var gold_label : Label = $HBox/GoldGroup/GoldLabel
@onready var wood_label : Label = $HBox/WoodGroup/WoodLabel
@onready var meat_label : Label = $HBox/MeatGroup/MeatLabel

var gold : int = 0
var wood : int = 0
var meat : int = 0

func _ready() -> void:
	_refresh()

func set_resources(p_gold: int, p_wood: int, p_meat: int) -> void:
	gold = p_gold
	wood = p_wood
	meat = p_meat
	_refresh()

func set_gold(amount: int) -> void:
	gold = amount
	gold_label.text = str(gold)

func set_wood(amount: int) -> void:
	wood = amount
	wood_label.text = str(wood)

func set_meat(amount: int) -> void:
	meat = amount
	meat_label.text = str(meat)

func _refresh() -> void:
	gold_label.text = str(gold)
	wood_label.text = str(wood)
	meat_label.text = str(meat)
