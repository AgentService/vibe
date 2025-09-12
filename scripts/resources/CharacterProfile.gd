extends Resource
class_name CharacterProfile

## Character profile resource for per-character persistence.
## Stores all character-specific data including progression, metadata, and save state.

@export var id: StringName
@export var name: String = ""
@export var clazz: StringName  # "Knight" | "Ranger" | "Mage"
@export var level: int = 1
@export var experience: float = 0.0
@export var created_date: String = ""  # "YYYY-MM-DD"
@export var last_played: String = ""   # "YYYY-MM-DDTHH:MM:SS"
@export var meta: Dictionary = {}      # Future: cosmetics, playtime, etc.
@export var progression: Dictionary = {}  # PlayerProgression.export_state() passthrough

func _init() -> void:
	# Set default values on creation
	var date_today := Time.get_date_string_from_system()
	var timestamp_now := Time.get_datetime_string_from_system()
	created_date = date_today
	last_played = timestamp_now

## Create a new character profile with the given parameters
static func create_new(character_name: String, character_class: StringName) -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.name = character_name
	profile.clazz = character_class
	profile.level = 1
	profile.experience = 0.0
	profile.progression = {"level": 1, "exp": 0.0, "version": 1}  # Keep 'exp' key for save compatibility
	
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
	for character in result:
		if character.is_valid_identifier() or character == "_":
			clean += character
	
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
	var old_level = level
	var old_exp = experience
	
	var new_level = progression_state.get("level", 1)
	var new_experience = progression_state.get("exp", 0.0)
	
	# Validate data consistency - prevent impossible states
	if new_level > 1 and new_experience <= 0.0:
		Logger.warn("sync_from_progression received invalid data: Level %d with %.1f XP - rejecting update" % [new_level, new_experience], "characters")
		return
	
	# Atomic update - both level and experience change together
	level = new_level
	experience = new_experience
	progression = progression_state.duplicate()
	last_played = Time.get_datetime_string_from_system()
	
	Logger.debug("CharacterProfile updated: Level %d, XP %.1f" % [level, experience], "characters")

## Get progression data for PlayerProgression loading - ensures data consistency
func get_progression_data() -> Dictionary:
	# Always return current authoritative data, not cached progression dict
	# This prevents stale data issues when progression dict is out of sync
	var current_data = {
		"level": level,
		"exp": experience,
		"version": 1
	}
	
	# Update cached progression dict to match
	progression = current_data.duplicate()
	
	return current_data

## Get character data suitable for passing to game systems
func get_character_data() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"class": clazz,
		"level": level,
		"exp": experience
	}

## Get save file path for this character
func get_save_path() -> String:
	return "user://profiles/" + str(id) + ".tres"

## Validate and repair character profile data
func is_valid() -> bool:
	if id.is_empty() or name.is_empty() or clazz.is_empty():
		return false
	if level < 1 or experience < 0.0:
		return false
	return true

## Repair corrupted character progression data
func repair_progression_if_needed() -> bool:
	var was_repaired = false
	
	# Detect corruption: Level > 1 but Experience = 0 (impossible - you need XP to gain levels)
	if level > 1 and experience <= 0.0:
		Logger.warn("Detected corrupted character progression: Level %d with %.1f XP (impossible)" % [level, experience], "debug")
		
		# Load XP curve to calculate correct minimum experience for this level
		var xp_curve_resource = load("res://data/core/progression-xp-curve.tres")
		if xp_curve_resource and xp_curve_resource.is_valid():
			var min_xp_for_level = xp_curve_resource.get_xp_for_level(level)
			if min_xp_for_level > 0:
				experience = float(min_xp_for_level)
				Logger.info("Repaired character %s: Set XP to %.1f (minimum for Level %d)" % [name, experience, level], "debug")
				
				# Update progression dict to match
				progression = {
					"level": level,
					"exp": experience,
					"version": 1
				}
				
				was_repaired = true
			else:
				Logger.error("Failed to get XP requirement for level %d, using fallback" % level, "debug")
				experience = float((level - 1) * 100)  # Fallback: 100 XP per level
				was_repaired = true
		else:
			Logger.error("XP curve resource not available for repair, using fallback", "debug")
			experience = float((level - 1) * 100)  # Fallback: 100 XP per level
			was_repaired = true
		
		if was_repaired:
			Logger.info("Character progression repaired: %s now has Level %d, XP %.1f" % [name, level, experience], "debug")
	
	return was_repaired
