extends Node

## Unified Damage Registry - Clean slate implementation
## Single damage pipeline for all entity types (pooled enemies, scene bosses, player)
## Uses Dictionary-based entity storage to avoid circular dependencies

class_name DamageRegistryV2

var _entities: Dictionary = {}  # String ID -> Dictionary data
var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 10.0  # Cleanup every 10 seconds

signal damage_applied(entity_id: String, damage: float, killed: bool)
signal entity_registered(entity_id: String, entity_type: String)
signal entity_unregistered(entity_id: String)

func _ready() -> void:
	Logger.info("DamageRegistry initialized", "combat")

func _process(delta: float) -> void:
	# Periodic cleanup of dead entities
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_dead_entities()
		_cleanup_timer = 0.0

## Register an entity with the damage system
## @param id: Unique string identifier (e.g., "enemy_0", "boss_ancient_lich", "player")
## @param data: Dictionary containing entity data
func register_entity(id: String, data: Dictionary) -> void:
	_entities[id] = data
	entity_registered.emit(id, data.get("type", "unknown"))
	
	# Debug logging removed for cleaner testing

## Unregister an entity from the damage system
func unregister_entity(id: String) -> void:
	if _entities.has(id):
		_entities.erase(id)
		entity_unregistered.emit(id)

## Apply damage to an entity
## @param target_id: String ID of target entity
## @param amount: Base damage amount
## @param source: String identifying damage source (for logging)
## @param tags: Array of damage tags (e.g., ["melee", "fire"])
## @param knockback_distance: Knockback distance in pixels
## @param source_position: Position of damage source for knockback direction
## @return bool: True if entity was killed, false otherwise
func apply_damage(target_id: String, amount: float, source: String = "unknown", tags: Array = [], knockback_distance: float = 0.0, source_position: Vector2 = Vector2.ZERO) -> bool:
	if not _entities.has(target_id):
		Logger.warn("Damage requested on unknown entity: " + target_id, "combat")
		return false
	
	var entity: Dictionary = _entities[target_id]
	if not entity.get("alive", true):
		Logger.warn("Damage requested on dead entity: " + target_id, "combat")
		return false
	
	# Calculate final damage (add crit, modifiers, etc. here)
	var final_damage: float = _calculate_final_damage(amount, tags)
	
	# Apply damage
	var old_hp: float = entity.get("hp", 0.0)
	entity["hp"] = max(0.0, old_hp - final_damage)
	var new_hp: float = entity["hp"]
	
	Logger.info("Entity %s: %.1f → %.1f HP (took %.1f damage from %s)" % [target_id, old_hp, new_hp, final_damage, source], "combat")
	
	# CRITICAL: Sync damage back to actual game entities via unified pipeline
	_sync_damage_to_game_entity(target_id, entity, final_damage, new_hp)
	
	# Handle death
	var was_killed: bool = false
	if new_hp <= 0.0 and entity.get("alive", true):
		entity["alive"] = false
		was_killed = true
		Logger.info("Entity %s KILLED by %s" % [target_id, source], "combat")
		_handle_entity_death(target_id, entity)
	
	# Determine if this was a critical hit for visual feedback
	var is_crit: bool = final_damage > amount * 1.5  # Simple crit detection
	
	# Create EntityId from string target_id
	var entity_id: EntityId
	if target_id.begins_with("enemy_"):
		var enemy_index = target_id.replace("enemy_", "").to_int()
		entity_id = EntityId.enemy(enemy_index)
	elif target_id.begins_with("boss_"):
		var boss_index = target_id.replace("boss_", "").to_int()
		entity_id = EntityId.new(EntityId.Type.ENEMY, boss_index)  # Treat bosses as special enemies
	elif target_id == "player":
		entity_id = EntityId.player()
	else:
		# Fallback for unknown entity types
		entity_id = EntityId.new(EntityId.Type.ENEMY, 0)
	
	# Create and emit damage applied payload with knockback info
	var damage_payload = EventBus.DamageAppliedPayload_Type.new(
		entity_id,
		final_damage,
		is_crit,
		PackedStringArray(tags),
		knockback_distance,
		source_position
	)
	EventBus.damage_applied.emit(damage_payload)
	
	# Legacy signal for backward compatibility
	damage_applied.emit(target_id, final_damage, was_killed)
	
	return was_killed

## Get entity data by ID
func get_entity(entity_id: String) -> Dictionary:
	return _entities.get(entity_id, {})

## Check if entity exists and is alive
func is_entity_alive(entity_id: String) -> bool:
	var entity: Dictionary = _entities.get(entity_id, {})
	return entity.get("alive", false)

## Get all entities of a specific type
func get_entities_by_type(entity_type: String) -> Array[String]:
	var result: Array[String] = []
	for id in _entities.keys():
		var entity: Dictionary = _entities[id]
		if entity.get("type", "") == entity_type:
			result.append(id)
	return result

## Get all alive entities
func get_alive_entities() -> Array[String]:
	var result: Array[String] = []
	for id in _entities.keys():
		var entity: Dictionary = _entities[id]
		if entity.get("alive", false):
			result.append(id)
	return result

## Calculate final damage with modifiers
func _calculate_final_damage(base_damage: float, tags: Array) -> float:
	var final_damage: float = base_damage
	
	# Apply crit chance (10% base crit)
	var is_crit: bool = RNG.randf("crit") < 0.1
	if is_crit:
		final_damage *= 2.0
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("CRITICAL HIT! Damage: %.1f → %.1f" % [base_damage, final_damage], "combat")
	
	# TODO: Add other damage modifiers here (resistances, vulnerabilities, etc.)
	
	return final_damage

## Handle entity death (emit events, cleanup, etc.)
func _handle_entity_death(entity_id: String, entity_data: Dictionary) -> void:
	var entity_type: String = entity_data.get("type", "unknown")
	var position: Vector2 = entity_data.get("pos", Vector2.ZERO)
	
	# Emit appropriate death events based on entity type
	match entity_type:
		"enemy":
			# Emit enemy killed event for XP/loot
			var payload = EventBus.EnemyKilledPayload_Type.new(position, 1)
			EventBus.enemy_killed.emit(payload)
		"boss":
			# TODO: Handle boss death events
			Logger.info("Boss defeated: " + entity_id, "combat")
		"player":
			# TODO: Handle player death
			Logger.info("Player defeated!", "combat")
		_:
			Logger.debug("Unknown entity type died: " + entity_type, "combat")
	
	# Clean up: Unregister dead entity to prevent memory leaks
	# Wait a frame to allow any final processing, then cleanup
	await get_tree().process_frame
	if _entities.has(entity_id):
		unregister_entity(entity_id)

## Unified damage syncing via EventBus signals (cleaner, decoupled)
func _sync_damage_to_game_entity(entity_id: String, entity_data: Dictionary, damage: float, new_hp: float) -> void:
	var entity_type: String = entity_data.get("type", "unknown")
	
	# Create a standardized damage sync payload
	var sync_payload = {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"damage": damage,
		"new_hp": new_hp,
		"is_death": new_hp <= 0.0
	}
	
	# Emit damage sync event for systems to handle
	# This removes the need for DamageRegistry to know about WaveDirector/Boss internals
	EventBus.damage_entity_sync.emit(sync_payload)
	Logger.debug("Emitted damage sync for %s (HP: %.1f)" % [entity_id, new_hp], "combat")


## DEBUG: Register all existing entities that haven't been registered yet
func debug_register_all_existing_entities() -> void:
	Logger.info("DEBUG: Scanning for unregistered entities...", "combat")
	var registered_count = 0
	
	# Register existing bosses
	var scene_root = get_tree().current_scene
	if scene_root:
		for node in scene_root.get_children():
			if node.has_method("get_current_health") and node.has_method("get_max_health"):
				var entity_id = "boss_" + str(node.get_instance_id())
				if not _entities.has(entity_id):
					var entity_data = {
						"id": entity_id,
						"type": "boss",
						"hp": node.get_current_health(),
						"max_hp": node.get_max_health(),
						"alive": node.is_alive() if node.has_method("is_alive") else true,
						"pos": node.global_position
					}
					register_entity(entity_id, entity_data)
					registered_count += 1
					Logger.info("DEBUG: Registered existing boss: " + entity_id, "combat")
	
	# Register existing enemies from WaveDirector
	var wave_director = get_tree().get_first_node_in_group("wave_directors")
	if wave_director:
		for i in range(wave_director.enemies.size()):
			var enemy = wave_director.enemies[i]
			if enemy.alive:
				var entity_id = "enemy_" + str(i)
				if not _entities.has(entity_id):
					var entity_data = {
						"id": entity_id,
						"type": "enemy",
						"hp": enemy.hp,
						"max_hp": enemy.hp,  # Assuming current HP is max for existing enemies
						"alive": true,
						"pos": enemy.pos
					}
					register_entity(entity_id, entity_data)
					registered_count += 1
					Logger.info("DEBUG: Registered existing enemy: " + entity_id, "combat")
	
	Logger.info("DEBUG: Registered " + str(registered_count) + " existing entities", "combat")

## Cleanup dead entities to prevent memory leaks
func cleanup_dead_entities() -> void:
	var cleanup_count = 0
	var entities_to_remove: Array[String] = []
	
	for entity_id in _entities.keys():
		var entity: Dictionary = _entities[entity_id]
		if not entity.get("alive", false):
			entities_to_remove.append(entity_id)
	
	for entity_id in entities_to_remove:
		unregister_entity(entity_id)
		cleanup_count += 1
	
	if cleanup_count > 0:
		Logger.debug("Cleaned up " + str(cleanup_count) + " dead entities", "combat")
