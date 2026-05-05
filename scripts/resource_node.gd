extends Node

# ResourceNode — attached to each resource object (gold stone, tree, sheep).
# Tracks how much is left and arbitrates which pawns are extracting.
#
# Attach to the root Node2D of each resource via resource_spawner.gd.
# Set resource_type, amount, and extract_time after attaching.

signal depleted(resource_node: Node)

# -- Config (set by resource_spawner after attach) ----------------------------
var resource_type  : String  = "gold"   # "gold" | "wood" | "meat"
var amount         : int     = 0
var extract_time   : float   = 0.0
var world_position : Vector2 = Vector2.ZERO
var collision_body : Node    = null   # the StaticBody2D/CharacterBody2D a pawn touches to arrive

# Pawns currently assigned to extract from this node (capped to avoid crowding)
const MAX_GATHERERS = 3
var _gatherers : Array = []

# -- Public API ---------------------------------------------------------------

# Called by a pawn when it arrives and wants to start extracting.
# Returns true if the pawn is accepted (slot available and resource not empty).
func register_gatherer(pawn: Node) -> bool:
	if amount <= 0:
		return false
	if pawn in _gatherers:
		return true
	if _gatherers.size() >= MAX_GATHERERS:
		return false
	_gatherers.append(pawn)
	return true

func unregister_gatherer(pawn: Node) -> void:
	_gatherers.erase(pawn)

# Called by a pawn when it finishes one extraction cycle.
# Returns the resource_type string if successful, "" if depleted.
func extract_one(pawn: Node) -> String:
	# sheep death
	var parent := get_parent()
	if is_instance_valid(parent):
		if parent.has_method("die"):
			parent.die()
		
	if amount <= 0 or pawn not in _gatherers:
		return ""
	amount -= 1
	if amount <= 0:
		_on_depleted()
	return resource_type

func is_depleted() -> bool:
	return amount <= 0

# -- Internal -----------------------------------------------------------------

func _on_depleted() -> void:
	# Notify all gatherers so they can abort
	for pawn in _gatherers.duplicate():
		if is_instance_valid(pawn) and pawn.has_method("on_resource_depleted"):
			pawn.on_resource_depleted()
	_gatherers.clear()
	emit_signal("depleted", self)
	# Remove the visual resource node from the scene
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.queue_free()
