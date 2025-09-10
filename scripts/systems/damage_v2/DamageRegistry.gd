extends Node

## Unified Damage Registry - Clean slate implementation
## Single damage pipeline for all entity types (pooled enemies, scene bosses, player)
## Uses Dictionary-based entity storage to avoid circular dependencies

class_name DamageRegistryV2

# Preload utility classes for zero-allocation damage queue
const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd")
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

# PHASE 7 OPTIMIZATION: Replace Dictionary with PackedArray-based storage (10-15MB reduction)
# Use parallel arrays for entity data instead of Dictionary of Dictionaries
var _entity_ids: PackedStringArray = PackedStringArray()          # Entity IDs ["enemy_0", "enemy_1", ...]
var _entity_types: PackedStringArray = PackedStringArray()        # Entity types ["enemy", "boss", "player"]
var _entity_positions_x: PackedFloat32Array = PackedFloat32Array() # X positions
var _entity_positions_y: PackedFloat32Array = PackedFloat32Array() # Y positions  
var _entity_hp: PackedFloat32Array = PackedFloat32Array()          # Current HP
var _entity_max_hp: PackedFloat32Array = PackedFloat32Array()      # Max HP
var _entity_alive: PackedByteArray = PackedByteArray()             # Alive status (0/1 instead of bool)
var _entity_count: int = 0                                         # Current number of entities
var _entity_lookup: Dictionary = {}                                # String ID -> index mapping (smaller than full data Dictionary)

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
	# Check config for zero-allocation damage queue
	_queue_enabled = BalanceDB.get_combat_value("use_zero_alloc_damage_queue")
	Logger.info("Zero-allocation damage queue: %s" % ("ENABLED" if _queue_enabled else "DISABLED"), "combat")
	
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
	# PHASE 7 OPTIMIZATION: Use PackedArray storage instead of Dictionary
	var existing_index = _entity_lookup.get(id, -1)
	if existing_index != -1:
		# Update existing entity
		_update_entity_at_index(existing_index, data)
	else:
		# Add new entity
		_add_new_entity(id, data)
	
	entity_registered.emit(id, data.get("type", "unknown"))

## PHASE 7: Add new entity to PackedArray storage
func _add_new_entity(id: String, data: Dictionary) -> void:
	var index = _entity_count
	_entity_lookup[id] = index
	
	# Ensure arrays have enough capacity
	if _entity_ids.size() <= index:
		_entity_ids.resize(index + 1)
		_entity_types.resize(index + 1)
		_entity_positions_x.resize(index + 1)
		_entity_positions_y.resize(index + 1)
		_entity_hp.resize(index + 1)
		_entity_max_hp.resize(index + 1)
		_entity_alive.resize(index + 1)
	
	# Store entity data in parallel arrays
	_entity_ids[index] = id
	_entity_types[index] = data.get("type", "unknown")
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	_entity_positions_x[index] = pos.x
	_entity_positions_y[index] = pos.y
	_entity_hp[index] = data.get("hp", 0.0)
	_entity_max_hp[index] = data.get("max_hp", data.get("hp", 0.0))
	_entity_alive[index] = 1 if data.get("alive", true) else 0
	
	_entity_count += 1

## PHASE 7: Update existing entity in PackedArray storage  
func _update_entity_at_index(index: int, data: Dictionary) -> void:
	_entity_types[index] = data.get("type", _entity_types[index])
	var pos: Vector2 = data.get("pos", Vector2(_entity_positions_x[index], _entity_positions_y[index]))
	_entity_positions_x[index] = pos.x
	_entity_positions_y[index] = pos.y
	_entity_hp[index] = data.get("hp", _entity_hp[index])
	_entity_max_hp[index] = data.get("max_hp", _entity_max_hp[index])
	_entity_alive[index] = 1 if data.get("alive", _entity_alive[index] == 1) else 0

## Unregister an entity from the damage system
func unregister_entity(id: String) -> void:
	# PHASE 7 OPTIMIZATION: Use PackedArray storage instead of Dictionary
	var index = _entity_lookup.get(id, -1)
	if index != -1:
		_remove_entity_at_index(index, id)
		entity_unregistered.emit(id)

## PHASE 7: Remove entity from PackedArray storage
func _remove_entity_at_index(index: int, id: String) -> void:
	# Mark as dead instead of removing to avoid array shifts
	_entity_alive[index] = 0
	_entity_lookup.erase(id)
	Logger.debug("Entity unregistered from DamageRegistry: %s" % id, "combat")


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
	# Early validation to avoid wasted queue operations - PHASE 7 OPTIMIZATION
	var index = _entity_lookup.get(target_id, -1)
	if index == -1:
		Logger.warn("Damage requested on unknown entity: " + target_id, "combat")
		return false
	
	if _entity_alive[index] == 0:
		Logger.warn("Damage requested on dead entity: " + target_id, "combat")
		return false
	
	# Check god mode for player damage (queue path)
	if target_id == "player" and CheatSystem and CheatSystem.is_god_mode_active():
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
	# PHASE 7 OPTIMIZATION: Use PackedArray storage instead of Dictionary lookup
	var index = _entity_lookup.get(target_id, -1)
	if index == -1:
		# During cleanup operations, many entities may be unregistered simultaneously
		# Only warn if this isn't a debug clear operation to reduce cleanup spam
		if source != "debug_clear_all":
			Logger.warn("Damage requested on unknown entity: " + target_id, "combat")
		return false
	
	if _entity_alive[index] == 0:
		# Similar throttling for dead entity warnings during cleanup
		if source != "debug_clear_all":
			Logger.warn("Damage requested on dead entity: " + target_id, "combat")
		return false
	
	# Check god mode for player damage
	if target_id == "player" and CheatSystem and CheatSystem.is_god_mode_active():
		return false
	
	# Calculate final damage (add crit, modifiers, etc. here)
	var final_damage: float = _calculate_final_damage(amount, tags)
	
	# Apply damage using PackedArray storage
	var old_hp: float = _entity_hp[index]
	var new_hp: float = max(0.0, old_hp - final_damage)
	_entity_hp[index] = new_hp
	
	Logger.info("Entity %s: %.1f → %.1f HP (took %.1f damage from %s)" % [target_id, old_hp, new_hp, final_damage, source], "combat")
	
	# CRITICAL: Sync damage back to actual game entities via unified pipeline
	_sync_damage_to_game_entity_packed(target_id, index, final_damage, new_hp)
	
	# Handle death using PackedArray storage
	var was_killed: bool = false
	if new_hp <= 0.0 and _entity_alive[index] == 1:
		_entity_alive[index] = 0
		was_killed = true
		Logger.info("Entity %s KILLED by %s" % [target_id, source], "combat")
		_handle_entity_death_packed(target_id, index)
	
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
	
	# Create and emit damage applied payload with knockback info (using object pool)
	var damage_payload = EventBus.acquire_damage_applied_payload()
	damage_payload.setup(
		entity_id,
		final_damage,
		is_crit,
		PackedStringArray(tags),
		knockback_distance,
		source_position
	)
	EventBus.damage_applied.emit(damage_payload)
	# Release payload back to pool after emission for reuse
	EventBus.release_damage_applied_payload(damage_payload)
	
	# Emit damage_dealt signal for camera shake and stats tracking
	var damage_dealt_payload = EventBus.DamageDealtPayload_Type.new(
		final_damage,
		_map_source_for_damage_dealt(source),
		target_id
	)
	EventBus.damage_dealt.emit(damage_dealt_payload)
	
	# Legacy signal for backward compatibility
	damage_applied.emit(target_id, final_damage, was_killed)
	
	return was_killed

## Map damage source to player/enemy for damage_dealt signal
func _map_source_for_damage_dealt(source: String) -> String:
	# Map various player damage sources to "player" for stats tracking
	if source in ["melee", "projectile", "ability", "player"]:
		return "player"
	elif source in ["enemy", "boss", "environment"]:
		return source
	else:
		# Default unknown sources to "unknown"
		return "unknown"

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
	# PHASE 7 OPTIMIZATION: Use PackedArray storage instead of Dictionary
	var index = _entity_lookup.get(entity_id, -1)
	if index != -1:
		_entity_positions_x[index] = new_pos.x
		_entity_positions_y[index] = new_pos.y

## Get entity data by ID - returns Dictionary for backward compatibility
func get_entity(entity_id: String) -> Dictionary:
	# PHASE 7 OPTIMIZATION: Build Dictionary from PackedArray data for backward compatibility
	var index = _entity_lookup.get(entity_id, -1)
	if index == -1:
		return {}
	
	return {
		"id": _entity_ids[index],
		"type": _entity_types[index],
		"pos": Vector2(_entity_positions_x[index], _entity_positions_y[index]),
		"hp": _entity_hp[index],
		"max_hp": _entity_max_hp[index],
		"alive": _entity_alive[index] == 1
	}

## Check if entity exists and is alive
func is_entity_alive(entity_id: String) -> bool:
	# PHASE 7 OPTIMIZATION: Direct PackedArray access
	var index = _entity_lookup.get(entity_id, -1)
	return index != -1 and _entity_alive[index] == 1

## Get all entities of a specific type
func get_entities_by_type(entity_type: String) -> Array[String]:
	# PHASE 7 OPTIMIZATION: Iterate through PackedArray instead of Dictionary
	var result: Array[String] = []
	for i in range(_entity_count):
		if _entity_types[i] == entity_type and _entity_alive[i] == 1:
			result.append(_entity_ids[i])
	return result

## Get all alive entities
func get_alive_entities() -> Array[String]:
	# PHASE 7 OPTIMIZATION: Iterate through PackedArray instead of Dictionary
	var result: Array[String] = []
	for i in range(_entity_count):
		if _entity_alive[i] == 1:
			result.append(_entity_ids[i])
	return result

## Get all entities within radius of position (spatial query)
## @param center: Center position for search
## @param radius: Search radius in pixels  
## @param filter_types: Optional array of entity types to include (e.g., ["boss", "enemy"])
## @return Array of entity IDs within radius
func get_entities_in_area(center: Vector2, radius: float, filter_types: Array = []) -> Array[String]:
	# PHASE 7 OPTIMIZATION: Iterate through PackedArray instead of Dictionary
	var result: Array[String] = []
	var radius_squared = radius * radius  # Avoid sqrt in distance calculation
	
	for i in range(_entity_count):
		# Skip dead entities
		if _entity_alive[i] == 0:
			continue
			
		# Apply type filter if specified
		if not filter_types.is_empty():
			if not filter_types.has(_entity_types[i]):
				continue
		
		# Distance check using PackedArray data
		var entity_pos = Vector2(_entity_positions_x[i], _entity_positions_y[i])
		var distance_squared = center.distance_squared_to(entity_pos)
		if distance_squared <= radius_squared:
			result.append(_entity_ids[i])
	
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
		# PHASE 7 OPTIMIZATION: Get position from PackedArray instead of Dictionary
		var index = _entity_lookup.get(entity_id, -1)
		if index == -1:
			continue
		var entity_pos = Vector2(_entity_positions_x[index], _entity_positions_y[index])
		
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
			# Emit enemy killed event for XP/loot (direct parameters - no allocation)
			EventBus.enemy_killed.emit(position, 1)
		"boss":
			# Emit enemy killed event for XP/loot (bosses give more XP)
			var boss_xp_value = 50  # Bosses give 50 XP vs regular enemies' 1 XP
			EventBus.enemy_killed.emit(position, boss_xp_value)
			if Logger.is_level_enabled(Logger.LogLevel.INFO):
				Logger.info("Boss defeated: " + entity_id + " (XP: %d)" % boss_xp_value, "combat")
		"player":
			# TODO: Handle player death
			Logger.info("Player defeated!", "combat")
		_:
			if Logger.is_debug():
				Logger.debug("Unknown entity type died: " + entity_type, "combat")
	
	# Clean up: Unregister dead entity to prevent memory leaks
	# Wait a frame to allow any final processing, then cleanup
	await get_tree().process_frame
	var index = _entity_lookup.get(entity_id, -1)
	if index != -1:
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

## PHASE 7: PackedArray-based sync function (replaces _sync_damage_to_game_entity)
func _sync_damage_to_game_entity_packed(entity_id: String, index: int, damage: float, new_hp: float) -> void:
	var entity_type: String = _entity_types[index]
	
	# Create a standardized damage sync payload using PackedArray data
	var sync_payload = {
		"entity_id": entity_id,
		"entity_type": entity_type,
		"damage": damage,
		"new_hp": new_hp,
		"is_death": new_hp <= 0.0
	}
	
	# Emit damage sync event for systems to handle
	EventBus.damage_entity_sync.emit(sync_payload)
	Logger.debug("Emitted damage sync for %s (HP: %.1f)" % [entity_id, new_hp], "combat")

## PHASE 7: PackedArray-based death handling (replaces _handle_entity_death)
func _handle_entity_death_packed(entity_id: String, index: int) -> void:
	var entity_type: String = _entity_types[index]
	var position: Vector2 = Vector2(_entity_positions_x[index], _entity_positions_y[index])
	
	# Emit appropriate death events based on entity type
	match entity_type:
		"enemy":
			# Emit enemy killed event for XP/loot (direct parameters - no allocation)
			EventBus.enemy_killed.emit(position, 1)
		"boss":
			# Emit enemy killed event for XP/loot (bosses give more XP)
			var boss_xp_value = 50  # Bosses give 50 XP vs regular enemies' 1 XP
			EventBus.enemy_killed.emit(position, boss_xp_value)
			if Logger.is_level_enabled(Logger.LogLevel.INFO):
				Logger.info("Boss defeated: " + entity_id + " (XP: %d)" % boss_xp_value, "combat")
		"player":
			# TODO: Handle player death
			Logger.info("Player defeated!", "combat")
		_:
			if Logger.is_debug():
				Logger.debug("Unknown entity type died: " + entity_type, "combat")
	
	# Clean up: Unregister dead entity to prevent memory leaks
	# Wait a frame to allow any final processing, then cleanup
	await get_tree().process_frame
	var lookup_index = _entity_lookup.get(entity_id, -1)
	if lookup_index != -1:
		unregister_entity(entity_id)


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
				if _entity_lookup.get(entity_id, -1) == -1:
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
					if Logger.is_level_enabled(Logger.LogLevel.INFO):
						Logger.info("DEBUG: Registered existing boss: " + entity_id, "combat")
	
	# Register existing enemies from WaveDirector
	var wave_director = get_tree().get_first_node_in_group("wave_directors")
	if wave_director:
		for i in range(wave_director.enemies.size()):
			var enemy = wave_director.enemies[i]
			if enemy.alive:
				# PHASE 4 OPTIMIZATION: Use WaveDirector's pre-generated entity IDs if available
				var entity_id: String
				if wave_director.has_method("get_enemy_entity_id"):
					entity_id = wave_director.get_enemy_entity_id(i)
				else:
					entity_id = "enemy_" + str(i)
				if _entity_lookup.get(entity_id, -1) == -1:
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
					if Logger.is_level_enabled(Logger.LogLevel.INFO):
						Logger.info("DEBUG: Registered existing enemy: " + entity_id, "combat")
	
	if Logger.is_level_enabled(Logger.LogLevel.INFO):
		Logger.info("DEBUG: Registered " + str(registered_count) + " existing entities", "combat")

## Cleanup dead entities to prevent memory leaks
func cleanup_dead_entities() -> void:
	# PHASE 7 OPTIMIZATION: Use PackedArray storage instead of Dictionary iteration
	var cleanup_count = 0
	var entities_to_remove: Array[String] = []
	
	for i in range(_entity_count):
		if _entity_alive[i] == 0:
			entities_to_remove.append(_entity_ids[i])
	
	for entity_id in entities_to_remove:
		unregister_entity(entity_id)
		cleanup_count += 1
	
	if cleanup_count > 0:
		if Logger.is_debug():
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
