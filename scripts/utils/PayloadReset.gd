extends RefCounted
class_name PayloadReset

## Static utility functions for resetting damage payloads without changing object shapes.
## Preserving object shapes prevents GDScript from reallocating dictionaries,
## maintaining zero-allocation behavior in the damage queue system.

## Clear a damage payload dictionary to default values.
## Preserves all keys to avoid shape changes and maintains zero-allocation.
## @param d: Dictionary damage payload to reset
static func clear_damage_payload(d: Dictionary) -> void:
	# Preserve keys to avoid shape changes; reset values to defaults
	d["target"] = &""
	d["source"] = &""
	d["base_damage"] = 0.0
	d["damage_type"] = &"generic"
	d["knockback"] = 0.0
	d["source_pos"] = Vector2.ZERO
	
	# Clear tags array without replacing it (preserve array shape)
	var tags: Array = d.get("tags", [])
	if tags:
		tags.clear()
	else:
		# Ensure tags key exists with empty array
		d["tags"] = []

## Clear a generic Array without reallocating.
## @param arr: Array to clear
static func clear_array(arr: Array) -> void:
	arr.clear()

## Clear a StringName array for tags.
## @param tags: Array[StringName] to clear
static func clear_tags_array(tags: Array) -> void:
	tags.clear()

## Factory function for creating damage payload dictionaries.
## Used by ObjectPool to create consistent payload shapes.
static func create_damage_payload() -> Dictionary:
	return {
		"target": &"",
		"source": &"",
		"base_damage": 0.0,
		"damage_type": &"generic",
		"knockback": 0.0,
		"source_pos": Vector2.ZERO,
		"tags": []
	}

## Factory function for creating tag arrays.
## Used by ObjectPool to create consistent tag array shapes.
static func create_tags_array() -> Array:
	return []

## Factory function for creating entity update payload dictionaries.
## Used by ObjectPool for zero-allocation entity position updates.
static func create_entity_update_payload() -> Dictionary:
	return {
		"entity_id": &"",
		"position": Vector2.ZERO
	}

## Clear an entity update payload dictionary to default values.
## Preserves all keys to avoid shape changes and maintains zero-allocation.
## @param d: Dictionary entity update payload to reset
static func clear_entity_update_payload(d: Dictionary) -> void:
	# Preserve keys to avoid shape changes; reset values to defaults
	d["entity_id"] = &""
	d["position"] = Vector2.ZERO
