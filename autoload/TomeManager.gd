extends Node

## TomeManager - Global tome registry and definition provider
##
## Responsibilities:
## - Load all tome definitions from data/content/tomes/
## - Provide tome definitions (immutable registry entries)
## - Track tome categories for UI/progression systems
##
## Usage:
##   var definition = TomeManager.get_definition("tome_damage")
##   var tome_path = TomeManager.get_file_path("tome_damage")

# ============================================================================
# REGISTRIES
# ============================================================================

## Map of tome_id → BaseTome definition (immutable registry)
var _tome_registry: Dictionary = {}  # {tome_id: BaseTome}

## Map of tome_id → file path for hot-reload support
var _tome_file_paths: Dictionary = {}  # {tome_id: "res://..."}

## Map of tome_id → category string (for UI organization)
var _tome_categories: Dictionary = {}  # {tome_id: "damage" | "cooldown" | "utility"}


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_all_tomes()


## Loads all tome definitions from the tomes content directory.
## Populates _tome_registry, _tome_file_paths, and _tome_categories.
func _load_all_tomes() -> void:
	Logger.info("TomeManager: Loading tomes...", "tomes")

	# Load tomes from main tomes directory
	_load_tomes_from_directory("res://data/content/tomes/")

	Logger.info("TomeManager: Loaded %d tomes" % _tome_registry.size(), "tomes")


## Scans a directory for .tres files and loads them as BaseTome resources.
func _load_tomes_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		Logger.warn("Failed to open tome directory: " + dir_path, "tomes")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path := dir_path + file_name
			_load_tome_from_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Loads a single tome resource from file and registers it.
func _load_tome_from_file(file_path: String) -> void:
	# Use CACHE_MODE_IGNORE for hot-reload support
	var tome = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not tome:
		Logger.warn("Failed to load tome: " + file_path, "tomes")
		return

	# Validate tome has required properties
	if not "tome_id" in tome or tome.tome_id.is_empty():
		Logger.warn("Tome missing tome_id: " + file_path, "tomes")
		return

	# Register tome
	var tome_id: String = tome.tome_id
	_tome_registry[tome_id] = tome
	_tome_file_paths[tome_id] = file_path

	# Categorize tome (simple heuristic based on modifiers)
	var category := _categorize_tome(tome)
	_tome_categories[tome_id] = category

	Logger.debug("Loaded tome: %s (%s)" % [tome_id, category], "tomes")


## Categorizes a tome based on its modifiers.
## Returns "damage", "cooldown", or "utility".
func _categorize_tome(tome) -> String:
	# Check damage multiplier
	if "damage_multiplier" in tome and tome.damage_multiplier != 1.0:
		return "damage"

	# Check cooldown multiplier
	if "cooldown_multiplier" in tome and tome.cooldown_multiplier != 1.0:
		return "cooldown"

	# Default to utility
	return "utility"


# ============================================================================
# TOME ACCESS
# ============================================================================

## Returns the tome definition (immutable registry entry).
## Returns null if tome_id not found.
func get_definition(tome_id: String):
	return _tome_registry.get(tome_id)


## Returns the file path for a tome (for debugging/hot-reload).
## Returns empty string if tome_id not found.
func get_file_path(tome_id: String) -> String:
	return _tome_file_paths.get(tome_id, "")


## Returns the category for a tome.
## Returns empty string if tome_id not found.
func get_category(tome_id: String) -> String:
	return _tome_categories.get(tome_id, "")


## Returns all tome IDs in the registry.
func get_all_tome_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _tome_registry.keys():
		ids.append(id)
	return ids


## Returns all tomes in a specific category.
func get_tomes_by_category(category: String) -> Array:
	var tomes: Array = []
	for tome_id in _tome_categories:
		if _tome_categories[tome_id] == category:
			var tome = _tome_registry.get(tome_id)
			if tome:
				tomes.append(tome)
	return tomes
