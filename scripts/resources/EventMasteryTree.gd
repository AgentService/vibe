class_name EventMasteryTree
extends Resource

## Event mastery progression tree for PoE Atlas-style passive allocation system.
## Tracks mastery points earned per event type and allocated passives.
## Used by EventMasterySystem to apply modifiers to event spawning behavior.

@export_group("Mastery Points")
@export var breach_points: int = 0 ## Points earned from completing Breach events
@export var ritual_points: int = 0 ## Points earned from completing Ritual events
@export var pack_hunt_points: int = 0 ## Points earned from completing Pack Hunt events
@export var boss_points: int = 0 ## Points earned from completing Boss events

@export_group("Allocated Passives")
@export var allocated_passives: Dictionary = {} ## passive_id -> level (int), 0 = not allocated

## Check if a specific passive is allocated
func is_passive_allocated(passive_id: StringName) -> bool:
	return get_passive_level(passive_id) > 0

## Get current level of a passive
func get_passive_level(passive_id: StringName) -> int:
	return allocated_passives.get(passive_id, 0)

## Check if there are enough points for a specific event type
func has_enough_points(event_type: StringName, required_points: int) -> bool:
	var available_points = get_points_for_event_type(event_type)
	return available_points >= required_points

## Check if a passive can be allocated (has enough points and not already allocated)
func can_allocate_passive(passive_id: StringName, required_points: int, event_type: StringName) -> bool:
	var available_points = get_points_for_event_type(event_type)
	return available_points >= required_points and not is_passive_allocated(passive_id)

## Get mastery points for specific event type
func get_points_for_event_type(event_type: StringName) -> int:
	match event_type:
		"breach": return breach_points
		"ritual": return ritual_points
		"pack_hunt": return pack_hunt_points
		"boss": return boss_points
		_: return 0

## Increment passive level (multi-level support)
func increment_passive_level(passive_id: StringName, cost: int, event_type: StringName) -> bool:
	if has_enough_points(event_type, cost):
		var current_level = get_passive_level(passive_id)
		allocated_passives[passive_id] = current_level + 1
		# Note: Points are not deducted - passives unlock when you have enough total points
		# This follows PoE Atlas passive design where points accumulate permanently
		return true
	return false

## Decrement passive level (respec functionality)
func decrement_passive_level(passive_id: StringName, refund_points: int, event_type: StringName) -> bool:
	var current_level = get_passive_level(passive_id)
	if current_level > 0:
		allocated_passives[passive_id] = current_level - 1
		if allocated_passives[passive_id] <= 0:
			allocated_passives.erase(passive_id)  # Remove entry if level 0
		return true
	return false

## Allocate a passive if requirements are met (legacy single-level support)
func allocate_passive(passive_id: StringName, cost: int, event_type: StringName) -> bool:
	if can_allocate_passive(passive_id, cost, event_type):
		allocated_passives[passive_id] = 1
		# Note: Points are not deducted - passives unlock when you have enough total points
		# This follows PoE Atlas passive design where points accumulate permanently
		return true
	return false

## Deallocate a passive (legacy single-level support)
func deallocate_passive(passive_id: StringName) -> void:
	allocated_passives.erase(passive_id)

## Add mastery points for completing an event
func add_mastery_points(event_type: StringName, points: int) -> void:
	match event_type:
		"breach": breach_points += points
		"ritual": ritual_points += points
		"pack_hunt": pack_hunt_points += points
		"boss": boss_points += points

## Get total mastery points across all event types
func get_total_points() -> int:
	return breach_points + ritual_points + pack_hunt_points + boss_points

## Get allocated passives count
func get_allocated_passives_count() -> int:
	return allocated_passives.size()

## Reset all passives (full respec)
func reset_all_passives() -> void:
	allocated_passives.clear()

## Validate mastery tree state
func is_valid() -> bool:
	# Ensure no negative points
	if breach_points < 0 or ritual_points < 0 or pack_hunt_points < 0 or boss_points < 0:
		return false

	# Validate allocated passives are positive integer values
	for passive_id in allocated_passives:
		var level = allocated_passives[passive_id]
		if not level is int or level <= 0:
			return false

	return true
