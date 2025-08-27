extends Node

## Unified Damage Registry V2 - Clean slate implementation
## Single damage pipeline for all entity types (pooled enemies, scene bosses, player)
## Uses Dictionary-based entity storage to avoid circular dependencies

class_name DamageRegistryV2

var _entities: Dictionary = {}  # String ID -> Dictionary data

signal damage_applied(entity_id: String, damage: float, killed: bool)
signal entity_registered(entity_id: String, entity_type: String)
signal entity_unregistered(entity_id: String)

func _ready() -> void:
	Logger.info("DamageRegistry V2 initialized", "combat")

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
## @return bool: True if entity was killed, false otherwise
func apply_damage(target_id: String, amount: float, source: String = "unknown", tags: Array = []) -> bool:
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
	
	# Handle death
	var was_killed: bool = false
	if new_hp <= 0.0 and entity.get("alive", true):
		entity["alive"] = false
		was_killed = true
		Logger.info("Entity %s KILLED by %s" % [target_id, source], "combat")
		_handle_entity_death(target_id, entity)
	
	# Emit damage applied signal
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