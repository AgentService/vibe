extends RefCounted

## Payload for loot_generated signal - treasure and reward creation.
## Provides compile-time type safety for loot system coordination.

class_name LootGeneratedPayload

var source_id: String
var source_type: String
var loot_data: Dictionary

func _init(src_id: String, src_type: String, loot: Dictionary) -> void:
	source_id = src_id
	source_type = src_type
	loot_data = loot

func _to_string() -> String:
	return "LootGeneratedPayload(source=%s, type=%s, loot=%s)" % [source_id, source_type, loot_data]