extends Node

## Character management system autoload.
## Handles character creation, persistence, selection, and progression synchronization.
## Integrates with PlayerProgression for per-character save states.

# Constants
const PROFILES_DIR := "user://profiles/"
const SAVE_DEBOUNCE_TIME := 1.0  # Seconds to wait before saving after progression change

# Current state
var current_profile: CharacterProfile
var profiles: Array[CharacterProfile] = []

# Internal state
var _save_timer: Timer
var _is_initialized: bool = false

func _ready() -> void:
	Logger.info("CharacterManager initializing", "characters")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup save debounce timer
	_save_timer = Timer.new()
	_save_timer.wait_time = SAVE_DEBOUNCE_TIME
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)
	
	# Ensure profiles directory exists
	_ensure_profiles_directory()
	
	# Load existing profiles
	_scan_and_load_profiles()
	
	# Connect to progression events
	EventBus.progression_changed.connect(_on_progression_changed)
	
	_is_initialized = true
	Logger.info("CharacterManager initialized with %d profiles" % profiles.size(), "characters")

## Ensure the profiles directory exists
func _ensure_profiles_directory() -> void:
	if not DirAccess.dir_exists_absolute(PROFILES_DIR):
		var dir := DirAccess.open("user://")
		if dir:
			var result := dir.make_dir("profiles")
			if result == OK:
				Logger.info("Created profiles directory", "characters")
			else:
				Logger.error("Failed to create profiles directory: %s" % error_string(result), "characters")
		else:
			Logger.error("Failed to access user:// directory", "characters")

## Scan profiles directory and load all character profiles
func _scan_and_load_profiles() -> void:
	profiles.clear()
	
	var dir := DirAccess.open(PROFILES_DIR)
	if not dir:
		Logger.warn("Could not access profiles directory", "characters")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_count := 0
	
	while file_name != "":
		if file_name.ends_with(".tres") and not dir.current_is_dir():
			var profile := _load_profile_from_file(PROFILES_DIR + file_name)
			if profile:
				profiles.append(profile)
				loaded_count += 1
		
		file_name = dir.get_next()
	
	Logger.info("Loaded %d character profiles" % loaded_count, "characters")
	
	# Sort profiles by last_played (most recent first)
	profiles.sort_custom(_sort_profiles_by_last_played)
	
	# Emit list changed signal
	EventBus.characters_list_changed.emit(_get_profiles_summary())

## Load a character profile from file
func _load_profile_from_file(file_path: String) -> CharacterProfile:
	var profile := load(file_path) as CharacterProfile
	if not profile:
		Logger.warn("Failed to load profile from %s" % file_path, "characters")
		return null
	
	if not profile.is_valid():
		Logger.warn("Invalid profile data in %s" % file_path, "characters")
		return null
	
	return profile

## Sort profiles by last_played date (most recent first)
func _sort_profiles_by_last_played(a: CharacterProfile, b: CharacterProfile) -> bool:
	return a.last_played > b.last_played

## Create a new character profile
func create_character(character_name: String, character_class: StringName) -> CharacterProfile:
	if not _is_initialized:
		Logger.error("CharacterManager not initialized", "characters")
		return null
	
	# Validate input
	if character_name.strip_edges().is_empty():
		Logger.warn("Cannot create character with empty name", "characters")
		return null
	
	var clean_name := character_name.strip_edges()
	if clean_name.length() > 50:  # Reasonable limit
		clean_name = clean_name.substr(0, 50)
	
	# Create new profile
	var profile := CharacterProfile.create_new(clean_name, character_class)
	
	# Save profile to disk
	var save_result := _save_profile_to_disk(profile)
	if not save_result:
		Logger.error("Failed to save new character profile", "characters")
		return null
	
	# Add to profiles list
	profiles.append(profile)
	profiles.sort_custom(_sort_profiles_by_last_played)
	
	Logger.info("Created new character: %s (%s) with ID %s" % [profile.name, profile.clazz, profile.id], "characters")
	
	# Emit signals
	EventBus.character_created.emit(profile.get_character_data())
	EventBus.characters_list_changed.emit(_get_profiles_summary())
	
	return profile

## Load a character by ID and set as current
func load_character(character_id: StringName) -> void:
	if not _is_initialized:
		Logger.error("CharacterManager not initialized", "characters")
		return
	
	# Find profile by ID
	var profile: CharacterProfile = null
	for p in profiles:
		if p.id == character_id:
			profile = p
			break
	
	if not profile:
		Logger.error("Character not found: %s" % character_id, "characters")
		return
	
	# Set as current profile
	current_profile = profile
	current_profile.last_played = Time.get_date_string_from_system()
	
	Logger.info("Loaded character: %s (%s)" % [profile.name, profile.clazz], "characters")
	
	# Emit signal
	EventBus.character_selected.emit(profile.get_character_data())
	
	# Auto-save the updated last_played date
	_save_profile_to_disk(profile)

## Delete a character by ID
func delete_character(character_id: StringName) -> void:
	if not _is_initialized:
		Logger.error("CharacterManager not initialized", "characters")
		return
	
	# Find and remove profile
	var profile_index := -1
	for i in range(profiles.size()):
		if profiles[i].id == character_id:
			profile_index = i
			break
	
	if profile_index == -1:
		Logger.error("Character not found for deletion: %s" % character_id, "characters")
		return
	
	var profile := profiles[profile_index]
	
	# Delete file
	var file_path := profile.get_save_path()
	if FileAccess.file_exists(file_path):
		var result := DirAccess.remove_absolute(file_path)
		if result != OK:
			Logger.error("Failed to delete character file: %s" % error_string(result), "characters")
			return
	
	# Remove from list
	profiles.remove_at(profile_index)
	
	# Clear current profile if it was the deleted one
	if current_profile and current_profile.id == character_id:
		current_profile = null
	
	Logger.info("Deleted character: %s (%s)" % [profile.name, profile.clazz], "characters")
	
	# Emit signals
	EventBus.character_deleted.emit(character_id)
	EventBus.characters_list_changed.emit(_get_profiles_summary())

## Save current profile to disk (debounced)
func save_current() -> void:
	if not current_profile:
		return
	
	# Start/restart the debounce timer
	_save_timer.stop()
	_save_timer.start()

## Immediate save (bypasses debouncing)
func save_current_immediate() -> void:
	if not current_profile:
		return
	
	_save_profile_to_disk(current_profile)

## Get current character profile
func get_current() -> CharacterProfile:
	return current_profile

## List all character profiles
func list_characters() -> Array[CharacterProfile]:
	return profiles

## Get profiles summary for UI
func _get_profiles_summary() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for profile in profiles:
		summaries.append({
			"id": profile.id,
			"name": profile.name,
			"class": profile.clazz,
			"level": profile.level,
			"exp": profile.experience,
			"last_played": profile.last_played,
			"created_date": profile.created_date
		})
	return summaries

## Save profile to disk
func _save_profile_to_disk(profile: CharacterProfile) -> bool:
	if not profile:
		return false
	
	var file_path := profile.get_save_path()
	var result := ResourceSaver.save(profile, file_path)
	
	if result == OK:
		Logger.debug("Saved character profile: %s" % profile.name, "characters")
		return true
	else:
		Logger.error("Failed to save character profile %s: %s" % [profile.name, error_string(result)], "characters")
		return false

## Handle progression changes from PlayerProgression
func _on_progression_changed(state: Dictionary) -> void:
	if not current_profile:
		return
	
	# Update current profile with new progression state
	current_profile.sync_from_progression(state)
	
	# Trigger debounced save
	save_current()

## Handle save timer timeout
func _on_save_timer_timeout() -> void:
	if current_profile:
		_save_profile_to_disk(current_profile)
