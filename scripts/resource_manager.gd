# resource_manager.gd
# Autoload singleton — tracks all player resources and exposes spend/add helpers.
# Add to Project > Project Settings > Globals as "ResourceManager".
extends Node

signal resources_changed(gold: int, wood: int, meat: int)

var gold : int = 100
var wood : int = 50
var meat : int = 10

var gold_multiplier : int = 10
var wood_multiplier : int = 10
var meat_multiplier : int = 1

# =========================================================================== #
#  Queries
# =========================================================================== #

func has_meat(amount: int) -> bool:
	return meat >= amount

func has_gold(amount: int) -> bool:
	return gold >= amount

func has_wood(amount: int) -> bool:
	return wood >= amount

# =========================================================================== #
#  Spending
# =========================================================================== #

# Returns true and deducts if affordable, false otherwise.
func spend_meat(amount: int) -> bool:
	if meat < amount:
		return false
	meat -= amount
	emit_signal("resources_changed", gold, wood, meat)
	return true

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("resources_changed", gold, wood, meat)
	return true

func spend_wood(amount: int) -> bool:
	if wood < amount:
		return false
	wood -= amount
	emit_signal("resources_changed", gold, wood, meat)
	return true

func spend(costs: Dictionary) -> bool:
	var g : int = costs.get("gold", 0)
	var w : int = costs.get("wood", 0)
	var m : int = costs.get("meat", 0)
	if gold < g or wood < w or meat < m:
		return false
	gold -= g
	wood -= w
	meat -= m
	emit_signal("resources_changed", gold, wood, meat)
	return true

# =========================================================================== #
#  Adding
# =========================================================================== #

func add(resource_type: String, amount: int) -> void:
	match resource_type:
		"gold": gold += amount * gold_multiplier
		"wood": wood += amount * wood_multiplier
		"meat": meat += amount * meat_multiplier
	emit_signal("resources_changed", gold, wood, meat)
