extends RefCounted

## Payload for level_up signal - player level advancement.
## Provides compile-time type safety for level progression events.

class_name LevelUpPayload

var new_level: int

func _init(level: int) -> void:
	new_level = level

func _to_string() -> String:
	return "LevelUpPayload(level=%s)" % new_level