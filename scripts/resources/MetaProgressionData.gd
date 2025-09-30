extends Resource
class_name MetaProgressionData

## Meta-progression save data for permanent unlocks across runs.
## Single save file: user://meta_progression.tres

# Currency
@export var rift_fragments: int = 0

# Character unlocks
@export var unlocked_characters: Array[String] = []
@export var unlocked_maps: Array[String] = []

# Item discovery & unlock system (MEGABONK-style)
@export var discovered_items: Array[String] = []
@export var unlocked_items: Array[String] = []
@export var discovered_skills: Array[String] = []
@export var unlocked_skills: Array[String] = []
@export var discovered_tomes: Array[String] = []
@export var unlocked_tomes: Array[String] = []

# Achievement system
@export var achievements: Dictionary = {}  # {"first_boss_kill": true, ...}
@export var character_achievements: Dictionary = {}  # {"fuchs": {"kills_1000": true}, ...}
@export var unlocked_skins: Dictionary = {}  # {"fuchs": ["default", "blue"], ...}
@export var character_runs: Dictionary = {}  # {"fuchs": 15, ...}

# Toggler system (requires 40 unlocks per category)
@export var toggler_item_enabled: bool = false
@export var toggler_disabled_items: Array[String] = []
@export var toggler_skill_enabled: bool = false
@export var toggler_disabled_skills: Array[String] = []
@export var toggler_tome_enabled: bool = false
@export var toggler_disabled_tomes: Array[String] = []


## Creates default starting progression data
func _init() -> void:
	# Start with one default character and map unlocked
	unlocked_characters = ["fuchs"]  # Default character
	unlocked_maps = ["forest"]  # Default map
	rift_fragments = 0


## Creates a fresh progression data instance with defaults
static func create_default() -> MetaProgressionData:
	var data := MetaProgressionData.new()
	return data


## Exports state as Dictionary for debugging/logging
func to_dict() -> Dictionary:
	return {
		"rift_fragments": rift_fragments,
		"unlocked_characters": unlocked_characters,
		"unlocked_maps": unlocked_maps,
		"discovered_items": discovered_items.size(),
		"unlocked_items": unlocked_items.size(),
		"toggler_item_enabled": toggler_item_enabled,
	}