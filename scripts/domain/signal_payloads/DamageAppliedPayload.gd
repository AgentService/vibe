extends RefCounted

## Payload for damage_applied signal - single damage instance applied.
## Provides compile-time type safety for damage system results.

class_name DamageAppliedPayload

var target_id: EntityId
var final_damage: float
var is_crit: bool
var tags: PackedStringArray
var knockback_distance: float
var source_position: Vector2

func _init(target_entity: EntityId, damage: float, critical_hit: bool, damage_tags: PackedStringArray, knockback_dist: float = 0.0, source_pos: Vector2 = Vector2.ZERO) -> void:
	target_id = target_entity
	final_damage = damage
	is_crit = critical_hit
	tags = damage_tags
	knockback_distance = knockback_dist
	source_position = source_pos

func reset() -> void:
	target_id = null
	final_damage = 0.0
	is_crit = false
	tags = PackedStringArray()
	knockback_distance = 0.0
	source_position = Vector2.ZERO

func setup(target_entity: EntityId, damage: float, critical_hit: bool, damage_tags: PackedStringArray, knockback_dist: float = 0.0, source_pos: Vector2 = Vector2.ZERO) -> void:
	target_id = target_entity
	final_damage = damage
	is_crit = critical_hit
	tags = damage_tags
	knockback_distance = knockback_dist
	source_position = source_pos

func _to_string() -> String:
	# Only generate debug string when in debug mode to save memory
	if Logger and Logger.is_debug():
		return "DamageAppliedPayload(target=%s, damage=%s, crit=%s, tags=%s, knockback=%s)" % [target_id, final_damage, is_crit, tags, knockback_distance]
	else:
		return "DamageAppliedPayload"
