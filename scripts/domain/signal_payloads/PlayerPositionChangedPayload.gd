extends RefCounted

## Payload for player_position_changed signal - cached player position updates.
## Provides compile-time type safety for camera following and system coordination.

class_name PlayerPositionChangedPayload

var position: Vector2

func _init(player_pos: Vector2) -> void:
	position = player_pos

func _to_string() -> String:
	return "PlayerPositionChangedPayload(pos=%s)" % position