extends Node

## CharacterManager - Global character registry
##
## Architecture Pattern (2025-10-14):
##   - Single-resource pattern (following BaseItem/BaseTome architecture)
##   - BaseCharacter = Gameplay (stats, starting abilities) + Shop metadata (UI, unlock)
##   - File naming: {character_id}.tres (unified single file)
##   - ItemManager pattern: Hot-reload support, directory scanning
##
## Responsibilities:
##   - Load all character definitions from data/content/characters/
##   - Provide unified character data (stats + shop metadata in BaseCharacter)
##   - Validate character configurations
##
## Usage:
##   var character = CharacterManager.get_character("ranger")
##   print(character.character_name)  # "Ranger"
##   print(character.base_max_hp)     # 80

# ============================================================================
# REGISTRY (Single Source of Truth)
# ============================================================================

## Map of character_id → BaseCharacter (unified: stats + shop metadata)
var _character_registry: Dictionary = {}  # {character_id: BaseCharacter}

## Map of character_id → file path for hot-reload support
var _character_file_paths: Dictionary = {}  # {character_id: "res://..."}


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_all_characters()


## Loads all character definitions from the characters content directory.
## Populates _character_registry with unified BaseCharacter resources.
func _load_all_characters() -> void:
	Logger.info("CharacterManager: Loading characters...", "characters")

	# Load characters from main characters directory
	_load_characters_from_directory("res://data/content/characters/")

	Logger.info("CharacterManager: Loaded %d characters" % _character_registry.size(), "characters")


## Scans a directory for .tres files and loads them as unified BaseCharacter resources.
## Clean single-resource pattern (no suffix checking, no dual loading).
func _load_characters_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		Logger.warn("Failed to open character directory: " + dir_path, "characters")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path := dir_path + file_name
			var character = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)

			# Only load BaseCharacter resources (skip any other .tres files)
			if character is BaseCharacter:
				_register_character(character, file_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Registers a BaseCharacter in the registry (single source of truth).
func _register_character(character: BaseCharacter, file_path: String) -> void:
	# Validate character has required properties
	if character.character_id.is_empty():
		Logger.warn("BaseCharacter missing character_id: " + file_path, "characters")
		return

	# Validate character configuration
	var errors := character.validate()
	if not errors.is_empty():
		Logger.warn("BaseCharacter '%s' has validation errors: %s" % [
			character.character_id, str(errors)
		], "characters")
		return

	# Register character
	var character_id: String = character.character_id
	_character_registry[character_id] = character
	_character_file_paths[character_id] = file_path

	Logger.debug("Loaded character: %s (%s)" % [character_id, character.character_name], "characters")


# ============================================================================
# CHARACTER ACCESS (Public API)
# ============================================================================

## Returns the unified BaseCharacter (stats + shop metadata).
## Returns null if character_id not found.
func get_character(character_id: String) -> BaseCharacter:
	return _character_registry.get(character_id) as BaseCharacter


## Returns the file path for a character (for debugging/hot-reload).
## Returns empty string if character_id not found.
func get_file_path(character_id: String) -> String:
	return _character_file_paths.get(character_id, "")


## Returns all character IDs in the registry.
func get_all_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _character_registry.keys():
		ids.append(id)
	return ids


## Returns all characters sorted by unlock cost (default characters first).
## Useful for character selection UI display order.
func get_all_characters_sorted() -> Array:
	var characters: Array = []
	for character in _character_registry.values():
		characters.append(character)

	# Sort by unlock_cost (0 = default character, comes first)
	characters.sort_custom(func(a: BaseCharacter, b: BaseCharacter) -> bool:
		return a.unlock_cost < b.unlock_cost
	)

	return characters


## Returns the default starting character (unlock_cost = 0).
## Returns first character in registry if no default found.
func get_default_character() -> BaseCharacter:
	# Find character with unlock_cost = 0
	for character in _character_registry.values():
		if character.unlock_cost == 0:
			return character

	# Fallback: Return first character in registry
	if not _character_registry.is_empty():
		return _character_registry.values()[0]

	Logger.warn("CharacterManager: No characters loaded", "characters")
	return null


# ============================================================================
# HOT-RELOAD SUPPORT
# ============================================================================

## Reloads a specific character from disk (for hot-reload during development).
## Returns true if successful, false if character not found or load failed.
func reload_character(character_id: String) -> bool:
	var file_path := get_file_path(character_id)
	if file_path.is_empty():
		Logger.warn("CharacterManager: Cannot reload unknown character: " + character_id, "characters")
		return false

	var character = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not character is BaseCharacter:
		Logger.warn("CharacterManager: Failed to reload character: " + character_id, "characters")
		return false

	_register_character(character, file_path)
	Logger.info("CharacterManager: Reloaded character: " + character_id, "characters")
	return true


## Reloads all characters from disk (for hot-reload during development).
func reload_all_characters() -> void:
	Logger.info("CharacterManager: Reloading all characters...", "characters")
	_character_registry.clear()
	_character_file_paths.clear()
	_load_all_characters()
