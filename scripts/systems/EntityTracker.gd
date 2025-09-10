extends Node

## Entity Tracker - Unified entity registration and spatial queries
## Replaces scene tree traversal with efficient registration-based lookups
## Used by unified damage system to find entities without direct references

# Entity storage: ID -> Dictionary with entity data
var _entities: Dictionary = {}

# Type-indexed storage for O(1) lookups (no per-frame scans)
var _entities_by_type: Dictionary = {} # String -> PackedStringArray

# Spatial indexing for efficient radius queries
var _spatial_grid: Dictionary = {}
const GRID_SIZE: float = 100.0

# Cleanup
var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 5.0

# Signals for entity lifecycle
signal entity_registered(entity_id: String, entity_type: String)
signal entity_unregistered(entity_id: String)

func _ready() -> void:
	Logger.info("EntityTracker initialized", "combat")

func _process(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_dead_entities()
		_cleanup_timer = 0.0

## Register an entity for tracking
## @param id: Unique string identifier
## @param data: Dictionary with "type", "pos", "alive", and other entity data
func register_entity(id: String, data: Dictionary) -> void:
	# RADAR DEBUG: Comprehensive logging to identify mesh enemy registration corruption
	var entity_type: String = data.get("type", "unknown")
	
	# Minimal registration logging
	
	# Validate entity data
	var pos = data.get("pos", Vector2.ZERO)
	var alive = data.get("alive", false)
	var hp = data.get("hp", 0.0)
	
	# Basic validation without spam
	
	# Check for invalid data that might corrupt EntityTracker
	if typeof(pos) != TYPE_VECTOR2:
		Logger.warn("EntityTracker: INVALID POSITION TYPE for %s - expected Vector2, got %s: %s" % [id, typeof(pos), pos], "radar")
		pos = Vector2.ZERO  # Sanitize
		data["pos"] = pos
	
	if typeof(entity_type) != TYPE_STRING or entity_type.is_empty():
		Logger.warn("EntityTracker: INVALID ENTITY TYPE for %s - got %s" % [id, entity_type], "radar")
		entity_type = "unknown"
		data["type"] = entity_type
	
	# Store entity data
	_entities[id] = data
	_update_spatial_index(id, pos)
	
	# Update type index 
	if not _entities_by_type.has(entity_type):
		# Pre-allocate reasonable capacity to avoid frequent resizing during burst spawning
		var new_array = PackedStringArray()
		# Pre-allocate space for common entity types to prevent resize overhead during waves
		if entity_type == "enemy":
			new_array.resize(200)  # Pre-allocate space for 200 enemies
			new_array.resize(0)    # Reset to empty but keep capacity
		elif entity_type == "boss":
			new_array.resize(20)   # Pre-allocate space for 20 bosses
			new_array.resize(0)    # Reset to empty but keep capacity
		_entities_by_type[entity_type] = new_array
	
	# Direct reference to avoid reassignment overhead
	_entities_by_type[entity_type].push_back(id)
	
	entity_registered.emit(id, entity_type)
	

## Batch register multiple entities of the same type (for burst spawning optimization)
## @param entities: Array of dictionaries with entity data (id, type, pos, etc.)
func batch_register_entities(entities: Array) -> void:
	if entities.is_empty():
		return
	
	# Group by entity type for efficient batch processing
	var entities_by_type: Dictionary = {}
	
	for entity_data in entities:
		var entity_id: String = entity_data.get("id", "")
		var entity_type: String = entity_data.get("type", "unknown")
		
		if entity_id.is_empty():
			Logger.warn("EntityTracker: Skipping entity with empty ID in batch registration", "combat")
			continue
		
		# Store individual entity data
		_entities[entity_id] = entity_data
		_update_spatial_index(entity_id, entity_data.get("pos", Vector2.ZERO))
		
		# Group for batch type index update
		if not entities_by_type.has(entity_type):
			entities_by_type[entity_type] = []
		entities_by_type[entity_type].append(entity_id)
	
	# Batch update type indexes to minimize array operations
	for entity_type in entities_by_type.keys():
		var ids: Array = entities_by_type[entity_type]
		
		# Ensure type array exists with pre-allocation
		if not _entities_by_type.has(entity_type):
			var new_array = PackedStringArray()
			# Pre-allocate based on batch size + reasonable buffer
			if entity_type == "enemy":
				new_array.resize(max(200, ids.size() * 2))
				new_array.resize(0)
			elif entity_type == "boss":
				new_array.resize(max(20, ids.size() * 2))
				new_array.resize(0)
			_entities_by_type[entity_type] = new_array
		
		# Batch append all IDs of this type at once
		var type_array: PackedStringArray = _entities_by_type[entity_type]
		for entity_id in ids:
			type_array.push_back(entity_id)
			entity_registered.emit(entity_id, entity_type)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("EntityTracker: Batch registered %d entities across %d types" % [entities.size(), entities_by_type.size()], "combat")

## Unregister an entity
func unregister_entity(id: String) -> void:
	if not _entities.has(id):
		return
		
	var entity_data = _entities[id]
	var entity_type: String = entity_data.get("type", "unknown")
	
	# Remove from type index using swap-remove for O(1) performance
	if _entities_by_type.has(entity_type):
		var type_array: PackedStringArray = _entities_by_type[entity_type]
		var idx: int = -1
		for i in range(type_array.size()):
			if type_array[i] == id:
				idx = i
				break
		
		if idx != -1:
			# Swap-remove: move last element to this position, then resize
			var last_idx: int = type_array.size() - 1
			if idx != last_idx:
				type_array[idx] = type_array[last_idx]
			type_array.resize(last_idx) # Remove the last element
			# Note: No reassignment needed - direct reference modification
		
		# Clean up empty type arrays
		if type_array.is_empty():
			_entities_by_type.erase(entity_type)
	
	_remove_from_spatial_index(id, entity_data.get("pos", Vector2.ZERO))
	_entities.erase(id)
	entity_unregistered.emit(id)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("EntityTracker: Unregistered %s (%s)" % [id, entity_type], "combat")

## Update entity position (important for spatial queries)
func update_entity_position(id: String, new_pos: Vector2) -> void:
	if not _entities.has(id):
		return
		
	var entity_data = _entities[id]
	var old_pos = entity_data.get("pos", Vector2.ZERO)
	
	# Skip update if position hasn't actually changed (prevents unnecessary spatial index churn)
	if old_pos.is_equal_approx(new_pos):
		return
	
	# Update spatial index
	_remove_from_spatial_index(id, old_pos)
	_update_spatial_index(id, new_pos)
	
	# Update entity data
	entity_data["pos"] = new_pos

## BOSS PERFORMANCE V2: Batch update entity positions for zero-allocation processing
## Used by BossUpdateManager to replace individual position updates
## @param ids: PackedStringArray of entity IDs
## @param positions: PackedVector2Array of corresponding positions
func batch_update_positions(ids: PackedStringArray, positions: PackedVector2Array) -> void:
	var count = ids.size()
	if count != positions.size():
		Logger.warn("EntityTracker: batch_update_positions size mismatch - ids:%d positions:%d" % [count, positions.size()], "performance")
		return
	
	for i in range(count):
		var id: String = ids[i]
		var new_pos: Vector2 = positions[i]
		
		if not _entities.has(id):
			continue
			
		var entity_data = _entities[id]
		var old_pos = entity_data.get("pos", Vector2.ZERO)
		
		# Update spatial index
		_remove_from_spatial_index(id, old_pos)
		_update_spatial_index(id, new_pos)
		
		# Update entity data
		entity_data["pos"] = new_pos
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG) and count > 0:
		Logger.debug("EntityTracker: batch updated %d entity positions" % count, "performance")

## Get all entities within radius of position
## @param center: Center position for search
## @param radius: Search radius in pixels
## @param filter_type: Optional entity type filter (e.g., "enemy", "boss")
## @return Array of entity IDs within radius
func get_entities_in_radius(center: Vector2, radius: float, filter_type: String = "") -> Array[String]:
	var result: Array[String] = []
	
	# Use spatial grid for efficient lookup
	var grid_radius = int(ceil(radius / GRID_SIZE))
	var center_grid_x = int(floor(center.x / GRID_SIZE))
	var center_grid_y = int(floor(center.y / GRID_SIZE))
	
	var checked_entities: Dictionary = {}  # Avoid duplicates
	
	# Check surrounding grid cells
	for x in range(center_grid_x - grid_radius, center_grid_x + grid_radius + 1):
		for y in range(center_grid_y - grid_radius, center_grid_y + grid_radius + 1):
			var grid_key = "%d,%d" % [x, y]
			if _spatial_grid.has(grid_key):
				for entity_id in _spatial_grid[grid_key]:
					if checked_entities.has(entity_id):
						continue
					checked_entities[entity_id] = true
					
					if not _entities.has(entity_id):
						continue
					
					var entity_data = _entities[entity_id]
					if not entity_data.get("alive", false):
						continue
					
					# Type filter
					if filter_type != "" and entity_data.get("type", "") != filter_type:
						continue
					
					# Distance check
					var entity_pos = entity_data.get("pos", Vector2.ZERO)
					if center.distance_to(entity_pos) <= radius:
						result.append(entity_id)
	
	return result

## Get entities in cone (for melee attacks)
## @param apex: Cone apex position
## @param direction: Cone direction (normalized vector)
## @param angle_degrees: Cone angle in degrees
## @param max_range: Maximum range
## @param filter_type: Optional entity type filter
## @return Array of entity IDs in cone
func get_entities_in_cone(apex: Vector2, direction: Vector2, angle_degrees: float, max_range: float, filter_type: String = "") -> Array[String]:
	var entities_in_range = get_entities_in_radius(apex, max_range, filter_type)
	var result: Array[String] = []
	
	var cone_radians = deg_to_rad(angle_degrees)
	var min_dot = cos(cone_radians / 2.0)
	
	for entity_id in entities_in_range:
		var entity_data = _entities[entity_id]
		var entity_pos = entity_data.get("pos", Vector2.ZERO)
		
		# Check if in cone angle
		var to_entity = (entity_pos - apex).normalized()
		var dot_product = to_entity.dot(direction)
		
		if dot_product >= min_dot:
			result.append(entity_id)
	
	return result

## Get entity data by ID
func get_entity(entity_id: String) -> Dictionary:
	return _entities.get(entity_id, {})

## Check if entity exists and is alive
func is_entity_alive(entity_id: String) -> bool:
	var entity_data = _entities.get(entity_id, {})
	return entity_data.get("alive", false)

## Get all entities of a specific type (PERFORMANCE NOTE: O(N) scan - use get_entities_by_type_view() for better performance)
func get_entities_by_type(entity_type: String) -> Array[String]:
	var result: Array[String] = []
	for id in _entities.keys():
		var entity_data = _entities[id]
		if entity_data.get("type", "") == entity_type and entity_data.get("alive", false):
			result.append(id)
	return result

## Read-only view: return internal array by reference (do not mutate)
## RADAR PERFORMANCE V3: O(1) type-indexed lookup - no scanning, no copying
func get_entities_by_type_view(entity_type: String) -> PackedStringArray:
	# Check if the type exists in our index
	if not _entities_by_type.has(entity_type):
		return PackedStringArray()
	
	var result = _entities_by_type[entity_type]
	return result

## Fill positions for the given ids into out_positions without allocations
## RADAR PERFORMANCE V3: Zero-allocation position fetching for batched processing
func get_positions_for(ids: PackedStringArray, out_positions: PackedVector2Array) -> void:
	out_positions.resize(0)
	
	for i in range(ids.size()):
		var id: String = ids[i]
		var entity_data = _entities.get(id)
		if entity_data:
			var pos = entity_data.get("pos", Vector2.ZERO)
			out_positions.push_back(pos)
		else:
			# Handle missing entities gracefully - push zero position
			out_positions.push_back(Vector2.ZERO)
			Logger.debug("EntityTracker: Entity %s NOT FOUND - using Vector2.ZERO" % id, "radar")

## Get all alive entities
func get_alive_entities() -> Array[String]:
	var result: Array[String] = []
	for id in _entities.keys():
		var entity_data = _entities[id]
		if entity_data.get("alive", false):
			result.append(id)
	return result

## Update spatial index for entity
func _update_spatial_index(entity_id: String, pos: Vector2) -> void:
	var grid_x = int(floor(pos.x / GRID_SIZE))
	var grid_y = int(floor(pos.y / GRID_SIZE))
	var grid_key = "%d,%d" % [grid_x, grid_y]
	
	if not _spatial_grid.has(grid_key):
		_spatial_grid[grid_key] = []
	
	if not _spatial_grid[grid_key].has(entity_id):
		_spatial_grid[grid_key].append(entity_id)

## Remove entity from spatial index
func _remove_from_spatial_index(entity_id: String, pos: Vector2) -> void:
	var grid_x = int(floor(pos.x / GRID_SIZE))
	var grid_y = int(floor(pos.y / GRID_SIZE))
	var grid_key = "%d,%d" % [grid_x, grid_y]
	
	if _spatial_grid.has(grid_key):
		var grid_entities = _spatial_grid[grid_key]
		var index = grid_entities.find(entity_id)
		if index != -1:
			grid_entities.remove_at(index)
		
		# Clean up empty grid cells
		if grid_entities.is_empty():
			_spatial_grid.erase(grid_key)

## Cleanup dead entities periodically
func cleanup_dead_entities() -> void:
	var entities_to_remove: Array[String] = []
	
	for entity_id in _entities.keys():
		var entity_data = _entities[entity_id]
		if not entity_data.get("alive", false):
			entities_to_remove.append(entity_id)
	
	for entity_id in entities_to_remove:
		unregister_entity(entity_id)
	
	if entities_to_remove.size() > 0:
		Logger.debug("EntityTracker: Cleaned up %d dead entities" % [entities_to_remove.size()], "combat")

## DEBUG: Get debug info about tracked entities
func get_debug_info() -> Dictionary:
	var alive_count = 0
	var types: Dictionary = {}
	
	for entity_data in _entities.values():
		if entity_data.get("alive", false):
			alive_count += 1
			var entity_type = entity_data.get("type", "unknown")
			types[entity_type] = types.get(entity_type, 0) + 1
	
	return {
		"total_entities": _entities.size(),
		"alive_entities": alive_count,
		"types": types,
		"spatial_grid_cells": _spatial_grid.size()
	}

## Clear entities of specific group/type (for scene transitions)
func clear(entity_type: String) -> void:
	"""Clear all entities of specified type - used during scene transitions"""
	var entities_to_remove: Array[String] = []
	
	# Find entities to remove
	for entity_id in _entities.keys():
		var entity_data = _entities[entity_id]
		if entity_data.get("type", "") == entity_type:
			entities_to_remove.append(entity_id)
	
	# Remove them
	for entity_id in entities_to_remove:
		unregister_entity(entity_id)
	
	if entities_to_remove.size() > 0:
		Logger.info("EntityTracker: Cleared %d entities of type '%s'" % [entities_to_remove.size(), entity_type], "combat")

## Reset EntityTracker completely (for scene transitions)
func reset() -> void:
	"""Reset all EntityTracker state - use during scene transitions"""
	var entity_count = _entities.size()
	
	# Clear all entities and indexes
	_entities.clear()
	_entities_by_type.clear()
	_spatial_grid.clear()
	
	# Reset cleanup timer
	_cleanup_timer = 0.0
	
	if entity_count > 0:
		Logger.info("EntityTracker: Reset complete - cleared %d entities" % entity_count, "combat")
