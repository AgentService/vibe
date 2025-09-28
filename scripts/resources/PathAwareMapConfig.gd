class_name PathAwareMapConfig
extends MapConfig

## PathAware extension of MapConfig for generated arenas
## Provides path-aware spawning capabilities while maintaining compatibility with traditional spawn zones
## Clean separation: PathAwareMapConfig for generated arenas, MapConfig for handmade arenas

@export_group("Path-Aware Configuration")
## Snapshot of generated path data for consumption by spawning systems
@export var path_snapshot: PathAwarePathSnapshot

## Configuration profiles for different spawn system behaviors
@export var spawn_profiles: Array[PathSpawnProfile] = []

## Seed used for arena generation (for reproducibility)
@export var generation_seed: int = 0

## Whether to automatically optimize spawns using path data (true) or use manual zones (false)
@export var auto_optimize_spawns: bool = true

## Get effective spawn zones - either from path analysis or manual zones
func get_effective_spawn_zones() -> Array[SpawnZone]:
	if path_snapshot and auto_optimize_spawns:
		return _generate_zones_from_paths()
	else:
		# Fall back to manual zones from base MapConfig
		return _convert_legacy_spawn_zones()

## Generate spawn zones from path data
func _generate_zones_from_paths() -> Array[SpawnZone]:
	if not path_snapshot:
		Logger.warn("PathAwareMapConfig: No path snapshot available for zone generation", "pathspawn")
		return []

	var zones: Array[SpawnZone] = []

	# Generate spawn zones for each category
	for category in PathSpawnProfile.PathSpawnCategory.values():
		var positions = _get_spawn_positions_for_category(category)
		if not positions.is_empty():
			var zone = _create_spawn_zone_for_category(category, positions)
			zones.append(zone)

	Logger.debug("Generated %d spawn zones from path data" % zones.size(), "pathspawn")
	return zones

## Get spawn positions for a specific category from path snapshot
func _get_spawn_positions_for_category(category: PathSpawnProfile.PathSpawnCategory) -> Array[Vector2]:
	if not path_snapshot:
		return []

	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return _sample_positions_along_path(path_snapshot.main_path_points, 64.0)
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return _sample_positions_along_branches()
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return path_snapshot.endpoint_positions.duplicate()
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return _get_clearing_positions()
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return _get_around_path_positions()
		_:
			return []

## Sample positions along a path with specified spacing
func _sample_positions_along_path(path_points: Array[Vector2], spacing: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if path_points.size() < 2:
		return positions

	for i in range(path_points.size() - 1):
		var start = path_points[i]
		var end = path_points[i + 1]
		var segment_length = start.distance_to(end)
		var steps = int(segment_length / spacing)

		for j in range(steps):
			var t = float(j) / float(steps)
			var position = start.lerp(end, t)
			positions.append(position)

	return positions

## Sample positions along branch paths
func _sample_positions_along_branches() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not path_snapshot or path_snapshot.branch_data.is_empty():
		return positions

	for branch_info in path_snapshot.branch_data:
		if branch_info.points.size() > 0:
			var branch_positions = _sample_positions_along_path(branch_info.points, 64.0)
			positions.append_array(branch_positions)

	return positions

## Get positions in clearing areas
func _get_clearing_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not path_snapshot or path_snapshot.clearings.is_empty():
		return positions

	for clearing in path_snapshot.clearings:
		# Sample positions within clearing radius
		var center = clearing.center
		var radius = clearing.radius * 0.7  # Use 70% of radius for safety

		# Generate positions in a circle pattern
		var point_count = int(radius / 32.0)  # One point per 32 units
		for i in range(point_count):
			var angle = TAU * float(i) / float(point_count)
			var offset = Vector2(cos(angle), sin(angle)) * radius * randf_range(0.3, 0.9)
			positions.append(center + offset)

	return positions

## Get positions around paths (buffer zones)
func _get_around_path_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not path_snapshot or path_snapshot.path_corridors.is_empty():
		return positions

	for corridor in path_snapshot.path_corridors:
		if corridor.center_line.size() > 0:
			var center_line: Array[Vector2] = corridor.center_line
			var buffer_distance = corridor.width * 0.75  # Position outside corridor but not too far

			positions.append_array(_sample_positions_around_line(center_line, buffer_distance))

	return positions

## Sample positions around a line with specified buffer distance
func _sample_positions_around_line(line_points: Array[Vector2], buffer_distance: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if line_points.size() < 2:
		return positions

	for i in range(line_points.size() - 1):
		var start = line_points[i]
		var end = line_points[i + 1]
		var direction = (end - start).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)

		# Sample along both sides of the line
		var segment_length = start.distance_to(end)
		var steps = int(segment_length / 48.0)  # One sample per 48 units

		for j in range(steps):
			var t = float(j) / float(steps)
			var point_on_line = start.lerp(end, t)

			# Add positions on both sides
			positions.append(point_on_line + perpendicular * buffer_distance)
			positions.append(point_on_line - perpendicular * buffer_distance)

	return positions

## Create a spawn zone for a specific category
func _create_spawn_zone_for_category(category: PathSpawnProfile.PathSpawnCategory, positions: Array[Vector2]) -> SpawnZone:
	var zone = SpawnZone.new()
	zone.category = category
	zone.positions = positions
	zone.weight = _get_category_weight(category)
	zone.name = _get_category_name(category)
	return zone

## Get weight for spawn category (can be overridden by spawn profiles)
func _get_category_weight(category: PathSpawnProfile.PathSpawnCategory) -> float:
	# Check spawn profiles for category weight
	for profile in spawn_profiles:
		if profile.spawn_categories.has(category):
			return profile.priority_weight

	# Default weights by category
	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return 1.0
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return 0.8
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return 1.5  # Higher weight for endpoints (good for bosses)
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return 1.2
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return 0.6
		_:
			return 1.0

## Get human-readable name for spawn category
func _get_category_name(category: PathSpawnProfile.PathSpawnCategory) -> String:
	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return "MainPath"
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return "Branches"
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return "Endpoints"
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return "Clearings"
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return "AroundPaths"
		_:
			return "Unknown"

## Convert legacy spawn zone dictionaries to SpawnZone objects for compatibility
func _convert_legacy_spawn_zones() -> Array[SpawnZone]:
	var zones: Array[SpawnZone] = []

	for zone_dict in spawn_zones:
		var zone = SpawnZone.new()
		zone.name = zone_dict.get("name", "")
		zone.weight = zone_dict.get("weight", 1.0)

		# Convert single position to position array
		var position = zone_dict.get("position", Vector2.ZERO)
		var radius = zone_dict.get("radius", 50.0)
		zone.positions = [position]  # Simple conversion for now

		zones.append(zone)

	return zones

## Get spawn profile by system name
func get_spawn_profile(system_name: String) -> PathSpawnProfile:
	for profile in spawn_profiles:
		if profile.system_name == system_name:
			return profile
	return null

## Check if path-aware spawning is enabled
func is_path_aware_spawning_enabled() -> bool:
	return path_snapshot != null and auto_optimize_spawns

## Get total spawn area bounds
func get_spawn_area_bounds() -> Rect2:
	if path_snapshot:
		return path_snapshot.total_arena_bounds
	else:
		# Fallback to traditional bounds
		var radius = spawn_radius if spawn_radius > 0 else arena_bounds_radius
		return Rect2(-radius, -radius, radius * 2, radius * 2)

## Validate PathAware configuration
func is_path_aware_valid() -> bool:
	if not is_path_aware_spawning_enabled():
		return true  # Traditional mode, base validation applies

	if not path_snapshot:
		Logger.warn("PathAwareMapConfig: path_snapshot is null but auto_optimize_spawns is true", "pathspawn")
		return false

	if path_snapshot.main_path_points.is_empty():
		Logger.warn("PathAwareMapConfig: path_snapshot has no main path points", "pathspawn")
		return false

	return true

## Override base validation to include path-aware checks
func is_valid() -> bool:
	return super.is_valid() and is_path_aware_valid()

# Forward declare SpawnZone and related types (these will be created later)
class SpawnZone:
	var name: String
	var category: PathSpawnProfile.PathSpawnCategory
	var positions: Array[Vector2] = []
	var weight: float = 1.0