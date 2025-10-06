extends Resource
class_name CardResource

## Base resource class for all cards in the game.
## Contains card identification, display properties, and stat modifiers.

@export var card_id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var level_requirement: int = 1
@export var weight: int = 1
@export var modifiers: Dictionary = {}

func is_available_at_level(level: int) -> bool:
	return level >= level_requirement

func get_display_text() -> String:
	return name + "\n" + description

func apply_to_stats(stats: Dictionary) -> void:
	for stat_name in modifiers:
		if not stats.has(stat_name):
			Logger.warn("Unknown stat: " + stat_name, "cards")
			continue
		
		var mod_value = modifiers[stat_name]
		
		# Handle different modification types
		if stat_name.ends_with("_add"):
			stats[stat_name] += mod_value
		elif stat_name.ends_with("_mult"):
			stats[stat_name] *= mod_value
		elif typeof(mod_value) == TYPE_BOOL:
			# Boolean values should be set directly
			stats[stat_name] = mod_value
		else:
			# Default to additive for numeric values
			stats[stat_name] += mod_value
	
	Logger.info("Applied card: " + name + " | Modifiers: " + str(modifiers), "cards")