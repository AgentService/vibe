extends Node

## ItemManager - Global item registry and runtime proc handler
##
## Architecture Pattern (2025-10-14):
##   - Single-resource pattern (following BaseTome architecture)
##   - BaseItem = Gameplay (procs, stats, cooldowns) + Shop metadata (UI, unlock)
##   - File naming: {item_id}.tres (no _gameplay/_metadata suffixes)
##   - TomeManager pattern: Hot-reload support, directory scanning
##
## Responsibilities:
##   - Load all item definitions from data/content/items/
##   - Provide unified item data (gameplay + shop metadata in BaseItem)
##   - Track equipped items and apply stat bonuses to Player.runtime_stats
##   - Handle item procs on damage_dealt events (lightning, explosion, freeze, poison)
##   - Update item cooldowns on combat_step
##
## Usage:
##   var item = ItemManager.get_item("thunder_mitts")
##   ItemManager.equip_item("thunder_mitts")

# ============================================================================
# REGISTRY (Single Source of Truth)
# ============================================================================

## Map of item_id → BaseItem (unified: gameplay + shop metadata)
var _item_registry: Dictionary = {}  # {item_id: BaseItem}

## Map of item_id → file path for hot-reload support
var _item_file_paths: Dictionary = {}  # {item_id: "res://..."}

## Map of item_id → category string (for UI organization)
var _item_categories: Dictionary = {}  # {item_id: "stat_boost" | "proc" | "utility"}


# ============================================================================
# EQUIPPED ITEMS TRACKING
# ============================================================================

## Currently equipped items with stack counts
## Structure: {item_id: {item: BaseItem, stack_count: int}}
var _equipped_items: Dictionary = {}  # {item_id: {item: BaseItem, stack_count: int}}

## Player reference for stat bonus application
var _player: Node2D = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_all_items()
	_connect_to_event_bus()


## Loads all item definitions from the items content directory.
## Populates _item_registry with unified BaseItem resources.
func _load_all_items() -> void:
	Logger.info("ItemManager: Loading items...", "items")

	# Load items from main items directory
	_load_items_from_directory("res://data/content/items/")

	Logger.info("ItemManager: Loaded %d items" % _item_registry.size(), "items")


## Scans a directory for .tres files and loads them as unified BaseItem resources.
## Clean single-resource pattern (no suffix checking, no dual loading).
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
			var item = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)

			# Only load BaseItem resources (skip any other .tres files)
			if item is BaseItem:
				_register_item(item, file_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Registers a BaseItem in the registry (single source of truth).
func _register_item(item: BaseItem, file_path: String) -> void:
	# Validate item has required properties
	if item.item_id.is_empty():
		Logger.warn("BaseItem missing item_id: " + file_path, "items")
		return

	# Register item
	var item_id: String = item.item_id
	_item_registry[item_id] = item
	_item_file_paths[item_id] = file_path

	# Categorize item (simple heuristic based on procs)
	var category := _categorize_item(item)
	_item_categories[item_id] = category

	Logger.debug("Loaded item: %s (%s)" % [item_id, category], "items")


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
	if "on_hit_poison" in item and item.on_hit_poison:
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

## Returns the unified BaseItem (gameplay + shop metadata).
## Returns null if item_id not found.
func get_item(item_id: String) -> BaseItem:
	return _item_registry.get(item_id) as BaseItem


## Compatibility alias for existing code (returns same as get_item).
## Returns null if item_id not found.
func get_base_item(item_id: String) -> BaseItem:
	return get_item(item_id)


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

## Equips an item by item_id. Stacks if already equipped, applies stat bonuses.
## Returns true if successful, false if item not found or player not set.
func equip_item(item_id: String) -> bool:
	var item: BaseItem = get_base_item(item_id)
	if not item:
		Logger.warn("ItemManager: Cannot equip unknown item: " + item_id, "items")
		return false

	if not _player:
		Logger.warn("ItemManager: Cannot equip item, no player set", "items")
		return false

	# Check if item already equipped (stacking)
	if _equipped_items.has(item_id):
		var item_data: Dictionary = _equipped_items[item_id]
		var old_stack_count: int = item_data.stack_count

		# Remove old stack bonuses (total from all previous stacks)
		_remove_stat_bonuses(item, old_stack_count)

		# Increment stack count
		item_data.stack_count += 1

		# Apply new stack bonuses (total from all stacks including new one)
		_apply_stat_bonuses(item, item_data.stack_count)

		Logger.info("ItemManager: Stacked item '%s' (stack: %d)" % [item_id, item_data.stack_count], "items")
		return true

	# First time equipping - create new entry
	_equipped_items[item_id] = {
		"item": item,
		"stack_count": 1
	}

	# Reset cooldowns on first equip
	item.reset_cooldowns()

	# Apply stat bonuses to player
	_apply_stat_bonuses(item, 1)

	Logger.info("ItemManager: Equipped item '%s' (stack: 1)" % item_id, "items")
	return true


## Unequips one stack of an item. Removes stat bonuses for one stack.
## Returns true if successful, false if item not equipped.
func unequip_item(item_id: String) -> bool:
	if not _equipped_items.has(item_id):
		Logger.warn("ItemManager: Cannot unequip item not equipped: " + item_id, "items")
		return false

	var item_data: Dictionary = _equipped_items[item_id]
	var item: BaseItem = item_data.item
	var old_stack_count: int = item_data.stack_count

	# Remove old stack bonuses (total from all current stacks)
	_remove_stat_bonuses(item, old_stack_count)

	# Decrement stack count
	item_data.stack_count -= 1

	# Reapply bonuses if stacks remain
	if item_data.stack_count > 0:
		_apply_stat_bonuses(item, item_data.stack_count)
		Logger.info("ItemManager: Unequipped item '%s' (stack: %d remaining)" % [item_id, item_data.stack_count], "items")
	else:
		# Remove from dictionary if no stacks remain
		_equipped_items.erase(item_id)
		Logger.info("ItemManager: Unequipped item '%s' (removed completely)" % item_id, "items")

	return true


## Returns all currently equipped items with stack info.
## Returns Array of Dictionaries: [{item: BaseItem, item_id: String, stack_count: int}, ...]
func get_equipped_items() -> Array:
	var items: Array = []
	for item_id in _equipped_items.keys():
		var item_data: Dictionary = _equipped_items[item_id]
		items.append({
			"item": item_data.item,
			"item_id": item_id,
			"stack_count": item_data.stack_count
		})
	return items


## Sets the player reference for stat bonus application.
## Should be called when player is spawned in arena.
func set_player(player: Node2D) -> void:
	_player = player
	Logger.debug("ItemManager: Player reference set", "items")


# ============================================================================
# STAT BONUS APPLICATION
# ============================================================================

## Applies item stat bonuses to player.runtime_stats (using ScalingCalculator)
func _apply_stat_bonuses(item: BaseItem, stack_count: int = 1) -> void:
	if not _player or not "runtime_stats" in _player:
		Logger.warn("ItemManager: Cannot apply stat bonuses, player has no runtime_stats", "items")
		return

	var stats = _player.runtime_stats

	# Damage multiplier (uses ScalingCalculator)
	if item.damage_mult != 1.0:
		# Auto-derive per_stack if not explicitly set
		var per_stack := item.damage_per_stack if item.damage_per_stack != 0.0 else (item.damage_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.damage_scaling_type,
			item.damage_hyperbolic_cap,
			item.damage_hyperbolic_k
		)
		stats.damage_mult *= stack_mult
		Logger.debug("Item '%s': Applied damage_mult=%.2f (x%d stacks, %s)" % [
			item.item_id, stack_mult, stack_count, ScalingCalculator.ScalingType.keys()[item.damage_scaling_type]
		], "items")

	# Movement speed multiplier (uses ScalingCalculator)
	if item.movement_speed_mult != 1.0:
		var per_stack := item.speed_per_stack if item.speed_per_stack != 0.0 else (item.movement_speed_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.speed_scaling_type,
			item.speed_hyperbolic_cap,
			item.speed_hyperbolic_k
		)
		stats.movement_speed_mult *= stack_mult
		Logger.debug("Item '%s': Applied movement_speed_mult=%.2f (x%d stacks, %s)" % [
			item.item_id, stack_mult, stack_count, ScalingCalculator.ScalingType.keys()[item.speed_scaling_type]
		], "items")

	# Pickup radius multiplier (uses ScalingCalculator)
	if item.pickup_radius_mult != 1.0:
		var per_stack := item.pickup_radius_per_stack if item.pickup_radius_per_stack != 0.0 else (item.pickup_radius_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.pickup_radius_scaling_type,
			0.0,  # No hyperbolic cap for pickup radius (use default EXPONENTIAL)
			1.0
		)
		stats.pickup_radius_mult *= stack_mult
		Logger.debug("Item '%s': Applied pickup_radius_mult=%.2f (x%d stacks, %s)" % [
			item.item_id, stack_mult, stack_count, ScalingCalculator.ScalingType.keys()[item.pickup_radius_scaling_type]
		], "items")

	# HP bonus (uses ScalingCalculator for flat scaling)
	if item.max_hp_bonus != 0:
		# Auto-derive per_stack if not explicitly set
		var per_stack := float(item.hp_per_stack) if item.hp_per_stack != 0 else float(item.max_hp_bonus)

		var bonus := int(ScalingCalculator.calculate_flat(
			per_stack,
			stack_count,
			item.hp_scaling_type,
			item.hp_hyperbolic_cap,
			item.hp_hyperbolic_k
		))
		stats.max_hp_bonus += bonus
		Logger.debug("Item '%s': Applied max_hp_bonus=%d (x%d stacks, %s)" % [
			item.item_id, bonus, stack_count, ScalingCalculator.ScalingType.keys()[item.hp_scaling_type]
		], "items")

	# Crit chance bonus (uses ScalingCalculator for flat scaling)
	if item.crit_chance_bonus != 0.0:
		var per_stack := item.crit_per_stack if item.crit_per_stack != 0.0 else item.crit_chance_bonus

		var bonus := ScalingCalculator.calculate_flat(
			per_stack,
			stack_count,
			item.crit_scaling_type,
			0.0,  # No hyperbolic cap for crit (typically capped at 1.0 by game logic)
			1.0
		)
		stats.crit_chance_bonus += bonus
		Logger.debug("Item '%s': Applied crit_chance_bonus=%.3f (x%d stacks, %s)" % [
			item.item_id, bonus, stack_count, ScalingCalculator.ScalingType.keys()[item.crit_scaling_type]
		], "items")


## Removes item stat bonuses from player.runtime_stats (using ScalingCalculator)
func _remove_stat_bonuses(item: BaseItem, stack_count: int = 1) -> void:
	if not _player or not "runtime_stats" in _player:
		return

	var stats = _player.runtime_stats

	# Damage multiplier (divide by calculated stack_mult)
	if item.damage_mult != 1.0:
		var per_stack := item.damage_per_stack if item.damage_per_stack != 0.0 else (item.damage_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.damage_scaling_type,
			item.damage_hyperbolic_cap,
			item.damage_hyperbolic_k
		)
		stats.damage_mult /= stack_mult
		Logger.debug("Item '%s': Removed damage_mult=%.2f (x%d stacks, new value: %.2f)" % [
			item.item_id, stack_mult, stack_count, stats.damage_mult
		], "items")

	# Movement speed multiplier (divide by calculated stack_mult)
	if item.movement_speed_mult != 1.0:
		var per_stack := item.speed_per_stack if item.speed_per_stack != 0.0 else (item.movement_speed_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.speed_scaling_type,
			item.speed_hyperbolic_cap,
			item.speed_hyperbolic_k
		)
		stats.movement_speed_mult /= stack_mult
		Logger.debug("Item '%s': Removed movement_speed_mult=%.2f (x%d stacks, new value: %.2f)" % [
			item.item_id, stack_mult, stack_count, stats.movement_speed_mult
		], "items")

	# Pickup radius multiplier (divide by calculated stack_mult)
	if item.pickup_radius_mult != 1.0:
		var per_stack := item.pickup_radius_per_stack if item.pickup_radius_per_stack != 0.0 else (item.pickup_radius_mult - 1.0)

		var stack_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.pickup_radius_scaling_type,
			0.0,
			1.0
		)
		stats.pickup_radius_mult /= stack_mult
		Logger.debug("Item '%s': Removed pickup_radius_mult=%.2f (x%d stacks, new value: %.2f)" % [
			item.item_id, stack_mult, stack_count, stats.pickup_radius_mult
		], "items")

	# HP bonus (subtract calculated flat value)
	if item.max_hp_bonus != 0:
		var per_stack := float(item.hp_per_stack) if item.hp_per_stack != 0 else float(item.max_hp_bonus)

		var bonus := int(ScalingCalculator.calculate_flat(
			per_stack,
			stack_count,
			item.hp_scaling_type,
			item.hp_hyperbolic_cap,
			item.hp_hyperbolic_k
		))
		stats.max_hp_bonus -= bonus
		Logger.debug("Item '%s': Removed max_hp_bonus=%d (x%d stacks, new value: %d)" % [
			item.item_id, bonus, stack_count, stats.max_hp_bonus
		], "items")

	# Crit chance bonus (subtract calculated flat value)
	if item.crit_chance_bonus != 0.0:
		var per_stack := item.crit_per_stack if item.crit_per_stack != 0.0 else item.crit_chance_bonus

		var bonus := ScalingCalculator.calculate_flat(
			per_stack,
			stack_count,
			item.crit_scaling_type,
			0.0,
			1.0
		)
		stats.crit_chance_bonus -= bonus
		Logger.debug("Item '%s': Removed crit_chance_bonus=%.3f (x%d stacks, new value: %.3f)" % [
			item.item_id, bonus, stack_count, stats.crit_chance_bonus
		], "items")


# ============================================================================
# EVENT BUS INTEGRATION
# ============================================================================

## Connects to EventBus signals for item proc handling and cooldown updates.
func _connect_to_event_bus() -> void:
	# Connect to damage_dealt for item procs (lightning, explosion, freeze)
	EventBus.damage_dealt.connect(_on_damage_dealt)

	# Connect to combat_step for cooldown updates (30Hz fixed step)
	EventBus.combat_step.connect(_on_combat_step)

	# Connect to item_acquired for chest/reward integration
	EventBus.item_acquired.connect(_on_item_acquired)

	Logger.debug("ItemManager: Connected to EventBus (damage_dealt, combat_step, item_acquired)", "items")


## Handles damage_dealt events for item proc checks and conditional damage bonuses.
## Checks all equipped items for proc triggers (lightning, explosion, freeze) and conditional effects.
func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type) -> void:
	# Recursion prevention: Don't proc on item-generated damage
	if payload.source.begins_with("item_"):
		return

	# Check each equipped item for conditional damage bonuses FIRST
	_check_conditional_damage(payload)

	# Then check each equipped item for proc triggers
	for item_data in _equipped_items.values():
		var item: BaseItem = item_data.item
		if item:
			_check_item_procs(item, payload)


## Handles combat_step events for item cooldown updates (30Hz).
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	var delta_time: float = payload.dt

	# Update cooldowns for all equipped items
	for item_data in _equipped_items.values():
		var item: BaseItem = item_data.item
		if item:
			item.update_cooldowns(delta_time)


# ============================================================================
# CONDITIONAL DAMAGE LOGIC (2025-10-16)
# ============================================================================

## Checks equipped items for conditional damage bonuses and applies additional damage if conditions met.
## Example: Focus Stone gives +20% damage to enemies within 13m.
func _check_conditional_damage(payload: EventBus.DamageDealtPayload_Type) -> void:
	# Skip if no position data available
	if payload.source_position == Vector2.ZERO or payload.impact_position == Vector2.ZERO:
		return

	# Calculate distance between source and impact
	var distance := payload.source_position.distance_to(payload.impact_position)

	# Check each equipped item for conditional damage
	for item_data in _equipped_items.values():
		var item: BaseItem = item_data.item
		if not item or not item.conditional_damage_enabled:
			continue

		var stack_count: int = item_data.get("stack_count", 1)

		# Check if within range
		if distance > item.conditional_damage_range:
			continue

		# Calculate conditional damage bonus with scaling
		var per_stack := item.conditional_damage_per_stack if item.conditional_damage_per_stack != 0.0 else item.conditional_damage_bonus

		var bonus_mult := ScalingCalculator.calculate_multiplier(
			per_stack,
			stack_count,
			item.conditional_damage_scaling_type,
			0.0,  # No hyperbolic cap for conditional damage
			1.0
		)

		# Calculate additional damage (bonus is multiplicative: 1.2x = +20% damage)
		var bonus_damage := payload.damage * (bonus_mult - 1.0)

		# Apply bonus damage via DamageService
		if bonus_damage > 0.0:
			DamageService._process_damage_immediate(
				payload.target,
				bonus_damage,
				"item_conditional_%s" % item.item_id,  # Source tag for tracking
				["conditional"],
				0.0,  # No knockback
				payload.source_position
			)

			Logger.debug("Item '%s': Conditional damage bonus %.1f (distance: %.0f/%.0f, mult: %.2fx, stacks: %d)" % [
				item.item_id, bonus_damage, distance, item.conditional_damage_range, bonus_mult, stack_count
			], "items")


# ============================================================================
# ITEM PROC LOGIC
# ============================================================================

## Checks all equipped items for proc triggers based on damage dealt.
## Handles lightning (per-item cooldown), explosion (stacked chance), freeze (stacked chance).
func _check_item_procs(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Get deterministic RNG stream for item procs
	var item_rng := RNG.stream("item_procs")

	# Lightning proc (cooldown-based, per-item)
	if item.on_hit_lightning and item._lightning_cooldown <= 0.0:
		_trigger_lightning_proc(item, payload)

	# Explosion proc (chance-based, per-item with stacks)
	if item.on_hit_explosion:
		var item_data: Dictionary = _equipped_items.get(item.item_id, {})
		var stack_count: int = item_data.get("stack_count", 1)

		# Multiplicative stacking: effective_chance = 1 - (1 - base_chance)^stack_count
		var effective_explosion_chance := 1.0 - pow(1.0 - item.explosion_chance, stack_count)

		var roll := item_rng.randf()
		if roll < effective_explosion_chance:
			_trigger_explosion_proc(item, payload)

	# Freeze proc (chance-based, per-item with stacks)
	if item.on_hit_freeze:
		var item_data: Dictionary = _equipped_items.get(item.item_id, {})
		var stack_count: int = item_data.get("stack_count", 1)

		# Multiplicative stacking: effective_chance = 1 - (1 - base_chance)^stack_count
		var effective_freeze_chance := 1.0 - pow(1.0 - item.freeze_chance, stack_count)

		var roll := item_rng.randf()
		if roll < effective_freeze_chance:
			_trigger_freeze_proc(item, payload)

	# Poison proc (chance-based, per-item with stacks)
	if item.on_hit_poison:
		var item_data: Dictionary = _equipped_items.get(item.item_id, {})
		var stack_count: int = item_data.get("stack_count", 1)

		# Multiplicative stacking: effective_chance = 1 - (1 - base_chance)^stack_count
		# Example: 3 items at 40% = 1 - 0.6^3 = 78.4% chance
		var effective_poison_chance := 1.0 - pow(1.0 - item.poison_chance, stack_count)

		var roll := item_rng.randf()
		if roll < effective_poison_chance:
			_trigger_poison_proc(item, payload)


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

	# Logger.debug("Item '%s': Lightning proc (damage=%.1f, cd=%.1f)" % [
	# 	item.item_id, lightning_damage, item.lightning_cooldown
	# ], "items")  # Removed per-tick spam


## Triggers explosion proc effect at enemy position.
func _trigger_explosion_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Increment proc counter
	item._explosion_procs += 1

	# Get stack info for logging
	var item_data: Dictionary = _equipped_items.get(item.item_id, {})
	var stack_count: int = item_data.get("stack_count", 1)
	var effective_chance := 1.0 - pow(1.0 - item.explosion_chance, stack_count)

	# Calculate explosion damage
	var explosion_damage := payload.damage * item.explosion_damage_mult

	# Spawn explosion effect at impact position (tracks target enemy for on-hit explosions)
	EffectSpawner.spawn_explosion(
		payload.impact_position,
		explosion_damage,
		item.explosion_radius,
		item.explosion_scene,  # Custom scene (VoodooDollExplosion, FrostExplosion, etc.)
		payload.target  # Track enemy for on-hit explosions (explosion follows target)
	)

	# Logger.debug("Item '%s': Explosion proc (damage=%.1f, radius=%.0f, stacks=%d, effective_chance=%.1f%%)" % [
	# 	item.item_id, explosion_damage, item.explosion_radius, stack_count, effective_chance * 100.0
	# ], "items")  # Removed per-tick spam


## Triggers freeze proc effect on enemy.
func _trigger_freeze_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Increment proc counter
	item._freeze_procs += 1

	# Get stack info for logging
	var item_data: Dictionary = _equipped_items.get(item.item_id, {})
	var stack_count: int = item_data.get("stack_count", 1)
	var effective_chance := 1.0 - pow(1.0 - item.freeze_chance, stack_count)

	# Apply freeze effect to target
	EffectSpawner.spawn_freeze(
		payload.target,
		item.freeze_duration,
		item.freeze_slow_mult
	)

	# Logger.debug("Item '%s': Freeze proc (target=%s, duration=%.1f, stacks=%d, effective_chance=%.1f%%)" % [
	# 	item.item_id, payload.target, item.freeze_duration, stack_count, effective_chance * 100.0
	# ], "items")  # Removed per-tick spam


## Triggers poison proc effect on enemy.
func _trigger_poison_proc(item: BaseItem, payload: EventBus.DamageDealtPayload_Type) -> void:
	# Increment proc counter
	item._poison_procs += 1

	# Get stack info for damage calculation
	var item_data: Dictionary = _equipped_items.get(item.item_id, {})
	var stack_count: int = item_data.get("stack_count", 1)
	var effective_chance := 1.0 - pow(1.0 - item.poison_chance, stack_count)

	# Calculate base poison damage (percentage of triggering hit)
	var base_poison_damage: float = payload.damage * item.poison_damage_per_tick

	# Overflow scaling: Convert excess proc chance into damage multiplier
	# Multiplicative for proc chance (capped at 100%), additive for overflow damage
	var total_chance: float = item.poison_chance * stack_count
	var damage_multiplier: float = 1.0 + max(0.0, total_chance - 1.0)
	var total_poison_damage: float = base_poison_damage * damage_multiplier

	# Calculate damage per tick dynamically (derive tick count from duration / interval)
	var tick_count: float = item.poison_duration / StatusEffect.POISON_TICK_INTERVAL
	var damage_per_tick: float = total_poison_damage / tick_count

	# Create poison status effect with scaled damage
	var poison_effect := StatusEffect.create_poison(
		item.poison_duration,
		damage_per_tick,
		"item_poison"  # Source tag for recursion prevention
	)

	# Apply poison status to target via StatusEffectSystem
	StatusEffectSystem.apply_status(payload.target, poison_effect)

	# Logger.debug("Item '%s': Poison proc (target=%s, duration=%.1f, base_dmg=%.1f, mult=%.2fx, dmg/tick=%.1f, stacks=%d, chance=%.1f%%)" % [
	# 	item.item_id, payload.target, item.poison_duration, base_poison_damage, damage_multiplier, damage_per_tick, stack_count, effective_chance * 100.0
	# ], "items")  # Removed per-tick spam


# ============================================================================
# ITEM ACQUISITION (Public API for Chests/Rewards)
# ============================================================================

## Handles item_acquired events from chests, boss drops, debug spawners, etc.
## Automatically equips items (future: add to inventory system).
func _on_item_acquired(item_id: String, source: String) -> void:
	# Validate item exists
	var item: BaseItem = get_base_item(item_id)
	if not item:
		Logger.warn("ItemManager: Cannot acquire unknown item: %s" % item_id, "items")
		return

	# Future: Add to inventory system, check capacity, show pickup UI
	# For now: Auto-equip directly
	var success := equip_item(item_id)

	if success:
		Logger.info("ItemManager: Acquired item '%s' from %s" % [item_id, source], "items")
		# Future: Emit UI notification, play pickup sound, show item card
	else:
		Logger.warn("ItemManager: Failed to acquire item '%s'" % item_id, "items")
