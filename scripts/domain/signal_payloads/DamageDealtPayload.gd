extends RefCounted

## Payload for damage_dealt signal - damage events for camera shake.
## Provides compile-time type safety for visual feedback coordination.

class_name DamageDealtPayload

var damage: float
var source: String
var target: String

func _init(dealt_damage: float, damage_source: String, damage_target: String) -> void:
	damage = dealt_damage
	source = damage_source
	target = damage_target

func _to_string() -> String:
	return "DamageDealtPayload(damage=%s, source=%s, target=%s)" % [damage, source, target]