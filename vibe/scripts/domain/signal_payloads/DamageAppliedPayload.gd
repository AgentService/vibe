extends RefCounted

## Payload for damage_applied signal - single damage instance applied.
## Provides compile-time type safety for damage system results.

class_name DamageAppliedPayload

var target_id: EntityId
var final_damage: float
var is_crit: bool
var tags: PackedStringArray

func _init(target_entity: EntityId, damage: float, critical_hit: bool, damage_tags: PackedStringArray) -> void:
	target_id = target_entity
	final_damage = damage
	is_crit = critical_hit
	tags = damage_tags

func _to_string() -> String:
	return "DamageAppliedPayload(target=%s, damage=%s, crit=%s, tags=%s)" % [target_id, final_damage, is_crit, tags]