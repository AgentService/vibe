extends Node

## Meta-progression autoload for permanent unlocks across runs.
## Replaces old CharacterManager with single-session run architecture.
## Save file: user://meta_progression.tres

# Save path constants
const SAVE_DIR: String = "user://"
const SAVE_FILE: String = "meta_progression.tres"
const SAVE_PATH: String = SAVE_DIR + SAVE_FILE

# Meta-progression data
var _data: MetaProgressionData = null
var _is_initialized: bool = false


## Initializes MetaProgression and loads save data
func _ready() -> void:
	Logger.info("MetaProgression initializing", "progression")
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load or create save data
	_data = _load_or_create()
	_is_initialized = true

	Logger.info("MetaProgression initialized - Rift Fragments: %d, Characters: %d" % [
		_data.rift_fragments,
		_data.unlocked_characters.size()
	], "progression")

	# Emit loaded signal
	EventBus.meta_progression_loaded.emit()


## Loads existing save or creates new one
func _load_or_create() -> MetaProgressionData:
	if not FileAccess.file_exists(SAVE_PATH):
		Logger.info("No save file found, creating default progression", "progression")
		var new_data := MetaProgressionData.create_default()
		save()
		return new_data

	var loaded_data := ResourceLoader.load(SAVE_PATH) as MetaProgressionData
	if loaded_data == null:
		Logger.error("Failed to load meta_progression.tres, creating default", "progression")
		return MetaProgressionData.create_default()

	Logger.info("Meta-progression loaded from disk", "progression")
	return loaded_data


## Saves meta-progression to disk
func save() -> void:
	if not _is_initialized:
		Logger.warn("MetaProgression not initialized, cannot save", "progression")
		return

	var result := ResourceSaver.save(_data, SAVE_PATH)
	if result != OK:
		Logger.error("Failed to save meta_progression.tres (Error: %d)" % result, "progression")
	else:
		Logger.debug("Meta-progression saved to disk", "progression")


## Resets meta-progression to default state (WARNING: destructive)
func reset() -> void:
	Logger.warn("Resetting meta-progression to default state", "progression")
	_data = MetaProgressionData.create_default()
	save()
	EventBus.meta_progression_loaded.emit()


# ═══════════════════════════════════════════════════════════════════
# RIFT FRAGMENTS (Currency)
# ═══════════════════════════════════════════════════════════════════

## Adds Rift Fragments from end-of-run rewards
func earn_rift_fragments(amount: int) -> void:
	if amount <= 0:
		Logger.warn("Cannot earn negative or zero Rift Fragments: %d" % amount, "progression")
		return

	_data.rift_fragments += amount
	Logger.info("Earned %d Rift Fragments (Total: %d)" % [amount, _data.rift_fragments], "progression")
	EventBus.rift_fragments_changed.emit(_data.rift_fragments)
	save()


## Spends Rift Fragments for unlocks, returns true if successful
func spend_rift_fragments(amount: int) -> bool:
	if amount <= 0:
		Logger.warn("Cannot spend negative or zero Rift Fragments: %d" % amount, "progression")
		return false

	if not can_afford(amount):
		Logger.warn("Insufficient Rift Fragments (Have: %d, Need: %d)" % [_data.rift_fragments, amount], "progression")
		return false

	_data.rift_fragments -= amount
	Logger.info("Spent %d Rift Fragments (Remaining: %d)" % [amount, _data.rift_fragments], "progression")
	EventBus.rift_fragments_changed.emit(_data.rift_fragments)
	save()
	return true


## Checks if player can afford a purchase
func can_afford(amount: int) -> bool:
	return _data.rift_fragments >= amount


## Gets current Rift Fragments balance
func get_rift_fragments() -> int:
	return _data.rift_fragments


# ═══════════════════════════════════════════════════════════════════
# CHARACTER UNLOCKS
# ═══════════════════════════════════════════════════════════════════

## Unlocks a character by ID
func unlock_character(character_id: String) -> void:
	if is_character_unlocked(character_id):
		Logger.debug("Character already unlocked: %s" % character_id, "progression")
		return

	_data.unlocked_characters.append(character_id)
	Logger.info("Character unlocked: %s" % character_id, "progression")
	EventBus.character_unlocked.emit(character_id)
	save()


## Checks if a character is unlocked
func is_character_unlocked(character_id: String) -> bool:
	return character_id in _data.unlocked_characters


## Gets list of all unlocked characters
func get_unlocked_characters() -> Array[String]:
	return _data.unlocked_characters.duplicate()


## Increments run count for a character
func increment_character_runs(character_id: String) -> void:
	var current_runs: int = _data.character_runs.get(character_id, 0)
	_data.character_runs[character_id] = current_runs + 1
	Logger.debug("Character %s run count: %d" % [character_id, current_runs + 1], "progression")
	save()


## Gets run count for a character
func get_character_runs(character_id: String) -> int:
	return _data.character_runs.get(character_id, 0)


# ═══════════════════════════════════════════════════════════════════
# MAP UNLOCKS
# ═══════════════════════════════════════════════════════════════════

## Unlocks a map by ID
func unlock_map(map_id: String) -> void:
	if is_map_unlocked(map_id):
		Logger.debug("Map already unlocked: %s" % map_id, "progression")
		return

	_data.unlocked_maps.append(map_id)
	Logger.info("Map unlocked: %s" % map_id, "progression")
	save()


## Checks if a map is unlocked
func is_map_unlocked(map_id: String) -> bool:
	return map_id in _data.unlocked_maps


## Gets list of all unlocked maps
func get_unlocked_maps() -> Array[String]:
	return _data.unlocked_maps.duplicate()


# ═══════════════════════════════════════════════════════════════════
# ITEM DISCOVERY & UNLOCK SYSTEM (MEGABONK-style)
# ═══════════════════════════════════════════════════════════════════

## Discovers an item in a run (adds to discovered list)
func discover_item(category: String, item_id: String) -> void:
	var discovered_array := _get_discovered_array(category)
	if discovered_array == null:
		Logger.error("Invalid category for discover_item: %s" % category, "progression")
		return

	# Check if already discovered or unlocked
	if item_id in discovered_array:
		return

	var unlocked_array := _get_unlocked_array(category)
	if item_id in unlocked_array:
		return

	discovered_array.append(item_id)
	Logger.info("Discovered new %s: %s" % [category, item_id], "progression")
	save()


## Unlocks an item (moves from discovered to unlocked)
func unlock_item(category: String, item_id: String) -> void:
	var discovered_array := _get_discovered_array(category)
	var unlocked_array := _get_unlocked_array(category)

	if discovered_array == null or unlocked_array == null:
		Logger.error("Invalid category for unlock_item: %s" % category, "progression")
		return

	# Remove from discovered
	var idx := discovered_array.find(item_id)
	if idx >= 0:
		discovered_array.remove_at(idx)

	# Add to unlocked if not already
	if item_id not in unlocked_array:
		unlocked_array.append(item_id)
		Logger.info("Unlocked %s: %s" % [category, item_id], "progression")
		EventBus.item_unlocked.emit(category, item_id)
		save()


## Removes item from discovered array (admin/debug only)
func _remove_item_from_discovered(category: String, item_id: String) -> void:
	var discovered_array := _get_discovered_array(category)
	if discovered_array == null:
		return

	var idx := discovered_array.find(item_id)
	if idx >= 0:
		discovered_array.remove_at(idx)
		Logger.debug("Removed %s from discovered_%s" % [item_id, category], "progression")


## Removes item from unlocked array (admin/debug only)
func _remove_item_from_unlocked(category: String, item_id: String) -> void:
	var unlocked_array := _get_unlocked_array(category)
	if unlocked_array == null:
		return

	var idx := unlocked_array.find(item_id)
	if idx >= 0:
		unlocked_array.remove_at(idx)
		Logger.debug("Removed %s from unlocked_%s" % [item_id, category], "progression")


## Checks if an item is unlocked
func is_item_unlocked(category: String, item_id: String) -> bool:
	var unlocked_array := _get_unlocked_array(category)
	if unlocked_array == null:
		return false
	return item_id in unlocked_array


## Checks if an item is discovered but not unlocked
func is_item_discovered(category: String, item_id: String) -> bool:
	var discovered_array := _get_discovered_array(category)
	if discovered_array == null:
		return false
	return item_id in discovered_array


## Gets discovered items for a category (not yet purchased)
func get_discovered_items(category: String) -> Array[String]:
	var discovered_array := _get_discovered_array(category)
	if discovered_array == null:
		return []
	return discovered_array.duplicate()


## Gets unlocked items for a category
func get_unlocked_items(category: String) -> Array[String]:
	var unlocked_array := _get_unlocked_array(category)
	if unlocked_array == null:
		return []
	return unlocked_array.duplicate()


## Helper: Gets discovered array for category
func _get_discovered_array(category: String) -> Array[String]:
	match category:
		"items":
			return _data.discovered_items
		"skills":
			return _data.discovered_skills
		"tomes":
			return _data.discovered_tomes
		_:
			var empty: Array[String] = []
			return empty


## Helper: Gets unlocked array for category
func _get_unlocked_array(category: String) -> Array[String]:
	match category:
		"items":
			return _data.unlocked_items
		"skills":
			return _data.unlocked_skills
		"tomes":
			return _data.unlocked_tomes
		_:
			var empty: Array[String] = []
			return empty


# ═══════════════════════════════════════════════════════════════════
# TOGGLER SYSTEM (Disable Unlocked Items)
# ═══════════════════════════════════════════════════════════════════

## Enables toggler for a category (requires 40 unlocks)
func enable_toggler(category: String) -> void:
	var unlocked_count := get_unlocked_items(category).size()
	if unlocked_count < 40:
		Logger.warn("Cannot enable toggler for %s: only %d/40 unlocks" % [category, unlocked_count], "progression")
		return

	match category:
		"items":
			if _data.toggler_item_enabled:
				return
			_data.toggler_item_enabled = true
		"skills":
			if _data.toggler_skill_enabled:
				return
			_data.toggler_skill_enabled = true
		"tomes":
			if _data.toggler_tome_enabled:
				return
			_data.toggler_tome_enabled = true
		_:
			Logger.error("Invalid category for enable_toggler: %s" % category, "progression")
			return

	Logger.info("Toggler enabled for category: %s" % category, "progression")
	EventBus.toggler_unlocked.emit(category)
	save()


## Checks if toggler is enabled for a category
func is_toggler_enabled(category: String) -> bool:
	match category:
		"items":
			return _data.toggler_item_enabled
		"skills":
			return _data.toggler_skill_enabled
		"tomes":
			return _data.toggler_tome_enabled
		_:
			return false


## Toggles an item (adds/removes from disabled list)
func toggle_item(category: String, item_id: String, enabled: bool) -> void:
	if not is_toggler_enabled(category):
		Logger.warn("Toggler not enabled for category: %s" % category, "progression")
		return

	var disabled_array := _get_disabled_array(category)
	if disabled_array == null:
		return

	if enabled:
		# Remove from disabled list (enable item)
		var idx := disabled_array.find(item_id)
		if idx >= 0:
			disabled_array.remove_at(idx)
			Logger.debug("Enabled %s: %s" % [category, item_id], "progression")
	else:
		# Add to disabled list (disable item)
		if item_id not in disabled_array:
			disabled_array.append(item_id)
			Logger.debug("Disabled %s: %s" % [category, item_id], "progression")

	save()


## Checks if an item is disabled via toggler
func is_item_disabled(category: String, item_id: String) -> bool:
	var disabled_array := _get_disabled_array(category)
	if disabled_array == null:
		return false
	return item_id in disabled_array


## Helper: Gets disabled array for category
func _get_disabled_array(category: String) -> Array[String]:
	match category:
		"items":
			return _data.toggler_disabled_items
		"skills":
			return _data.toggler_disabled_skills
		"tomes":
			return _data.toggler_disabled_tomes
		_:
			var empty: Array[String] = []
			return empty


# ═══════════════════════════════════════════════════════════════════
# ACHIEVEMENTS
# ═══════════════════════════════════════════════════════════════════

## Unlocks a global achievement
func unlock_achievement(achievement_id: String) -> void:
	if _data.achievements.get(achievement_id, false):
		return

	_data.achievements[achievement_id] = true
	Logger.info("Achievement unlocked: %s" % achievement_id, "progression")
	save()


## Checks if a global achievement is unlocked
func has_achievement(achievement_id: String) -> bool:
	return _data.achievements.get(achievement_id, false)


## Unlocks a character-specific achievement
func unlock_character_achievement(character_id: String, achievement_id: String) -> void:
	if not _data.character_achievements.has(character_id):
		_data.character_achievements[character_id] = {}

	var char_achievements: Dictionary = _data.character_achievements[character_id]
	if char_achievements.get(achievement_id, false):
		return

	char_achievements[achievement_id] = true
	Logger.info("Character achievement unlocked: %s - %s" % [character_id, achievement_id], "progression")
	save()


## Checks if a character-specific achievement is unlocked
func has_character_achievement(character_id: String, achievement_id: String) -> bool:
	if not _data.character_achievements.has(character_id):
		return false
	var char_achievements: Dictionary = _data.character_achievements[character_id]
	return char_achievements.get(achievement_id, false)


## Unlocks a skin for a character
func unlock_skin(character_id: String, skin_id: String) -> void:
	if not _data.unlocked_skins.has(character_id):
		_data.unlocked_skins[character_id] = []

	var skins: Array = _data.unlocked_skins[character_id]
	if skin_id in skins:
		return

	skins.append(skin_id)
	Logger.info("Skin unlocked: %s - %s" % [character_id, skin_id], "progression")
	save()


## Gets unlocked skins for a character
func get_unlocked_skins(character_id: String) -> Array:
	if not _data.unlocked_skins.has(character_id):
		return ["default"]  # Always have default skin
	return _data.unlocked_skins[character_id].duplicate()


# ═══════════════════════════════════════════════════════════════════
# TIER PROGRESSION SYSTEM (3 stages per tier, unlimited tier 4)
# ═══════════════════════════════════════════════════════════════════

const STAGES_PER_TIER: int = 3  # Tier 1-3 each have 3 stages
const UNLIMITED_TIER: int = 4   # Tier 4 = Unlimited mode

## Unlocks a tier (called when player completes all stages of previous tier)
func unlock_tier(tier: int) -> void:
	if tier <= _data.unlocked_tiers:
		Logger.debug("Tier %d already unlocked" % tier, "progression")
		return

	if tier > _data.unlocked_tiers + 1:
		Logger.warn("Cannot unlock Tier %d - must unlock tiers sequentially (current: %d)" % [tier, _data.unlocked_tiers], "progression")
		return

	_data.unlocked_tiers = tier
	Logger.info("Tier %d unlocked!" % tier, "progression")
	EventBus.tier_unlocked.emit(tier)
	save()


## Checks if a tier is unlocked
func is_tier_unlocked(tier: int) -> bool:
	return tier <= _data.unlocked_tiers


## Gets the highest unlocked tier
func get_unlocked_tiers() -> int:
	return _data.unlocked_tiers


## Updates deepest stage reached for a tier (called during/after run)
func update_deepest_stage(tier: int, stage: int) -> void:
	var current_best: int = _data.tier_deepest_stage.get(tier, 0)

	if stage > current_best:
		_data.tier_deepest_stage[tier] = stage
		Logger.info("New record: Tier %d - Deepest Stage %d" % [tier, stage], "progression")
		EventBus.deepest_stage_updated.emit(tier, stage)
		save()


## Gets deepest stage reached for a tier
func get_deepest_stage(tier: int) -> int:
	return _data.tier_deepest_stage.get(tier, 0)


## Increments run counter for a map+tier combination
func increment_run_count(map_id: String, tier: int) -> void:
	# Ensure map exists in dictionary
	if not _data.map_tier_runs.has(map_id):
		_data.map_tier_runs[map_id] = {}

	# Increment tier run count
	var current_count: int = _data.map_tier_runs[map_id].get(tier, 0)
	_data.map_tier_runs[map_id][tier] = current_count + 1

	Logger.debug("Run count for %s Tier %d: %d" % [map_id, tier, current_count + 1], "progression")
	save()


## Gets run count for a specific map+tier
func get_run_count(map_id: String, tier: int) -> int:
	if not _data.map_tier_runs.has(map_id):
		return 0
	return _data.map_tier_runs[map_id].get(tier, 0)


## Gets total run count across all tiers for a map
func get_total_run_count(map_id: String) -> int:
	if not _data.map_tier_runs.has(map_id):
		return 0

	var total := 0
	for tier in _data.map_tier_runs[map_id].keys():
		total += _data.map_tier_runs[map_id][tier]
	return total


# ═══════════════════════════════════════════════════════════════════
# DEBUG & UTILITY
# ═══════════════════════════════════════════════════════════════════

## Gets full progression state for debugging
func get_state() -> Dictionary:
	if not _is_initialized:
		return {}
	return _data.to_dict()