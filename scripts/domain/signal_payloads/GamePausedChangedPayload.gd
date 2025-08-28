extends RefCounted

## Payload for game_paused_changed signal - game state coordination.
## Provides compile-time type safety for pause system management.

class_name GamePausedChangedPayload

var is_paused: bool

func _init(paused: bool) -> void:
	is_paused = paused

func _to_string() -> String:
	return "GamePausedChangedPayload(paused=%s)" % is_paused