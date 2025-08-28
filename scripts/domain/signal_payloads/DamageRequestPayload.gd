extends RefCounted

## Payload for damage_requested signal - request damage calculation.
## Provides compile-time type safety for cross-system damage coordination.

class_name DamageRequestPayload

var source_id: EntityId
var target_id: EntityId
var base_damage: float
var tags: PackedStringArray
var knockback_distance: float
var source_position: Vector2

func _init(source_entity: EntityId, target_entity: EntityId, damage: float, damage_tags: PackedStringArray, knockback_dist: float = 0.0, source_pos: Vector2 = Vector2.ZERO) -> void:
	source_id = source_entity
	target_id = target_entity
	base_damage = damage
	tags = damage_tags
	knockback_distance = knockback_dist
	source_position = source_pos

func _to_string() -> String:
	return "DamageRequestPayload(source=%s, target=%s, damage=%s, tags=%s, knockback=%s)" % [source_id, target_id, base_damage, tags, knockback_distance]
