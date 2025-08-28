extends RefCounted

## Payload for damage_batch_applied signal - multiple damage instances for AoE.
## Provides compile-time type safety for batch damage processing.

class_name DamageBatchAppliedPayload

var damage_instances: Array[Dictionary]

func _init(instances: Array[Dictionary]) -> void:
	damage_instances = instances

func _to_string() -> String:
	return "DamageBatchAppliedPayload(instances=%s)" % damage_instances.size()