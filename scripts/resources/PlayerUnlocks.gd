extends Resource
class_name PlayerUnlocks

## Player unlocks configuration resource for progression system.
## Placeholder for future ability, map, and feature unlock system.

@export var ability_unlocks: Dictionary = {}  # {"ability_id": required_level}
@export var map_unlocks: Dictionary = {}      # {"map_id": required_level}
@export var feature_unlocks: Dictionary = {} # {"feature_id": required_level}

## Check if player has unlocked a specific ability
func has_ability_unlock(ability_id: StringName, player_level: int) -> bool:
	var required_level: int = ability_unlocks.get(ability_id, 1)  # Default to level 1
	return player_level >= required_level

## Check if player has unlocked a specific map
func has_map_unlock(map_id: StringName, player_level: int) -> bool:
	var required_level: int = map_unlocks.get(map_id, 1)  # Default to level 1
	return player_level >= required_level

## Check if player has unlocked a specific feature
func has_feature_unlock(feature_id: StringName, player_level: int) -> bool:
	var required_level: int = feature_unlocks.get(feature_id, 1)  # Default to level 1
	return player_level >= required_level

## Generic unlock check - returns true if player meets level requirement
func has_unlock(unlock_id: StringName, player_level: int) -> bool:
	# Check all unlock types
	if ability_unlocks.has(unlock_id):
		return has_ability_unlock(unlock_id, player_level)
	elif map_unlocks.has(unlock_id):
		return has_map_unlock(unlock_id, player_level)
	elif feature_unlocks.has(unlock_id):
		return has_feature_unlock(unlock_id, player_level)
	else:
		return true  # Unknown unlocks default to available