## AbilityController.gd
## Component for managing player abilities, cooldowns, and auto-casting.
##
## This class handles all ability-related logic, keeping Player.gd focused
## on movement and animation. Follows component-based architecture pattern.
##
## Responsibilities:
## - Manage ability slots and cooldowns
## - Auto-cast abilities when ready
## - Handle ability equip/level-up/tome application
## - Provide context for ability activation (player ref, enemies, direction)
##
## Architecture:
## - Uses EventBus.combat_step (30Hz fixed timestep) for deterministic updates
## - Ensures consistent cooldown timing regardless of framerate
## - Compatible with future networked play / replay systems
##
## Usage:
##   var ability_controller = AbilityController.new(player)
##   ability_controller.equip_ability("ranger_arrow", 0)
##   # Combat step handled automatically via EventBus
extends RefCounted
class_name AbilityController

# ============================================================================
# PROPERTIES
# ============================================================================

## Reference to the owning player
var _player: Node2D

## Optional reference to ghost swarm spawner for ghost targeting
var ghost_swarm_spawner: GhostSwarmSpawner = null

## Ability slots (4 slots, null = empty)
var ability_slots: Array[BaseAbility] = [null, null, null, null]

## Cooldown timers for each slot
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

## Tome slots (4 slots, null = empty)
var tome_slots: Array[BaseTome] = [null, null, null, null]

## Stack counts for each tome slot
var tome_stacks: Array[int] = [0, 0, 0, 0]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(player: Node2D) -> void:
	_player = player

	# Connect to 30Hz fixed-step combat loop
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
		EventBus.ability_acquired.connect(_on_ability_acquired)
		EventBus.tome_acquired.connect(_on_tome_acquired)
		Logger.debug("AbilityController connected to EventBus signals (combat_step, ability_acquired, tome_acquired)", "abilities")
	else:
		Logger.warn("AbilityController: EventBus not available for signal connections", "abilities")


## Cleanup when controller is freed
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect from EventBus to prevent memory leaks
		if EventBus and is_instance_valid(EventBus):
			var combat_step_ref = Callable(self, "_on_combat_step")
			if EventBus.combat_step.is_connected(combat_step_ref):
				EventBus.combat_step.disconnect(combat_step_ref)

			var ability_acquired_ref = Callable(self, "_on_ability_acquired")
			if EventBus.ability_acquired.is_connected(ability_acquired_ref):
				EventBus.ability_acquired.disconnect(ability_acquired_ref)

			var tome_acquired_ref = Callable(self, "_on_tome_acquired")
			if EventBus.tome_acquired.is_connected(tome_acquired_ref):
				EventBus.tome_acquired.disconnect(tome_acquired_ref)

			Logger.debug("AbilityController disconnected from EventBus signals", "abilities")


# ============================================================================
# UPDATE LOOP (30Hz FIXED STEP)
# ============================================================================

## Combat step handler - runs at fixed 30Hz via EventBus.combat_step
## Ensures deterministic ability cooldowns and auto-casting
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	var delta_time: float = payload.dt  # Always 1/30 = 0.0333s

	_update_cooldowns(delta_time)
	_auto_cast_ready_abilities()


## Decrements all active cooldowns by delta time.
func _update_cooldowns(delta: float) -> void:
	for i in range(ability_cooldowns.size()):
		if ability_cooldowns[i] > 0.0:
			ability_cooldowns[i] = maxf(0.0, ability_cooldowns[i] - delta)


## Auto-casts ready abilities (fires when off cooldown).
## For Phase 1, abilities fire automatically.
## Future phases may add manual activation or AI target selection.
func _auto_cast_ready_abilities() -> void:
	for i in range(ability_slots.size()):
		var ability := ability_slots[i]

		# Skip empty slots or abilities on cooldown
		if not ability or ability_cooldowns[i] > 0.0:
			continue

		# Check if there are enemies in range before firing (using ability's range)
		var enemies = _get_nearby_enemies(ability)
		if enemies.is_empty():
			continue  # Don't fire if no enemies

		# Auto-cast ability
		activate_ability(i)


# ============================================================================
# ABILITY ACTIVATION
# ============================================================================

## Activates an ability in a specific slot.
## Calls ability.activate() and starts cooldown timer.
func activate_ability(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ability_slots.size():
		Logger.warn("Invalid ability slot index: %d" % slot_index, "abilities")
		return

	var ability := ability_slots[slot_index]

	if not ability:
		return  # Empty slot, no warning needed

	# Create activation context for ability (includes enemies in ability's range)
	var context := _create_activation_context(ability)

	# Activate the ability (ability handles signal emission)
	ability.activate(_player, context)

	# Start cooldown using final_cooldown (includes tome modifiers)
	ability_cooldowns[slot_index] = ability.final_cooldown


## Creates the activation context dictionary for abilities.
## Context includes player reference and enemy list within ability's range.
## Direction is determined by ability's fire_mode setting.
func _create_activation_context(ability: BaseAbility) -> Dictionary:
	return {
		"player": _player,
		"enemies": _get_nearby_enemies(ability)
		# Don't include "direction" - let ability use its fire_mode (CLOSEST_ENEMY, etc.)
	}


# ============================================================================
# EVENT HANDLERS (EventBus Signal Listeners)
# ============================================================================

## Handles ability_acquired events from UI, debug panels, level-up system.
## Architecture: CONSUMER ONLY - listens to signal, does NOT re-emit.
## The existing equip_ability() method handles all side-effects (cooldown reset, logging, slot assignment).
func _on_ability_acquired(ability_id: String, slot: int) -> void:
	# Validate ability exists in registry
	if not AbilityManager.has_definition(ability_id):
		Logger.warn("Cannot acquire unknown ability: %s" % ability_id, "abilities")
		return

	# Equip via existing method (reuses slot logic and side-effects)
	equip_ability(ability_id, slot)


## Handles tome_acquired events from UI, debug panels, rewards.
## Architecture: CONSUMER ONLY - listens to signal, does NOT re-emit.
## The existing equip_tome() method handles all side-effects (stacking, tome application, logging).
func _on_tome_acquired(tome_id: String, stack_count: int) -> void:
	# Get tome definition from TomeManager
	var tome = TomeManager.get_definition(tome_id)
	if not tome:
		Logger.warn("Cannot acquire unknown tome: %s" % tome_id, "abilities")
		return

	# Equip tome stack_count times (equip_tome adds 1 stack per call)
	for i in range(stack_count):
		equip_tome(tome)


# ============================================================================
# ABILITY MANAGEMENT
# ============================================================================

## Equips an ability to a slot (or finds empty slot if slot == -1).
## Creates instance from AbilityManager and stores in ability_slots array.
func equip_ability(ability_id: String, slot: int = -1) -> void:
	# Create instance from AbilityManager
	var ability_instance := AbilityManager.create_ability_instance(ability_id)

	if not ability_instance:
		Logger.warn("Failed to equip unknown ability: %s" % ability_id, "abilities")
		return

	# Find slot to equip to
	var target_slot := slot
	if target_slot == -1:
		target_slot = _find_empty_ability_slot()

	if target_slot == -1:
		Logger.warn("No empty ability slots available for: %s" % ability_id, "abilities")
		return

	# Equip ability
	ability_slots[target_slot] = ability_instance
	ability_cooldowns[target_slot] = 0.0  # Ready to use immediately

	Logger.info("Equipped ability: %s to slot %d" % [ability_instance.ability_name, target_slot], "abilities")


## Levels up an ability by ID (searches all slots).
## Increases ability level and applies scaling.
func level_up_ability(ability_id: String, levels: int = 1) -> void:
	var slot_index := find_ability_slot(ability_id)

	if slot_index == -1:
		Logger.warn("Cannot level up ability not in slots: %s" % ability_id, "abilities")
		return

	var ability := ability_slots[slot_index]
	ability.level_up(levels)

	Logger.info("Leveled up ability: %s to level %d" % [ability.ability_name, ability.ability_level], "abilities")


## Finds the slot index of an ability by ID.
## Returns -1 if not found.
func find_ability_slot(ability_id: String) -> int:
	for i in range(ability_slots.size()):
		var ability := ability_slots[i]
		if ability and ability.ability_id == ability_id:
			return i
	return -1


## Clears an ability slot, removing the equipped ability.
func clear_ability_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ability_slots.size():
		Logger.warn("Invalid slot index: %d" % slot_index, "abilities")
		return

	var ability := ability_slots[slot_index]
	if ability:
		Logger.info("Cleared ability: %s from slot %d" % [ability.ability_name, slot_index], "abilities")

	ability_slots[slot_index] = null
	ability_cooldowns[slot_index] = 0.0


## Finds the first empty ability slot.
## Returns -1 if all slots are full.
func _find_empty_ability_slot() -> int:
	for i in range(ability_slots.size()):
		if ability_slots[i] == null:
			return i
	return -1


# ============================================================================
# TOME MANAGEMENT
# ============================================================================

## Equips a tome (or increases stack count if already equipped).
## Applies tome modifiers to all applicable abilities.
func equip_tome(tome: BaseTome) -> void:
	if not tome:
		Logger.warn("Attempted to equip null tome", "abilities")
		return

	# Find existing tome slot or empty slot
	var slot_index := find_tome_slot(tome.tome_id)

	if slot_index == -1:
		# Not equipped yet - find empty slot
		slot_index = _find_empty_tome_slot()

	if slot_index == -1:
		Logger.warn("No empty tome slots available for: %s" % tome.tome_name, "abilities")
		return

	# Equip or increase stack
	var stack_count := 1
	if tome_slots[slot_index] == tome:
		stack_count = tome_stacks[slot_index] + 1
	else:
		tome_slots[slot_index] = tome
		stack_count = 1

	tome_stacks[slot_index] = stack_count

	# Apply tome to all applicable abilities
	_apply_tome_to_all_abilities(tome, stack_count)

	# Apply tome to player stats (future phase)
	_apply_tome_to_player(tome, stack_count)

	Logger.info("Equipped tome: %s (×%d stacks)" % [tome.tome_name, stack_count], "abilities")


## Applies a tome to all equipped abilities that match its tags.
func _apply_tome_to_all_abilities(tome: BaseTome, stack_count: int) -> void:
	for ability in ability_slots:
		if ability and tome.can_apply_to_ability(ability):
			# Only log if tome has meaningful ability modifiers (not just player stats)
			var has_ability_mods := _tome_has_ability_modifiers(tome)

			tome.apply_to_ability(ability, stack_count)

			if has_ability_mods:
				Logger.debug("Applied tome %s to ability %s" % [tome.tome_id, ability.ability_id], "abilities")


## Checks if a tome has any meaningful ability modifiers (not just player stats).
## Returns true if any ability modifier differs from identity values.
## Uses to_dict() for maintainability - automatically includes new properties.
func _tome_has_ability_modifiers(tome: BaseTome) -> bool:
	var tome_data := tome.to_dict()
	var ability_mods: Dictionary = tome_data.get("ability_modifiers", {})

	for property_name in ability_mods.keys():
		var value = ability_mods[property_name]

		# Check multipliers (identity = 1.0)
		if property_name.ends_with("_multiplier"):
			if value != 1.0:
				return true

		# Check bonuses (identity = 0)
		elif property_name.ends_with("_bonus"):
			if value != 0:
				return true

	return false


## Applies a tome to player stats (stub for future phases).
func _apply_tome_to_player(tome: BaseTome, stack_count: int) -> void:
	tome.apply_to_player(_player, stack_count)


## Finds the slot index of a tome by ID.
## Returns -1 if not found.
func find_tome_slot(tome_id: String) -> int:
	for i in range(tome_slots.size()):
		var tome := tome_slots[i]
		if tome and tome.tome_id == tome_id:
			return i
	return -1


## Finds the first empty tome slot.
## Returns -1 if all slots are full.
func _find_empty_tome_slot() -> int:
	for i in range(tome_slots.size()):
		if tome_slots[i] == null:
			return i
	return -1


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Gets nearby enemies within the CURRENT ABILITY'S effective range.
## Uses the ability's final_range property for dynamic range detection.
## Falls back to 800px if ability has no range property (utility abilities).
## INCLUDES ghost swarm enemies if active (as position wrappers).
func _get_nearby_enemies(ability: BaseAbility) -> Array:
	if not _player or not is_instance_valid(_player):
		return []

	# Access scene tree through player node (RefCounted doesn't have get_tree())
	var tree := _player.get_tree()
	if not tree:
		return []

	# SPAWN SYSTEM: Use "targetable" group to filter out spawning enemies
	# Enemies transition: spawning (0.5s) → targetable after spawn animation
	var all_enemies = tree.get_nodes_in_group("targetable")
	var nearby_enemies: Array = []

	# Use ability's final_range (supports tome modifiers)
	var detection_range: float = 800.0  # Default fallback
	if ability is DamageAbility:
		detection_range = ability.final_range

	# Add scene-based enemies
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if not enemy_node:
			continue

		var distance := _player.global_position.distance_to(enemy_node.global_position)
		if distance <= detection_range:
			nearby_enemies.append(enemy_node)

	# Add ghost swarm enemies (as position wrappers)
	if ghost_swarm_spawner and ghost_swarm_spawner.is_active():
		var ghost_positions = ghost_swarm_spawner.get_living_ghost_positions()
		for ghost_pos in ghost_positions:
			var distance := _player.global_position.distance_to(ghost_pos)
			if distance <= detection_range:
				# Create lightweight wrapper for ghost position
				var ghost_wrapper = {
					"global_position": ghost_pos,
					"is_ghost": true
				}
				nearby_enemies.append(ghost_wrapper)

	return nearby_enemies


## Gets the player's current facing direction.
## Returns normalized Vector2 based on mouse position.
func _get_player_facing_direction() -> Vector2:
	# Use mouse position for aiming
	var mouse_pos := _player.get_global_mouse_position()
	return (mouse_pos - _player.global_position).normalized()
