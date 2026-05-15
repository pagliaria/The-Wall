# formation_manager.gd
# Pure math — no scene dependency.
# Called by unit_selection._issue_move_order to compute per-unit destinations.

extends Node

enum Formation { LINE, WEDGE, BOX, FLANKS }
enum Spacing   { TIGHT, NORMAL, LOOSE }

const SPACING_VALUES : Dictionary = {
	Spacing.TIGHT:  64.0,
	Spacing.NORMAL: 120.0,
	Spacing.LOOSE:  190.0,
}

# Unit type priority for slot assignment — lower = front
const TYPE_PRIORITY : Dictionary = {
	"warrior": 0,
	"lancer":  1,
	"pawn":    2,
	"archer":  3,
	"monk":    4,
}

# Returns an Array of Vector2 world positions, one per unit.
# units   — ordered array of unit nodes
# target  — world position of right-click destination
# dir     — unit vector pointing from group center toward target (move direction)
func get_slots(units: Array, target: Vector2, dir: Vector2, formation: Formation, spacing: Spacing) -> Array:
	var gap     : float = SPACING_VALUES[spacing]
	var raw     : Array = _raw_slots(units.size(), formation, gap)
	var rotated : Array = _rotate_slots(raw, dir)
	# Assign slots in type-priority order — melee gets front slots first
	return _assign_slots_by_priority(units, rotated, target)

# =========================================================================== #
#  Slot shapes
# =========================================================================== #

func _raw_slots(count: int, formation: Formation, gap: float) -> Array:
	match formation:
		Formation.LINE:   return _line(count, gap)
		Formation.WEDGE:  return _wedge(count, gap)
		Formation.BOX:    return _box(count, gap)
		Formation.FLANKS: return _flanks(count, gap)
	return _line(count, gap)

# Horizontal line perpendicular to movement
func _line(count: int, gap: float) -> Array:
	var slots : Array = []
	var row_size : int = ceili(sqrt(float(count)))
	for i in count:
		var col : int   = i % row_size
		var row : int   = i / row_size
		slots.append(Vector2(
			(col - (min(count - row * row_size, row_size) - 1) * 0.5) * gap,
			row * gap
		))
	return slots

# Point forward, wings fanning back — one unit per side per row
func _wedge(count: int, gap: float) -> Array:
	var slots : Array = []
	slots.append(Vector2.ZERO)  # tip
	var wing : int = 1
	while slots.size() < count:
		# Left wing slot
		if slots.size() < count:
			slots.append(Vector2(-wing * gap * 0.85, wing * gap * 0.75))
		# Right wing slot
		if slots.size() < count:
			slots.append(Vector2( wing * gap * 0.85, wing * gap * 0.75))
		wing += 1
	return slots

# Outer ring of melee, inner cluster of ranged/support
func _box(count: int, gap: float) -> Array:
	var slots   : Array = []
	if count <= 4:
		return _line(count, gap)
	# Outer ring
	var ring_size : int = ceili(count * 0.6)
	ring_size = max(ring_size, 4)
	ring_size = min(ring_size, count)
	var inner : int = count - ring_size
	for i in ring_size:
		var angle : float = (float(i) / ring_size) * TAU - PI * 0.5
		var radius : float = gap * 1.4
		slots.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	# Inner cluster
	for j in inner:
		var angle : float = (float(j) / max(inner, 1)) * TAU
		var radius : float = gap * 0.5
		slots.append(Vector2(cos(angle) * radius * 0.6, sin(angle) * radius * 0.6))
	return slots

# Two columns flanking center, ranged behind
func _flanks(count: int, gap: float) -> Array:
	var slots   : Array = []
	var per_col : int   = ceili(count / 2.0)
	for i in count:
		var side : int  = i % 2  # 0 left, 1 right
		var row  : int  = i / 2
		var x    : float = (side * 2 - 1) * gap
		var y    : float = (row - (per_col - 1) * 0.5) * gap
		slots.append(Vector2(x, y))
	return slots

# Assign slots by type priority — index 0 in rotated is the "front" slot.
# Melee units get low-index (front) slots, ranged get high-index (back) slots.
# Within the same type group, nearest-neighbor to avoid crossing paths.
func _assign_slots_by_priority(units: Array, offsets: Array, target: Vector2) -> Array:
	# Build result indexed by original unit order
	var result : Array = []
	result.resize(units.size())

	# Sort units by priority, keeping track of original index
	var indexed : Array = []
	for i in units.size():
		indexed.append({"unit": units[i], "orig_idx": i})
	indexed.sort_custom(func(a, b):
		return _type_priority(a["unit"]) < _type_priority(b["unit"])
	)

	# Walk through priority-sorted units, assign slots in order
	# Within each priority group use nearest-neighbor to reduce crossing
	var available : Array = []
	for i in offsets.size():
		available.append(i)

	var group_start : int = 0
	while group_start < indexed.size():
		# Find end of current priority group
		var cur_priority : int = _type_priority(indexed[group_start]["unit"])
		var group_end    : int = group_start
		while group_end < indexed.size() and _type_priority(indexed[group_end]["unit"]) == cur_priority:
			group_end += 1

		# Collect available slots for this group (front-most first)
		var group_slots : int = group_end - group_start
		var pool        : Array = available.slice(0, group_slots)

		# Assign nearest-neighbor within group
		for gi in range(group_start, group_end):
			var unit : Node = indexed[gi]["unit"]
			if not is_instance_valid(unit) or pool.is_empty():
				result[indexed[gi]["orig_idx"]] = target
				continue
			var best_pos  : int   = 0
			var best_dist : float = INF
			for pi in pool.size():
				var d : float = unit.position.distance_to(target + offsets[pool[pi]])
				if d < best_dist:
					best_dist = d
					best_pos  = pi
			result[indexed[gi]["orig_idx"]] = target + offsets[pool[best_pos]]
			pool.remove_at(best_pos)
			available.remove_at(best_pos)

		group_start = group_end

	return result

# =========================================================================== #
#  Helpers
# =========================================================================== #

func _type_priority(unit: Node) -> int:
	var script : Script = unit.get_script()
	if script:
		var name : String = script.resource_path.get_file().get_basename().to_lower()
		return TYPE_PRIORITY.get(name, 5)
	return 5

# Rotate all slot offsets so formation faces movement direction
func _rotate_slots(slots: Array, dir: Vector2) -> Array:
	# dir points toward target. Formation "forward" is -Y (up in raw space).
	# We want raw -Y to align with dir.
	var forward  : Vector2 = dir if dir.length() > 0.01 else Vector2(0, -1)
	var angle    : float   = forward.angle_to(Vector2(0, -1))
	var rotated  : Array   = []
	for s in slots:
		rotated.append((s as Vector2).rotated(-angle))
	return rotated

# Assign each unit to its nearest available slot (greedy nearest-neighbor)
func _assign_slots(units: Array, offsets: Array, target: Vector2) -> Array:
	var result    : Array = []
	result.resize(units.size())
	var available : Array = []
	for i in offsets.size():
		available.append(i)

	for i in units.size():
		var unit : Node = units[i]
		if not is_instance_valid(unit) or available.is_empty():
			result[i] = target
			continue
		var best_pos  : int   = 0
		var best_dist : float = INF
		for j in available.size():
			var slot_world : Vector2 = target + offsets[available[j]]
			var d          : float   = unit.position.distance_to(slot_world)
			if d < best_dist:
				best_dist = d
				best_pos  = j
		result[i] = target + offsets[available[best_pos]]
		available.remove_at(best_pos)
	return result
