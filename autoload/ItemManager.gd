extends Node

## ItemManager - Global item registry and runtime proc handler
##
## Architecture Pattern (2025-10-13):
##   - Dual registries: BaseItem (gameplay) + ItemMetadata (catalog)
##   - Filename convention: {item_id}_gameplay.tres + {item_id}_metadata.tres
##   - TomeManager pattern: Hot-reload support, directory scanning
##
## Responsibilities:
##   - Load all item definitions from data/content/items/
##   - Provide item gameplay data (BaseItem) and catalog data (ItemMetadata)
##   - Track equipped items and apply stat bonuses to Player.runtime_stats
##   - Handle item procs on damage_dealt events (lightning, explosion, freeze)
##   - Update item cooldowns on combat_step
##
## Usage:
##   var gameplay = ItemManager.get_base_item("thunder_mitts")
##   var catalog = ItemManager.get_item_metadata("thunder_mitts")
##   ItemManager.equip_item("thunder_mitts")

# ============================================================================
# REGISTRIES (Following TomeManager Pattern)
# ============================================================================

## Map of item_id → BaseItem (gameplay data: procs, stats, cooldowns)
var _item_registry: Dictionary = {}  # {item_id: BaseItem}

## Map of item_id → ItemMetadata (catalog data: display_name, icon, unlock)
var _metadata_registry: Dictionary = {}  # {item_id: ItemMetadata}

## Map of item_id → file path for hot-reload support
var _item_file_paths: Dictionary = {}  # {item_id: "res://..."}

## Map of item_id → category string (for UI organization)
var _item_categories: Dictionary = {}  # {item_id: "stat_boost" | "proc" | "utility"}


# ============================================================================
# EQUIPPED ITEMS TRACKING
# ============================================================================

## Currently equipped items (item_id → BaseItem reference)
var _equipped_items: Dictionary = {}  # {item_id: BaseItem}

## Player reference for stat bonus application
var _player: Node2D = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_all_items()
	_connect_to_event_bus()


## Loads all item definitions from the items content directory.
## Populates both _item_registry and _metadata_registry with dual-resource pattern.
func _load_all_items() -> void:
	Logger.info("ItemManager: Loading items...", "items")

	# Load items from main items directory
	_load_items_from_directory("res://data/content/items/")

	Logger.info("ItemManager: Loaded %d items (%d gameplay, %d metadata)" % [
		_item_registry.size(),
		_item_registry.size(),
		_metadata_registry.size()
	], "items")


## Scans a directory for .tres files and loads them as BaseItem + ItemMetadata resources.
## Recognizes filename suffix patterns: {item_id}_gameplay.tres and {item_id}_metadata.tres
func _load_items_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		Logger.warn("Failed to open item directory: " + dir_path, "items")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path := dir_path + file_name

			# Detect file type by suffix
			if file_name.ends_with("_gameplay.tres"):
				_load_base_item_from_file(file_path)
			elif file_name.ends_with("_metadata.tres"):
				_load_item_metadata_from_file(file_path)
			else:
				Logger.warn("Skipping item file with unknown suffix: " + file_name, "items")

		file_name = dir.get_next()

	dir.list_dir_end()


## Loads a single BaseItem resource from file and registers it in _item_registry.
func _load_base_item_from_file(file_path: String) -> void:
	# Use CACHE_MODE_IGNORE for hot-reload support
	var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not item:
		Logger.warn("Failed to load BaseItem: " + file_path, "items")
		return

	# Validate item has required properties
	if not "item_id" in item or item.item_id.is_empty():
		Logger.warn("BaseItem missing item_id: " + file_path, "items")
		return

	# Register item
	var item_id: String = item.item_id
	_item_registry[item_id] = item
	_item_file_paths[item_id] = file_path

	# Categorize item (simple heuristic based on procs)
	var category := _categorize_item(item)
	_item_categories[item_id] = category

	Logger.debug("Loaded BaseItem: %s (%s)" % [item_id, category], "items")


## Loads a single ItemMetadata resource from file and registers it in _metadata_registry.
func _load_item_metadata_from_file(file_path: String) -> void:
	# Use CACHE_MODE_IGNORE for hot-reload support
	var metadata = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not metadata:
		Logger.warn("Failed to load ItemMetadata: " + file_path, "items")
		return

	# Validate metadata has required properties
	if not "item_id" in metadata or metadata.item_id.is_empty():
		Logger.warn("ItemMetadata missing item_id: " + file_path, "items")
		return

	# Register metadata
	var item_id: String = metadata.item_id
	_metadata_registry[item_id] = metadata

	Logger.debug("Loaded ItemMetadata: %s" % item_id, "items")


## Categorizes an item based on its properties.
## Returns "proc", "stat_boost", or "utility".
func _categorize_item(item) -> String:
	# Check for proc types
	if "on_hit_lightning" in item and item.on_hit_lightning:
		return "proc"
	if "on_hit_explosion" in item and item.on_hit_explosion:
		return "proc"
	if "on_hit_freeze" in item and item.on_hit_freeze:
		return "proc"

	# Check for stat bonuses
	if "max_hp_bonus" in item and item.max_hp_bonus != 0:
		return "stat_boost"
	if "movement_speed_mult" in item and item.movement_speed_mult != 1.0:
		return "stat_boost"
	if "damage_mult" in item and item.damage_mult != 1.0:
		return "stat_boost"

	# Default to utility
	return "utility"


# ============================================================================
# ITEM ACCESS (Public API)
# ============================================================================

## Returns the BaseItem gameplay data (procs, stats, cooldowns).
## Returns null if item_id not found.
func get_base_item(item_id: String) -> BaseItem:
	return _item_registry.get(item_id) as BaseItem


## Returns the ItemMetadata catalog data (display_name, icon, unlock_cost).
## Returns null if item_id not found.
func get_item_metadata(item_id: String):
	return _metadata_registry.get(item_id)


## Returns the file path for an item (for debugging/hot-reload).
## Returns empty string if item_id not found.
func get_file_path(item_id: String) -> String:
	return _item_file_paths.get(item_id, "")


## Returns the category for an item.
## Returns empty string if item_id not found.
func get_category(item_id: String) -> String:
	return _item_categories.get(item_id, "")


## Returns all item IDs in the registry.
func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _item_registry.keys():
		ids.append(id)
	return ids


## Returns all items in a specific category.
func get_items_by_category(category: String) -> Array:
	var items: Array = []
	for item_id in _item_categories:
		if _item_categories[item_id] == category:
			var item := _item_registry.get(item_id) as BaseItem
			if item:
				items.append(item)
	return items


# ============================================================================
# EQUIPPED ITEMS MANAGEMENT
# ============================================================================

## Equips an item by item_id. Applies stat bonuses to player and resets cooldowns.
## Returns true if successful, false if item not found or player not set.
func equip_item(item_id: String) -> bool:
	var item: BaseItem = get_base_item(item_id)
	if not item:
		Logger.warn("ItemManager: Cannot equip unknown item: " + item_id, "items")
		return false

	if not _player:
		Logger.warn("ItemManager: Cannot equip item, no player set", "items")
		return false

	# Reset cooldowns on equip
	item.reset_cooldowns()

	# Add to equipped items
	_equipped_items[item_id] = item

	# Apply stat bonuses to player
	_apply_stat_bonuses(item)

	Logger.info("ItemManager: Equipped item '%s'" % item_id, "items")
	return true


## Unequips an item by item_id. Removes stat bonuses from player.
## Returns true if successful, false if item not equipped.
func unequip_item(item_id: String) -> bool:
	if not _equipped_items.has(item_id):
		Logger.warn("ItemManager: Cannot unequip item not equipped: " + item_id, "items")
		return false

	var item: BaseItem = _equipped_items[item_id] as BaseItem
	_equipped_items.erase(item_id)

	# Remove stat bonuses from player
	_remove_stat_bonuses(item)

	Logger.info("ItemManager: Unequipped item '%s'" % item_id, "items")
	return true


## Returns all currently equipped items.
func get_equipped_items() -> Array[BaseItem]:
	var items: Array[BaseItem] = []
	for item in _equipped_items.values():
		items.append(item)
	return items


## Sets the player reference for stat bonus application.
## Should be called when player is spawned in arena.
func set_player(player: Node2D) -> void:
	_player = player
	Logger.debug("ItemManager: Player reference set", "items")


# ============================================================================
# STAT BONUS APPLICATION
# ============================================================================

## Applies item stat bonuses to player.runtime_stats
func _apply_stat_bonuses(item: BaseItem) -> void:
	if not _player or not "runtime_stats" in _player:
		Logger.warn("ItemManager: Cannot apply stat bonuses, player has no runtime_stats", "items")
		return

	var stats = _player.runtime_stats

	# Apply multiplicative modifiers
	if item.movement_speed_mult != 1.0:
		stats.movement_speed_mult *= item.movement_speed_mult
		Logger.debug("Item '%s': Applied movement_speed_mult=%.2f" % [item.item_id, item.movement_speed_mult], "items")

	if item.damage_mult != 1.0:
		stats.damage_mult *= item.damage_mult
		Logger.debug("Item '%s': Applied damage_mult=%.2f" % [item.item_id, item.damage_mult], "items")

	if item.pickup_radius_mult != 1.0:
		stats.pickup_radius_mult *= item.pickup_radius_mult
		Logger.debug("Item '%s': Applied pickup_radius_mult=%.2f" % [item.item_id, item.pickup_radius_mult], "items")

	# Apply additive bonuses
	if item.max_hp_bonus != 0:
		stats.max_hp_bonus += item.max_hp_bonus
		Logger.debug("Item '%s': Applied max_hp_bonus=%d" % [item.item_id, item.max_hp_bonus], "items")


## Removes item stat bonuses from player.runtime_stats
func _remove_stat_bonuses(item: BaseItem) -> void:
	if not _player or not "runtime_stats" in _player:
		return

	var stats = _player.runtime_stats

	# Remove multiplicative modifiers (divide by original multiplier)
	if item.movement_speed_mult != 1.0:
		stats.movement_speed_mult /= item.movement_speed_mult

	if item.damage_mult != 1.0:
		stats.damage_mult /= item.damage_mult

	if item.pickup_radius_mult != 1.0:
		stats.pickup_radius_mult /= item.pickup_radius_mult

	# Remove additive bonuses (subtract original bonus)
	if item.max_hp_bonus != 0:
		stats.max_hp_bonus -= item.max_hp_bonus


# ============================================================================
# EVENT BUS INTEGRATION
# ============================================================================

## Connects to EventBus signals for item proc handling and cooldown updates.
func _connect_to_event_bus() -> void:
	# Connect to damage_dealt for item procs (lightning, explosion, freeze)
	EventBus.damage_dealt.connect(_on_damage_dealt)

	# Connect to combat_step for cooldown updates (30Hz fixed step)
	EventBus.combat_step.connect(_on_combat_step)

	Logger.debug("ItemManager: Connected to EventBus (damage_dealt, combat_step)", "items")


## Handles damage_dealt events for item proc checks.
## Checks all equipped items for proc triggers (lightning, explosion, freeze).
func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type) -> void:
	# Recursion prevention: Don't proc on item-generated damage
	if payload.source.begins_with("item_"):
		return

	# Check each equipped item for proc triggers
	for item_obj in _equipped_items.values():
		var item: BaseItem = item_obj as BaseItem
		if item:
			_check_item_procs(item, payload)


## Handles combat_step events for item cooldown updates (30Hz).
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	var delta_time: float = payload.dt

	# Update cooldowns for all equipped items
	for item_obj in _equipped_items.values():
		var item: BaseItem = item_obj as BaseItem
		if item:
			item.update_cooldowns(delta_time)


# ============================================================================
# ITEM PROC LOGIC
# ============================================================================

## Checks an item for proc triggers based on damage dealt.
## Handles lightning (cooldown-based), explosion (chance-based), freeze (chance-based).
func _check_item_procs(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Get deterministic RNG stream for item procs
	var item_rng := RNG.stream("item_procs")

	# Lightning proc (cooldown-based)
	if item.on_hit_lightning and item._lightning_cooldown <= 0.0:
		_trigger_lightning_proc(item, payload)

	# Explosion proc (chance-based)
	if item.on_hit_explosion:
		var roll := item_rng.randf()
		if roll < item.explosion_chance:
			_trigger_explosion_proc(item, payload)

	# Freeze proc (chance-based)
	if item.on_hit_freeze:
		var roll := item_rng.randf()
		if roll < item.freeze_chance:
			_trigger_freeze_proc(item, payload)


## Triggers lightning proc effect at enemy position.
func _trigger_lightning_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Start cooldown
	item._lightning_cooldown = item.lightning_cooldown

	# Calculate lightning damage
	var lightning_damage := payload.damage * item.lightning_damage_mult

	# Spawn lightning effect at impact position
	EffectSpawner.spawn_lightning(
		payload.impact_position,
		lightning_damage,
		item.lightning_chain_count,
		item.lightning_chain_range
	)

	Logger.debug("Item '%s': Lightning proc (damage=%.1f, cd=%.1f)" % [
		item.item_id, lightning_damage, item.lightning_cooldown
	], "items")


## Triggers explosion proc effect at enemy position.
func _trigger_explosion_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Increment proc counter
	item._explosion_procs += 1

	# Calculate explosion damage
	var explosion_damage := payload.damage * item.explosion_damage_mult

	# Spawn explosion effect at impact position
	EffectSpawner.spawn_explosion(
		payload.impact_position,
		explosion_damage,
		item.explosion_radius
	)

	Logger.debug("Item '%s': Explosion proc (damage=%.1f, radius=%.0f)" % [
		item.item_id, explosion_damage, item.explosion_radius
	], "items")


## Triggers freeze proc effect on enemy.
func _trigger_freeze_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Increment proc counter
	item._freeze_procs += 1

	# Apply freeze effect to target
	EffectSpawner.spawn_freeze(
		payload.target,
		item.freeze_duration,
		item.freeze_slow_mult
	)

	Logger.debug("Item '%s': Freeze proc (target=%s, duration=%.1f)" % [
		item.item_id, payload.target, item.freeze_duration
	], "items")
