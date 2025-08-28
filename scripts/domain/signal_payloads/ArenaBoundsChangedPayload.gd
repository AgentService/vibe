extends RefCounted

## Payload for arena_bounds_changed signal - arena boundary updates.
## Provides compile-time type safety for camera and UI boundary coordination.

class_name ArenaBoundsChangedPayload

var bounds: Rect2

func _init(arena_bounds: Rect2) -> void:
	bounds = arena_bounds

func _to_string() -> String:
	return "ArenaBoundsChangedPayload(bounds=%s)" % bounds