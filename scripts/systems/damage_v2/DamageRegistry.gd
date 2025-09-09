extends Node

## Unified Damage Registry - Clean slate implementation
## Single damage pipeline for all entity types (pooled enemies, scene bosses, player)
## Uses Dictionary-based entity storage to avoid circular dependencies

class_name DamageRegistryV2

# Preload utility classes for zero-allocation damage queue
const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd")
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

var _entities: Dictionary = {}  # String ID -> Dictionary data
var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 10.0  # Cleanup every 10 seconds

# Zero-allocation damage queue components (only initialized when enabled)
var _damage_queue
var _payload_pool
var _tags_pool
var _processor_timer: Timer
var _queue_enabled: bool = false

# Queue metrics
var _enqueued: int = 0
var _processed: int = 0
var _dropped_overflow: int = 0
var _max_watermark: int = 0
var _last_tick_ms: float = 0.0
var _total_ticks: int = 0

signal damage_applied(entity_id: String, damage: float, killed: bool)
signal entity_registered(entity_id: String, entity_type: String)
signal entity_unregistered(entity_id: String)

func _ready() -> void:
	Logger.info("DamageRegistry initialized", "combat")
	_setup_queue_if_enabled()
	
	# Connect to pause system for queue management
	EventBus.game_paused_changed.connect(_on_paused_changed)

## Setup zero-allocation damage queue if enabled by config
func _setup_queue_if_enabled() -> void:
	_queue_enabled = BalanceDB.get_combat_value("use_zero_alloc_damage_queue")
	if not _queue_enabled:
		return
		
	# Initialize queue components
	_damage_queue = RingBufferUtil.new()
	_damage_queue.setup(BalanceDB.get_combat_value("damage_queue_capacity"))
	
	_payload_pool = ObjectPoolUtil.new()
	_payload_pool.setup(
		BalanceDB.get_combat_value("damage_pool_size"),
		PayloadResetUtil.create_damage_payload,
		PayloadResetUtil.clear_damage_payload
	)
	
	_tags_pool = ObjectPoolUtil.new()
	_tags_pool.setup(
		128, # Smaller pool for tag arrays
		PayloadResetUtil.create_tags_array,
		PayloadResetUtil.clear_tags_array
	)
	
	# Setup 30Hz processor timer
	_processor_timer = Timer.new()
	_processor_timer.one_shot = false
	_processor_timer.wait_time = 1.0 / BalanceDB.get_combat_value("damage_queue_tick_rate_hz")
	add_child(_processor_timer)
	_processor_timer.timeout.connect(_process_damage_queue_tick)
	
	# Start processor (will be paused if game is paused)
	_apply_pause_state(get_tree().paused)
	
	Logger.info("Zero-alloc damage queue initialized (capacity: %d, pool: %d)" % [
		_damage_queue.capacity(), _payload_pool.available_count()
	], "combat")

## Handle pause state changes
func _on_paused_changed(payload) -> void:
	var is_paused = payload.is_paused if payload else false
	_apply_pause_state(is_paused)

## Apply pause state to queue processor
func _apply_pause_state(is_paused: bool) -> void:
	if not _queue_enabled or not _processor_timer:
		return
		
	if is_paused:
		_processor_timer.stop()
	else:
		_processor_timer.start()

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
	if _queue_enabled:
		return _enqueue_damage(target_id, amount, source, tags, knockback_distance, source_position)
	else:
		return _process_damage_immediate(target_id, amount, source, tags, knockback_distance, source_position)

## Enqueue damage for batched processing (zero-allocation path)
func _enqueue_damage(target_id: String, amount: float, source: String, tags: Array, knockback_distance: float, source_position: Vector2) -> bool:
	# Early validation to avoid wasted queue operations
	if not _entities.has(target_id):
		Logger.warn("Damage requested on unknown entity: " + target_id, "combat")
		return false
	
	var entity: Dictionary = _entities[target_id]
	if not entity.get("alive", true):
		Logger.warn("Damage requested on dead entity: " + target_id, "combat")
		return false
	
	# Acquire pooled payload
	var d: Dictionary = _payload_pool.acquire()
	d["target"] = target_id
	d["source"] = source
	d["base_damage"] = amount
	d["damage_type"] = "generic"  # Default damage type
	d["knockback"] = knockback_distance
	d["source_pos"] = source_position
	
	# Copy tags using pooled array
	var t: Array = _tags_pool.acquire()
	for tag in tags:
		t.push_back(tag)
	d["tags"] = t
	
	# Try to enqueue
	if not _damage_queue.try_push(d):
		# Queue full: implement drop-oldest policy
		var dropped: Dictionary = _damage_queue.try_pop()
		if dropped != null:
			var dropped_tags: Array = dropped.get("tags", null)
			if dropped_tags != null:
				_tags_pool.release(dropped_tags)
			_payload_pool.release(dropped)
		
		# Try to enqueue again
		if not _damage_queue.try_push(d):
			# Hard drop: queue still full somehow
			var d_tags: Array = d.get("tags", null)
			if d_tags != null:
				_tags_pool.release(d_tags)
			_payload_pool.release(d)
			_dropped_overflow += 1
			if (_dropped_overflow % 100) == 0:  # Throttled warning
				Logger.warn("Damage queue hard drop (total: %d)" % _dropped_overflow, "combat")
			return false
		_dropped_overflow += 1
	
	_enqueued += 1
	if _damage_queue.count() > _max_watermark:
		_max_watermark = _damage_queue.count()
	return true

## Process damage immediately (original path, used when queue disabled)
func _process_damage_immediate(target_id: String, amount: float, source: String, tags: Array, knockback_distance: float, source_position: Vector2) -> bool:
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

## Process queued damage at fixed 30Hz rate
func _process_damage_queue_tick() -> void:
	if not _queue_enabled:
		return
		
	var start_time = Time.get_ticks_msec()
	var max_per_tick = BalanceDB.get_combat_value("damage_queue_max_per_tick")
	var processed = 0
	
	while processed < max_per_tick:
		var d = _damage_queue.try_pop()
		if d == null:
			break
			
		# Process damage using existing internal logic
		var tags: Array = d.get("tags", null)
		var _was_killed = _process_damage_immediate(
			d["target"], 
			d["base_damage"], 
			d["source"], 
			tags if tags else [], 
			d.get("knockback", 0.0), 
			d.get("source_pos", Vector2.ZERO)
		)
		
		# Release back to pools
		if tags != null:
			_tags_pool.release(tags)
			d["tags"] = []  # Detach to avoid double-release
		_payload_pool.release(d)
		processed += 1
	
	_processed += processed
	_total_ticks += 1
	_last_tick_ms = Time.get_ticks_msec() - start_time

## Update entity position for spatial queries
## @param entity_id: String identifier of entity to update
## @param new_pos: New position of the entity
func update_entity_position(entity_id: String, new_pos: Vector2) -> void:
	if _entities.has(entity_id):
		_entities[entity_id]["pos"] = new_pos

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

## Get all entities within radius of position (spatial query)
## @param center: Center position for search
## @param radius: Search radius in pixels  
## @param filter_types: Optional array of entity types to include (e.g., ["boss", "enemy"])
## @return Array of entity IDs within radius
func get_entities_in_area(center: Vector2, radius: float, filter_types: Array = []) -> Array[String]:
	var result: Array[String] = []
	
	for entity_id in _entities.keys():
		var entity_data = _entities[entity_id]
		
		# Skip dead entities
		if not entity_data.get("alive", false):
			continue
			
		# Apply type filter if specified
		if not filter_types.is_empty():
			var entity_type = entity_data.get("type", "")
			if not filter_types.has(entity_type):
				continue
		
		# Distance check
		var entity_pos = entity_data.get("pos", Vector2.ZERO)
		if center.distance_to(entity_pos) <= radius:
			result.append(entity_id)
	
	return result

## Get entities in cone area (for melee attacks, projectile targeting)
## @param origin: Cone apex position
## @param direction: Cone direction (normalized vector)
## @param angle_degrees: Cone angle in degrees  
## @param max_range: Maximum range
## @param filter_types: Optional array of entity types to include
## @return Array of entity IDs in cone
func get_entities_in_cone(origin: Vector2, direction: Vector2, angle_degrees: float, max_range: float, filter_types: Array = []) -> Array[String]:
	# First get all entities in range, then filter by cone
	var entities_in_range = get_entities_in_area(origin, max_range, filter_types)
	var result: Array[String] = []
	
	var cone_radians = deg_to_rad(angle_degrees)
	var min_dot = cos(cone_radians / 2.0)
	
	for entity_id in entities_in_range:
		var entity_data = _entities[entity_id]
		var entity_pos = entity_data.get("pos", Vector2.ZERO)
		
		# Check if in cone angle
		var to_entity = (entity_pos - origin).normalized()
		var dot_product = to_entity.dot(direction)
		
		if dot_product >= min_dot:
			result.append(entity_id)
	
	return result

## Calculate final damage with modifiers
func _calculate_final_damage(base_damage: float, _tags: Array) -> float:
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
			# Emit enemy killed event for XP/loot (bosses give more XP)
			var boss_xp_value = 50  # Bosses give 50 XP vs regular enemies' 1 XP
			var payload = EventBus.EnemyKilledPayload_Type.new(position, boss_xp_value)
			EventBus.enemy_killed.emit(payload)
			Logger.info("Boss defeated: " + entity_id + " (XP: %d)" % boss_xp_value, "combat")
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

## Get queue metrics for debugging and monitoring
func get_queue_stats() -> Dictionary:
	if not _queue_enabled:
		return {"enabled": false}
	
	return {
		"enabled": true,
		"enqueued": _enqueued,
		"processed": _processed,
		"dropped_overflow": _dropped_overflow,
		"max_watermark": _max_watermark,
		"current_queue_size": _damage_queue.count() if _damage_queue else 0,
		"queue_capacity": _damage_queue.capacity() if _damage_queue else 0,
		"last_tick_ms": _last_tick_ms,
		"total_ticks": _total_ticks,
		"payload_pool_available": _payload_pool.available_count() if _payload_pool else 0,
		"tags_pool_available": _tags_pool.available_count() if _tags_pool else 0
	}

## Toggle queue on/off at runtime for A/B testing
func set_queue_enabled(enabled: bool) -> void:
	if enabled == _queue_enabled:
		return
		
	if enabled and not _queue_enabled:
		# Enable queue
		_setup_queue_if_enabled()
	elif not enabled and _queue_enabled:
		# Disable queue - process any remaining items
		if _damage_queue:
			while not _damage_queue.is_empty():
				_process_damage_queue_tick()
		
		# Cleanup queue components
		if _processor_timer:
			_processor_timer.stop()
			_processor_timer.queue_free()
			_processor_timer = null
		
		_damage_queue = null
		_payload_pool = null
		_tags_pool = null
		_queue_enabled = false
		
		Logger.info("Zero-alloc damage queue disabled", "combat")

## Reset queue metrics
func reset_queue_metrics() -> void:
	_enqueued = 0
	_processed = 0
	_dropped_overflow = 0
	_max_watermark = 0
	_last_tick_ms = 0.0
	_total_ticks = 0
