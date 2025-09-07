extends Resource
class_name CharacterProfile

## Character profile resource for per-character persistence.
## Stores all character-specific data including progression, metadata, and save state.

@export var id: StringName
@export var name: String = ""
@export var clazz: StringName  # "Knight" | "Ranger" | "Mage"
@export var level: int = 1
@export var exp: float = 0.0
@export var created_date: String = ""  # "YYYY-MM-DD"
@export var last_played: String = ""   # "YYYY-MM-DD"
@export var meta: Dictionary = {}      # Future: cosmetics, playtime, etc.
@export var progression: Dictionary = {}  # PlayerProgression.export_state() passthrough

func _init() -> void:
	# Set default values on creation
	var date_today := Time.get_date_string_from_system()
	created_date = date_today
	last_played = date_today

## Create a new character profile with the given parameters
static func create_new(character_name: String, character_class: StringName) -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.name = character_name
	profile.clazz = character_class
	profile.level = 1
	profile.exp = 0.0
	profile.progression = {"level": 1, "exp": 0.0, "version": 1}
	
	# Generate unique ID
	profile.id = _generate_unique_id(character_name, character_class)
	
	return profile

## Generate a unique character ID
static func _generate_unique_id(character_name: String, character_class: StringName) -> StringName:
	var base_name := str(character_class).to_lower() + "_" + _slugify(character_name)
	var suffix := ""
	var attempt := 0
	
	# Ensure uniqueness by checking if file exists
	while attempt < 100:  # Safety limit
		var test_id := base_name + suffix
		var file_path := "user://profiles/" + test_id + ".tres"
		
		if not FileAccess.file_exists(file_path):
			return StringName(test_id)
		
		attempt += 1
		suffix = "_" + _generate_random_suffix()
	
	# Fallback if somehow we can't find a unique ID
	return StringName(base_name + "_" + str(Time.get_ticks_msec()))

## Convert name to URL-friendly slug
static func _slugify(text: String) -> String:
	var result := text.to_lower()
	result = result.strip_edges()
	
	# Replace spaces and special chars with underscore
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	
	# Remove non-alphanumeric characters except underscore
	var clean := ""
	for char in result:
		if char.is_valid_identifier() or char == "_":
			clean += char
	
	# Limit length and ensure it's not empty
	if clean.length() > 20:
		clean = clean.substr(0, 20)
	if clean.is_empty():
		clean = "character"
	
	return clean

## Generate random suffix for ID uniqueness
static func _generate_random_suffix() -> String:
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result := ""
	for i in range(6):
		result += chars[randi() % chars.length()]
	return result

## Update progression data from PlayerProgression system
func sync_from_progression(progression_state: Dictionary) -> void:
	level = progression_state.get("level", 1)
	exp = progression_state.get("exp", 0.0)
	progression = progression_state.duplicate()
	last_played = Time.get_date_string_from_system()

## Get character data suitable for passing to game systems
func get_character_data() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"class": clazz,
		"level": level,
		"exp": exp
	}

## Get save file path for this character
func get_save_path() -> String:
	return "user://profiles/" + str(id) + ".tres"

## Validate character profile data
func is_valid() -> bool:
	if id.is_empty() or name.is_empty() or clazz.is_empty():
		return false
	if level < 1 or exp < 0.0:
		return false
	return true