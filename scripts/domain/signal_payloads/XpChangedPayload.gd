extends RefCounted

## Payload for xp_changed signal - experience point updates.
## Provides compile-time type safety for progression tracking.

class_name XpChangedPayload

var current_xp: int
var next_level_xp: int

func _init(current: int, next_level: int) -> void:
	current_xp = current
	next_level_xp = next_level

func _to_string() -> String:
	return "XpChangedPayload(current=%s, next_level=%s)" % [current_xp, next_level_xp]