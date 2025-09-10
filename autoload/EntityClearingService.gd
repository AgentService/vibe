extends Node

## Production autoload for entity and transient object clearing
## Provides safe, unified clearing functionality for all production scenarios
## Replaces the misplaced entity clearing logic that was in DebugManager

func _ready() -> void:
	Logger.info("EntityClearingService: Production entity clearing system initialized", "system")

func clear_all_entities() -> void:
	"""Clean entity clearing using WaveDirector reset and scene groups"""
	Logger.info("EntityClearingService: Starting clean entity clear (no death events)", "system")
	var cleared_count := 0
	
	# Method 1: Reset WaveDirector to properly clear all MultiMesh pool enemies
	var wave_directors := get_tree().get_nodes_in_group("wave_directors")
	for wave_director in wave_directors:
		if is_instance_valid(wave_director) and wave_director.has_method("reset"):
			Logger.debug("Resetting WaveDirector: %s" % wave_director.name, "system")
			wave_director.reset()
			cleared_count += 50  # Approximate pool enemy count
	
	# Method 2: Clean tracking systems (EntityTracker, DamageService)
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
	
	# Method 3: Clear scene-based entities via groups (bosses, instanced enemies)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var arena_owned := get_tree().get_nodes_in_group("arena_owned")
	
	Logger.debug("Found %d enemies and %d arena_owned objects to clear via groups" % [enemies.size(), arena_owned.size()], "system")
	
	# Clear enemies group (bosses, instanced enemies)
	for enemy in enemies:
		if is_instance_valid(enemy):
			Logger.debug("Clean removing enemy node: %s" % enemy.name, "system")
			enemy.queue_free()
			cleared_count += 1
	
	# Clear arena_owned group (projectiles, effects, etc.)
	for obj in arena_owned:
		if is_instance_valid(obj) and not obj.is_in_group("enemies"):  # Avoid double-clearing
			Logger.debug("Clean removing arena object: %s" % obj.name, "system") 
			obj.queue_free()
			cleared_count += 1
	
	Logger.info("EntityClearingService: Clean removed ~%d entities (WaveDirector reset + groups + tracking, no XP orbs spawned)" % cleared_count, "system")

func clear_transient_objects() -> void:
	"""Clear transient objects (XP orbs, items, projectiles, etc.) via group system"""
	Logger.info("EntityClearingService: Starting transient object clear", "system")
	var cleared_count := 0
	
	# Clear XP orbs and other transient objects
	var transients := get_tree().get_nodes_in_group("transient")
	Logger.debug("Found %d objects in 'transient' group" % transients.size(), "system")
	
	for obj in transients:
		if is_instance_valid(obj):
			Logger.debug("Clearing transient object: %s (type: %s)" % [obj.name, obj.get_class()], "system")
			obj.queue_free()
			cleared_count += 1
		else:
			Logger.debug("Skipping invalid transient object", "system")
	
	Logger.info("EntityClearingService: Cleared %d transient objects (XP orbs, etc.)" % cleared_count, "system")

func clear_all_world_objects() -> void:
	"""Combined clean clear for complete world reset - no death events or XP spawning"""
	Logger.info("EntityClearingService: Starting complete world clear", "system")
	
	# Clear existing transient objects (XP orbs, etc.)
	clear_transient_objects()
	
	# Clean clear entities (no death events, no XP spawning)
	clear_all_entities()
	
	Logger.info("EntityClearingService: Complete world clear finished - no XP orbs spawned", "system")
