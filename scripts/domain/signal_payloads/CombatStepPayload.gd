extends RefCounted

## Payload for combat_step signal - fixed 30Hz timing updates.
## Provides compile-time type safety for deterministic combat timing.

class_name CombatStepPayload

var dt: float

func _init(delta_time: float) -> void:
	dt = delta_time

func _to_string() -> String:
	return "CombatStepPayload(dt=%s)" % dt