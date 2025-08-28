extends RefCounted

## Payload for entity_killed signal - entity death with rewards.
## Provides compile-time type safety for entity lifecycle events.

class_name EntityKilledPayload

var entity_id: EntityId
var death_pos: Vector2
var rewards: Dictionary

func _init(entity: EntityId, position: Vector2, reward_data: Dictionary) -> void:
	entity_id = entity
	death_pos = position
	rewards = reward_data

func _to_string() -> String:
	return "EntityKilledPayload(entity=%s, pos=%s, rewards=%s)" % [entity_id, death_pos, rewards]
