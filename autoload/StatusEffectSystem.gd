extends Node

## StatusEffectSystem - Centralized status effect & DoT management
##
## Responsibilities:
##   - Track active status effects per entity (poison, burn, bleed, chill)
##   - Update effects on 30Hz combat step (tick damage, decrement duration)
##   - Apply damage via DamageService._process_damage_immediate
##   - Handle stacking/merging based on StatusEffect.StackBehavior
##   - Clean up expired effects and handle entity death
##   - Emit signals when status effects are applied/removed (for UI updates)
##
## Usage:
##   StatusEffectSystem.apply_status(enemy_id, StatusEffect.create_poison(3.0, 5.0))
##   StatusEffectSystem.has_status(enemy_id, "poison")  # Check for effect
##   StatusEffectSystem.remove_status(enemy_id, "poison")  # Remove effect
##
## Signals:
##   status_applied(entity_id, effect_type) - Emitted when new effect applied
##   status_removed(entity_id, effect_type) - Emitted when effect expires/removed

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a status effect is applied to an entity (first time, not merges)
signal status_applied(entity_id: String, effect_type: String)

## Emitted when a status effect is removed/expires from an entity
signal status_removed(entity_id: String, effect_type: String)

# ============================================================================
# STATE
# ============================================================================

## Active status effects per entity
## Structure: {entity_id: [StatusEffect, StatusEffect, ...]}
var _active_effects: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to combat step for effect updates (30Hz)
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)

	Logger.debug("StatusEffectSystem initialized", "status")


# ============================================================================
# PUBLIC API
# ============================================================================

## Apply a status effect to an entity
## Handles stacking/merging based on effect's StackBehavior
##
## Parameters:
##   entity_id: Target entity ID
##   effect: StatusEffect instance to apply
##
## Returns:
##   bool - true if effect was applied/merged, false if invalid
func apply_status(entity_id: String, effect: StatusEffect) -> bool:
	if not effect.is_valid():
		Logger.warn("StatusEffectSystem: Invalid effect for %s: %s" % [entity_id, effect], "status")
		return false

	# Initialize entity effect array if needed
	if not _active_effects.has(entity_id):
		_active_effects[entity_id] = []

	var entity_effects: Array = _active_effects[entity_id]

	# Check for existing effect of same type from same source
	var existing_effect: StatusEffect = _find_existing_effect(entity_id, effect.effect_type, effect.source)

	if existing_effect:
		# Merge with existing effect based on stack behavior
		if effect.stack_behavior == StatusEffect.StackBehavior.STACK_DAMAGE:
			# Independent stack - add new instance
			entity_effects.append(effect)
			Logger.debug("StatusEffectSystem: Stacked %s on %s (independent)" % [effect.effect_type, entity_id], "status")
		else:
			# Merge into existing effect (no signal - effect already active)
			existing_effect.merge_with(effect)
			Logger.debug("StatusEffectSystem: Merged %s on %s (dur=%.1fs)" % [
				effect.effect_type, entity_id, existing_effect.remaining_duration
			], "status")
	else:
		# New effect - add to entity and emit signal
		entity_effects.append(effect)
		status_applied.emit(entity_id, effect.effect_type)
		Logger.debug("StatusEffectSystem: Applied %s to %s (dur=%.1fs, dmg=%.1f/tick)" % [
			effect.effect_type, entity_id, effect.remaining_duration, effect.damage_per_tick
		], "status")

	return true


## Check if entity has a specific status effect type
func has_status(entity_id: String, effect_type: String) -> bool:
	if not _active_effects.has(entity_id):
		return false

	for effect in _active_effects[entity_id]:
		if effect.effect_type == effect_type:
			return true

	return false


## Remove all effects of a specific type from an entity
func remove_status(entity_id: String, effect_type: String) -> void:
	if not _active_effects.has(entity_id):
		return

	var entity_effects: Array = _active_effects[entity_id]
	var i := 0
	var removed_any: bool = false

	while i < entity_effects.size():
		if entity_effects[i].effect_type == effect_type:
			entity_effects.remove_at(i)
			removed_any = true
			Logger.debug("StatusEffectSystem: Removed %s from %s" % [effect_type, entity_id], "status")
		else:
			i += 1

	# Emit signal if we removed at least one effect
	if removed_any:
		status_removed.emit(entity_id, effect_type)


## Remove all effects from an entity (e.g., on death)
func clear_all_status(entity_id: String) -> void:
	if _active_effects.has(entity_id):
		var entity_effects: Array = _active_effects[entity_id]
		var count: int = entity_effects.size()

		# Emit removal signals for each unique effect type
		var effect_types_removed: Dictionary = {}
		for effect in entity_effects:
			if not effect_types_removed.has(effect.effect_type):
				effect_types_removed[effect.effect_type] = true
				status_removed.emit(entity_id, effect.effect_type)

		_active_effects.erase(entity_id)
		Logger.debug("StatusEffectSystem: Cleared %d effects from %s" % [count, entity_id], "status")


## Get all active effects for an entity (for debugging/UI)
func get_active_effects(entity_id: String) -> Array:
	return _active_effects.get(entity_id, [])


# ============================================================================
# COMBAT STEP UPDATE
# ============================================================================

## Update all active effects (called at 30Hz by combat_step)
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	var delta_time: float = payload.dt

	# Track entities with expired effects for cleanup
	var entities_to_cleanup: Array[String] = []

	for entity_id in _active_effects.keys():
		var entity_effects: Array = _active_effects[entity_id]

		# Update each effect and apply ticks
		var i := 0
		while i < entity_effects.size():
			var effect: StatusEffect = entity_effects[i]

			# Update effect (returns number of ticks to apply this frame)
			var ticks_to_apply: int = effect.update(delta_time)

			# Apply all accumulated ticks (catch up on slow frames)
			for tick_count in range(ticks_to_apply):
				_apply_effect_tick(entity_id, effect)

			# Remove if expired
			if effect.is_expired():
				var effect_type: String = effect.effect_type
				Logger.debug("StatusEffectSystem: Expired %s on %s" % [effect_type, entity_id], "status")
				entity_effects.remove_at(i)

				# Emit removal signal if this was the last effect of this type
				if not _has_effect_type(entity_id, effect_type):
					status_removed.emit(entity_id, effect_type)
			else:
				i += 1

		# Mark empty entities for cleanup
		if entity_effects.is_empty():
			entities_to_cleanup.append(entity_id)

	# Clean up entities with no active effects
	for entity_id in entities_to_cleanup:
		_active_effects.erase(entity_id)


# ============================================================================
# EFFECT TICK APPLICATION
# ============================================================================

## Apply a single effect tick (damage, slow, etc.)
func _apply_effect_tick(entity_id: String, effect: StatusEffect) -> void:
	# Check if entity still alive (overkill prevention)
	if not DamageService.is_entity_alive(entity_id):
		return

	# Get entity position for damage source
	var entity_pos: Vector2 = EntityTracker.get_entity(entity_id).get("pos", Vector2.ZERO)

	# Apply damage for damaging effects
	if effect.damage_per_tick > 0.0:
		var damage_types: Array[String] = _get_damage_types_for_effect(effect.effect_type)

		DamageService._process_damage_immediate(
			entity_id,
			effect.damage_per_tick,
			effect.source,  # e.g., "item_poison"
			damage_types,   # e.g., ["poison", "dot"]
			0.0,            # No knockback
			entity_pos      # Source position
		)

		Logger.debug("StatusEffectSystem: Ticked %s on %s (dmg=%.1f)" % [
			effect.effect_type, entity_id, effect.damage_per_tick
		], "status")

	# Apply slow effects (handled via EffectSpawner for now - future: separate slow system)
	if effect.slow_mult < 1.0:
		# Could emit a signal here for future slow system
		pass


# ============================================================================
# HELPERS
# ============================================================================

## Find existing effect of same type and source
func _find_existing_effect(entity_id: String, effect_type: String, source: String) -> StatusEffect:
	if not _active_effects.has(entity_id):
		return null

	for effect in _active_effects[entity_id]:
		if effect.effect_type == effect_type and effect.source == source:
			return effect

	return null


## Check if entity has any effects of a specific type (for signal emission)
func _has_effect_type(entity_id: String, effect_type: String) -> bool:
	if not _active_effects.has(entity_id):
		return false

	for effect in _active_effects[entity_id]:
		if effect.effect_type == effect_type:
			return true

	return false


## Get damage types for an effect type
func _get_damage_types_for_effect(effect_type: String) -> Array[String]:
	match effect_type:
		"poison":
			return ["poison", "dot"]
		"burn":
			return ["fire", "dot"]
		"bleed":
			return ["physical", "dot"]
		_:
			return ["dot"]


# ============================================================================
# DEBUGGING
# ============================================================================

## Get debug stats for all active effects
func get_debug_stats() -> Dictionary:
	var total_effects := 0
	var effects_by_type: Dictionary = {}

	for entity_effects in _active_effects.values():
		for effect in entity_effects:
			total_effects += 1

			if not effects_by_type.has(effect.effect_type):
				effects_by_type[effect.effect_type] = 0
			effects_by_type[effect.effect_type] += 1

	return {
		"total_effects": total_effects,
		"affected_entities": _active_effects.size(),
		"effects_by_type": effects_by_type
	}
