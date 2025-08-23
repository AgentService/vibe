extends Resource
class_name CardDefinition

## Defines a single card with its properties and stat modifications.
## Used for type-safe card loading and Inspector editing.

@export var card_id: String = ""
@export_multiline var description: String = ""
@export var min_level: int = 1
@export var weight: int = 1
@export var stat_modifiers: Dictionary = {}


func get_display_text() -> String:
	return description

func is_available_at_level(level: int) -> bool:
	return level >= min_level

func get_total_weight() -> int:
	return weight