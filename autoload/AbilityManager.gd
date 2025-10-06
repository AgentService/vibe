## AbilityManager.gd
## Singleton for managing ability definitions and creating instances.
##
## This autoload scans res://data/content/abilities/ for .tres files,
## loads them as BaseAbility resources, and provides access to definitions.
##
## Key Responsibilities:
## - Load all ability definitions from content directory
## - Validate ability configurations on startup
## - Provide ability definitions (immutable registry entries)
## - Create ability instances (duplicated for player modification)
## - Track ability categories for UI/progression systems
##
## Usage:
##   var definition = AbilityManager.get_definition("ranger_arrow")
##   var instance = AbilityManager.create_ability_instance("ranger_arrow")
##   # instance can be modified (level-up, tome application) without affecting definition
extends Node

# ============================================================================
# REGISTRIES
# ============================================================================

## Map of ability_id → BaseAbility definition (immutable registry)
var _ability_registry: Dictionary = {}  # {ability_id: BaseAbility}

## Map of ability_id → file path (for debugging/hot-reload)
var _ability_file_paths: Dictionary = {}  # {ability_id: "res://..."}

## Map of ability_id → category name (projectile, aoe, melee, etc.)
var _ability_categories: Dictionary = {}  # {ability_id: "projectile"}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_all_abilities()
	Logger.info("AbilityManager initialized with %d abilities" % _ability_registry.size(), "abilities")


## Scans res://data/content/abilities/ subdirectories and loads all .tres files.
## Validates each ability and logs warnings for invalid configurations.
func _load_all_abilities() -> void:
	var base_path := "res://data/content/abilities/"

	# Check if base directory exists
	if not DirAccess.dir_exists_absolute(base_path):
		Logger.warn("Abilities directory not found: %s" % base_path, "abilities")
		return

	# Scan subdirectories (projectile/, aoe/, melee/, etc.)
	var dir := DirAccess.open(base_path)
	if not dir:
		Logger.error("Failed to open abilities directory: %s" % base_path, "abilities")
		return

	dir.list_dir_begin()
	var subdir_name := dir.get_next()

	while subdir_name != "":
		# Skip hidden files and non-directories
		if not subdir_name.begins_with(".") and dir.current_is_dir():
			var category := subdir_name
			var category_path := base_path.path_join(subdir_name)
			_load_abilities_from_category(category_path, category)

		subdir_name = dir.get_next()

	dir.list_dir_end()


## Loads all .tres files from a specific category directory.
func _load_abilities_from_category(category_path: String, category: String) -> void:
	var dir := DirAccess.open(category_path)
	if not dir:
		Logger.warn("Failed to open category directory: %s" % category_path, "abilities")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		# Only process .tres files
		if file_name.ends_with(".tres"):
			var file_path := category_path.path_join(file_name)
			_load_ability_file(file_path, category)

		file_name = dir.get_next()

	dir.list_dir_end()


## Loads a single ability .tres file and registers it.
func _load_ability_file(file_path: String, category: String) -> void:
	var ability := load(file_path) as BaseAbility

	if not ability:
		Logger.warn("Failed to load ability from: %s" % file_path, "abilities")
		return

	# Validate ability configuration
	var errors := ability.validate()
	if not errors.is_empty():
		Logger.warn("Ability validation errors in %s:" % file_path, "abilities")
		for error in errors:
			Logger.warn("  - %s" % error, "abilities")

	# Register ability
	var ability_id := ability.ability_id

	if ability_id.is_empty():
		Logger.error("Ability has empty ability_id: %s" % file_path, "abilities")
		return

	if _ability_registry.has(ability_id):
		Logger.warn("Duplicate ability_id '%s' (overwriting): %s" % [ability_id, file_path], "abilities")

	_ability_registry[ability_id] = ability
	_ability_file_paths[ability_id] = file_path
	_ability_categories[ability_id] = category

	Logger.debug("Loaded ability: %s (%s)" % [ability_id, category], "abilities")


# ============================================================================
# ABILITY ACCESS
# ============================================================================

## Returns the ability definition (immutable registry entry).
## Do NOT modify this directly - use create_ability_instance() for player abilities.
##
## Returns null if ability_id not found.
func get_definition(ability_id: String) -> BaseAbility:
	return _ability_registry.get(ability_id)


## Creates an independent instance of an ability for player use.
## This duplicates the definition, allowing level-up and tome modifications
## without affecting the registry.
##
## Returns null if ability_id not found.
func create_ability_instance(ability_id: String) -> BaseAbility:
	var definition := get_definition(ability_id)

	if not definition:
		Logger.warn("Attempted to create instance of unknown ability: %s" % ability_id, "abilities")
		return null

	# Deep duplicate to create independent instance
	return definition.duplicate(true) as BaseAbility


## Returns the file path for an ability (for debugging/hot-reload).
## Returns empty string if ability_id not found.
func get_file_path(ability_id: String) -> String:
	return _ability_file_paths.get(ability_id, "")


## Returns array of ability IDs in a specific category.
## Example: get_abilities_in_category("projectile") → ["ranger_arrow", "fireball", ...]
func get_abilities_in_category(category: String) -> Array[String]:
	var result: Array[String] = []

	for ability_id in _ability_categories.keys():
		if _ability_categories[ability_id] == category:
			result.append(ability_id)

	return result


## Returns all registered ability IDs.
func get_all_ability_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_ability_registry.keys())
	return result


# ============================================================================
# DEBUGGING
# ============================================================================

## Prints all registered abilities (for debugging).
func debug_print_registry() -> void:
	print("=== AbilityManager Registry ===")
	print("Total abilities: %d" % _ability_registry.size())

	for category in _get_all_categories():
		var abilities_in_category := get_abilities_in_category(category)
		print("\n[%s] (%d abilities):" % [category, abilities_in_category.size()])

		for ability_id in abilities_in_category:
			var ability := _ability_registry[ability_id] as BaseAbility
			print("  - %s (Lv%d, %s)" % [ability.ability_name, ability.ability_level, ability_id])


## Returns all unique category names.
func _get_all_categories() -> Array[String]:
	var categories: Dictionary = {}

	for category in _ability_categories.values():
		categories[category] = true

	var result: Array[String] = []
	result.assign(categories.keys())
	return result
