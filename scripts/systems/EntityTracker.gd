extends Node

## Entity Tracker - Unified entity registration and spatial queries
## Replaces scene tree traversal with efficient registration-based lookups
## Used by unified damage system to find entities without direct references

# Entity storage: ID -> Dictionary with entity data
var _entities: Dictionary = {}

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
	_entities[id] = data
	_update_spatial_index(id, data.get("pos", Vector2.ZERO))
	entity_registered.emit(id, data.get("type", "unknown"))
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("EntityTracker: Registered %s (%s) at %s" % [id, data.get("type", "unknown"), data.get("pos", Vector2.ZERO)], "combat")

## Unregister an entity
func unregister_entity(id: String) -> void:
	if _entities.has(id):
		var entity_data = _entities[id]
		_remove_from_spatial_index(id, entity_data.get("pos", Vector2.ZERO))
		_entities.erase(id)
		entity_unregistered.emit(id)
		
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("EntityTracker: Unregistered %s" % [id], "combat")

## Update entity position (important for spatial queries)
func update_entity_position(id: String, new_pos: Vector2) -> void:
	if not _entities.has(id):
		return
		
	var entity_data = _entities[id]
	var old_pos = entity_data.get("pos", Vector2.ZERO)
	
	# Update spatial index
	_remove_from_spatial_index(id, old_pos)
	_update_spatial_index(id, new_pos)
	
	# Update entity data
	entity_data["pos"] = new_pos

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
			var grid_key = str(x) + "," + str(y)
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

## Get all entities of a specific type
func get_entities_by_type(entity_type: String) -> Array[String]:
	var result: Array[String] = []
	for id in _entities.keys():
		var entity_data = _entities[id]
		if entity_data.get("type", "") == entity_type and entity_data.get("alive", false):
			result.append(id)
	return result

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
	var grid_key = str(grid_x) + "," + str(grid_y)
	
	if not _spatial_grid.has(grid_key):
		_spatial_grid[grid_key] = []
	
	if not _spatial_grid[grid_key].has(entity_id):
		_spatial_grid[grid_key].append(entity_id)

## Remove entity from spatial index
func _remove_from_spatial_index(entity_id: String, pos: Vector2) -> void:
	var grid_x = int(floor(pos.x / GRID_SIZE))
	var grid_y = int(floor(pos.y / GRID_SIZE))
	var grid_key = str(grid_x) + "," + str(grid_y)
	
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