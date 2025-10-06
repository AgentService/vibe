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
		Logger.debug("AbilityController connected to combat_step", "abilities")
	else:
		Logger.warn("AbilityController: EventBus not available for combat_step connection", "abilities")


## Cleanup when controller is freed
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect from EventBus to prevent memory leaks
		if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
			EventBus.combat_step.disconnect(_on_combat_step)
			Logger.debug("AbilityController disconnected from combat_step", "abilities")


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

	# Create activation context for ability
	var context := _create_activation_context()

	# Activate the ability (ability handles signal emission)
	ability.activate(_player, context)

	# Start cooldown using final_cooldown (includes tome modifiers)
	ability_cooldowns[slot_index] = ability.final_cooldown

	Logger.debug("Activated ability: %s (cooldown: %.2fs)" % [ability.ability_name, ability.final_cooldown], "abilities")


## Creates the activation context dictionary for abilities.
## Context includes player reference, enemy list, and facing direction.
func _create_activation_context() -> Dictionary:
	return {
		"player": _player,
		"enemies": _get_nearby_enemies(),
		"direction": _get_player_facing_direction()
	}


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
			tome.apply_to_ability(ability, stack_count)
			Logger.debug("Applied tome %s to ability %s" % [tome.tome_id, ability.ability_id], "abilities")


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

## Gets nearby enemies for ability targeting (stub for Phase 1.3).
## Returns empty array until enemy tracking is implemented.
func _get_nearby_enemies() -> Array:
	# TODO (Phase 1.3): Query EntityTracker or enemy group
	# var enemies = get_tree().get_nodes_in_group("enemies")
	# return enemies.filter(func(e): return e.global_position.distance_to(_player.global_position) < 500)
	return []


## Gets the player's current facing direction.
## Returns normalized Vector2 based on mouse position.
func _get_player_facing_direction() -> Vector2:
	# Use mouse position for aiming
	var mouse_pos := _player.get_global_mouse_position()
	return (mouse_pos - _player.global_position).normalized()
