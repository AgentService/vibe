extends RefCounted

## Payload for enemy_killed signal - legacy enemy death event.
## Provides compile-time type safety for backward compatibility.
## NOTE: Consider migrating to EntityKilledPayload for new code.

class_name EnemyKilledPayload

var pos: Vector2
var xp_value: int

func _init(position: Vector2, xp: int) -> void:
	pos = position
	xp_value = xp

func _to_string() -> String:
	# Only generate debug string when in debug mode to save memory
	if Logger and Logger.is_debug():
		return "EnemyKilledPayload(pos=%s, xp=%s)" % [pos, xp_value]
	else:
		return "EnemyKilledPayload"