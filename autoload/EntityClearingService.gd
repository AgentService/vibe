extends Node

## Production autoload for entity and transient object clearing
## Provides safe, unified clearing functionality for all production scenarios
## Replaces the misplaced entity clearing logic that was in DebugManager

func _ready() -> void:
	Logger.info("EntityClearingService: Production entity clearing system initialized", "system")

func clear_all_entities() -> void:
	"""Clean entity clearing using semantic groups - only clears enemies and their effects"""
	Logger.info("EntityClearingService: Starting semantic enemy clear (enemies + effects, no death events)", "system")
	var cleared_count := 0

	# Method 1: Reset WaveDirector to clear internal state (legacy pooled enemies if any remain)
	var wave_directors := get_tree().get_nodes_in_group("wave_directors")
	for wave_director in wave_directors:
		if is_instance_valid(wave_director) and wave_director.has_method("reset"):
			Logger.debug("Resetting WaveDirector: %s" % wave_director.name, "system")
			wave_director.reset()
			cleared_count += 50  # Approximate pool enemy count

	# Method 2: Clean tracking systems (EntityTracker, DamageService) - only non-player entities
	var all_entities := EntityTracker.get_alive_entities()
	for entity_id in all_entities:
		var entity_data := EntityTracker.get_entity(entity_id)
		var entity_type = entity_data.get("type", "unknown")

		# Skip player entities to avoid clearing the player
		if entity_type == "player":
			continue

		# Clean removal from tracking systems without death events
		Logger.debug("Clean removing tracked entity: %s (type: %s)" % [entity_id, entity_type], "system")
		EntityTracker.unregister_entity(entity_id)
		if DamageService.is_entity_alive(entity_id):
			DamageService.unregister_entity(entity_id)
		cleared_count += 1

	# Method 3: Clear scene-based entities via semantic groups
	cleared_count += _clear_semantic_group(ClearingSemantics.CLEAR_WITH_ENEMIES, "enemies")
	cleared_count += _clear_semantic_group(ClearingSemantics.CLEAR_WITH_ENEMY_EFFECTS, "enemy effects")

	# Legacy fallback: Clear old "enemies" group for backward compatibility
	var legacy_enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in legacy_enemies:
		if is_instance_valid(enemy):
			# Only clear if not already cleared by semantic groups
			if not enemy.is_in_group(ClearingSemantics.CLEAR_WITH_ENEMIES):
				Logger.debug("Legacy clear: removing enemy node: %s" % enemy.name, "system")
				enemy.queue_free()
				cleared_count += 1

	Logger.info("EntityClearingService: Semantically cleared %d entities (enemies + effects, preserving persistent events)" % cleared_count, "system")

func clear_transient_objects() -> void:
	"""Clear transient objects (XP orbs, items, projectiles, etc.) via semantic groups"""
	Logger.info("EntityClearingService: Starting semantic transient object clear", "system")
	var cleared_count := 0

	# Clear objects marked for transient clearing
	cleared_count += _clear_semantic_group(ClearingSemantics.CLEAR_WITH_TRANSIENTS, "transient objects")

	# Legacy fallback: Clear old "transient" group for backward compatibility
	var legacy_transients := get_tree().get_nodes_in_group("transient")
	for obj in legacy_transients:
		if is_instance_valid(obj):
			# Only clear if not already cleared by semantic groups
			if not obj.is_in_group(ClearingSemantics.CLEAR_WITH_TRANSIENTS):
				Logger.debug("Legacy clear: transient object: %s" % obj.name, "system")
				obj.queue_free()
				cleared_count += 1

	Logger.info("EntityClearingService: Semantically cleared %d transient objects" % cleared_count, "system")

func clear_all_world_objects() -> void:
	"""Combined clean clear for complete world reset - no death events or XP spawning"""
	Logger.info("EntityClearingService: Starting complete world clear", "system")
	
	# Clear existing transient objects (XP orbs, etc.)
	clear_transient_objects()
	
	# Clean clear entities (no death events, no XP spawning)
	clear_all_entities()
	
	Logger.info("EntityClearingService: Complete world clear finished - no XP orbs spawned", "system")

## Helper method to clear a specific semantic group
func _clear_semantic_group(semantic_group: String, group_description: String) -> int:
	var nodes := get_tree().get_nodes_in_group(semantic_group)
	var cleared_count := 0

	Logger.debug("Found %d objects in semantic group '%s' (%s)" % [nodes.size(), semantic_group, group_description], "system")

	for obj in nodes:
		if is_instance_valid(obj):
			Logger.debug("Semantically clearing %s: %s" % [group_description, obj.name], "system")
			obj.queue_free()
			cleared_count += 1
		else:
			Logger.debug("Skipping invalid object in semantic group '%s'" % semantic_group, "system")

	return cleared_count
