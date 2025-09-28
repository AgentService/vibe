class_name PathAwareMapConfig
extends MapConfig

## PathAware extension of MapConfig for generated arenas
## Provides path-aware spawning capabilities while maintaining compatibility with traditional spawn zones
## Clean separation: PathAwareMapConfig for generated arenas, MapConfig for handmade arenas

@export_group("Path-Aware Configuration")
## Snapshot of generated path data for consumption by spawning systems
@export var path_snapshot: PathAwarePathSnapshot

## Configuration profiles for different spawn system behaviors
@export var spawn_profiles: Array = []

## Seed used for arena generation (for reproducibility)
@export var generation_seed: int = 0

## Whether to automatically optimize spawns using path data (true) or use manual zones (false)
@export var auto_optimize_spawns: bool = true

## Get effective spawn zones - either from path analysis or manual zones
func get_effective_spawn_zones() -> Array:
	if path_snapshot and auto_optimize_spawns:
		return _generate_zones_from_paths()
	else:
		# Fall back to manual zones from base MapConfig
		return _convert_legacy_spawn_zones()

## Generate spawn zones from path data
func _generate_zones_from_paths() -> Array:
	if not path_snapshot:
		Logger.warn("PathAwareMapConfig: No path snapshot available for zone generation", "pathspawn")
		return []

	var zones: Array = []

	# Generate spawn zones for each category
	for category in PathSpawnProfile.PathSpawnCategory.values():
		var positions = _get_spawn_positions_for_category(category)
		if not positions.is_empty():
			var zone = _create_spawn_zone_for_category(category, positions)
			zones.append(zone)

	Logger.debug("Generated %d spawn zones from path data" % zones.size(), "pathspawn")
	return zones

## Get spawn positions for a specific category from path snapshot
func _get_spawn_positions_for_category(category: PathSpawnProfile.PathSpawnCategory) -> Array:
	if not path_snapshot:
		return []

	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return _sample_positions_along_path(path_snapshot.main_path_points, 64.0)
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return _sample_positions_along_branches()
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return path_snapshot.endpoint_positions.duplicate()
		PathSpawnProfile.PathSpawnCategory.AT_BRANCH_ENDPOINTS:
			return _get_branch_endpoint_positions()
		PathSpawnProfile.PathSpawnCategory.MAIN_CHECKPOINTS:
			return _get_main_checkpoint_positions()
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return _get_clearing_positions()
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return _get_around_path_positions()
		_:
			return []

## Sample positions along a path with specified spacing
func _sample_positions_along_path(path_points: Array, spacing: float) -> Array:
	var positions: Array = []

	if path_points.size() < 2:
		return positions

	# Convert PathPoints to Vector2 if needed
	var vector_points = _convert_to_vector2_array(path_points)

	for i in range(vector_points.size() - 1):
		var start: Vector2 = vector_points[i]
		var end: Vector2 = vector_points[i + 1]
		var segment_length = start.distance_to(end)
		var steps = int(segment_length / spacing)

		for j in range(steps):
			var t = float(j) / float(steps)
			var position = start.lerp(end, t)
			positions.append(position)

	return positions

## Convert PathPoint objects to Vector2 array
func _convert_to_vector2_array(path_points: Array) -> Array:
	var vector_points: Array = []
	for point in path_points:
		if point is Vector2:
			vector_points.append(point)
		elif point != null and point.get("position") != null:
			vector_points.append(point.position)
	return vector_points

## Sample positions along branch paths (exclude main path spine segments)
func _sample_positions_along_branches() -> Array:
	var positions: Array = []

	if not path_snapshot or path_snapshot.branch_data.is_empty():
		return positions

	# Process only true branch extensions, not main path segments
	# A branch is considered a "true branch" if it extends from a main path point
	# but doesn't connect to the next main path point in sequence
	var main_path_positions = _convert_to_vector2_array(path_snapshot.main_path_points)

	for i in range(path_snapshot.branch_data.size()):
		var branch_info = path_snapshot.branch_data[i]

		if branch_info.points.size() > 1:  # Need at least 2 points to interpolate
			# Check if this is a main path segment by seeing if it connects consecutive main points
			var is_main_path_segment = _is_main_path_segment(branch_info, main_path_positions)

			if not is_main_path_segment:
				var branch_positions = _sample_positions_along_path(branch_info.points, 64.0)
				positions.append_array(branch_positions)

	return positions

## Check if a branch represents a main path segment (connecting consecutive main points)
func _is_main_path_segment(branch_info, main_path_positions: Array) -> bool:
	if branch_info.points.size() < 2 or main_path_positions.size() < 2:
		return false

	var branch_start = branch_info.points[0]
	var branch_start_pos = branch_start if branch_start is Vector2 else branch_start.position
	var branch_end = branch_info.points[-1]
	var branch_end_pos = branch_end if branch_end is Vector2 else branch_end.position

	# Check if this branch connects two consecutive main path points
	for i in range(main_path_positions.size() - 1):
		var main_point_a = main_path_positions[i]
		var main_point_b = main_path_positions[i + 1]

		# Check if branch connects these two main points (in either direction)
		var connects_a_to_b = (branch_start_pos.distance_to(main_point_a) < 20.0 and
							   branch_end_pos.distance_to(main_point_b) < 20.0)
		var connects_b_to_a = (branch_start_pos.distance_to(main_point_b) < 20.0 and
							   branch_end_pos.distance_to(main_point_a) < 20.0)

		if connects_a_to_b or connects_b_to_a:
			return true

	return false

## Get positions in clearing areas
func _get_clearing_positions() -> Array:
	var positions: Array = []

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
func _get_around_path_positions() -> Array:
	var positions: Array = []

	if not path_snapshot or path_snapshot.path_corridors.is_empty():
		return positions

	for corridor in path_snapshot.path_corridors:
		if corridor.center_line.size() > 0:
			var center_line: Array = corridor.center_line
			var buffer_distance = corridor.width * 0.75  # Position outside corridor but not too far

			positions.append_array(_sample_positions_around_line(center_line, buffer_distance))

	return positions

## Sample positions around a line with specified buffer distance
func _sample_positions_around_line(line_points: Array, buffer_distance: float) -> Array:
	var positions: Array = []

	if line_points.size() < 2:
		return positions

	# Convert PathPoints to Vector2 if needed
	var vector_points = _convert_to_vector2_array(line_points)

	for i in range(vector_points.size() - 1):
		var start: Vector2 = vector_points[i]
		var end: Vector2 = vector_points[i + 1]
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

## Get main path checkpoint positions (strategic waypoints)
func _get_main_checkpoint_positions() -> Array:
	var positions: Array = []

	if not path_snapshot or path_snapshot.main_path_points.is_empty():
		return positions

	# Convert PathPoints to Vector2 and skip the first point (START point)
	var vector_points = _convert_to_vector2_array(path_snapshot.main_path_points)

	# Skip index 0 (START point) - strategic checkpoints start from index 1
	for i in range(1, vector_points.size()):
		positions.append(vector_points[i])

	return positions

## Get branch endpoint positions (branch terminus points - may overlap with checkpoints)
func _get_branch_endpoint_positions() -> Array:
	var positions: Array = []

	if not path_snapshot or path_snapshot.main_path_points.is_empty() or path_snapshot.branch_data.is_empty():
		return positions

	# Find all branch endpoints by tracing from checkpoint positions
	# Red triangles indicate branch start/end points for additional spawn targeting
	var main_path_positions = _convert_to_vector2_array(path_snapshot.main_path_points)

	for i in range(path_snapshot.main_path_points.size()):
		var main_point = path_snapshot.main_path_points[i]
		var main_pos = main_point if main_point is Vector2 else main_point.position

		# Find branches that originate from this checkpoint
		for branch_info in path_snapshot.branch_data:
			if branch_info.points.size() > 0:
				var branch_start = branch_info.points[0]
				var branch_start_pos = branch_start if branch_start is Vector2 else branch_start.position
				var distance = main_pos.distance_to(branch_start_pos)

				# If this branch starts near this checkpoint, collect its endpoint
				if distance < 50.0:  # Close enough to be connected
					# Skip main path segments - only collect true branch endpoints
					var is_main_path_segment = _is_main_path_segment(branch_info, main_path_positions)

					if not is_main_path_segment:
						var branch_end = branch_info.points[-1]
						var branch_end_pos = branch_end if branch_end is Vector2 else branch_end.position

						# Only add unique endpoints (avoid duplicates)
						var is_duplicate = false
						for existing_pos in positions:
							if existing_pos.distance_to(branch_end_pos) < 10.0:
								is_duplicate = true
								break

						if not is_duplicate:
							positions.append(branch_end_pos)

	return positions

## Create a spawn zone for a specific category
func _create_spawn_zone_for_category(category: PathSpawnProfile.PathSpawnCategory, positions: Array) -> SpawnZone:
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
		PathSpawnProfile.PathSpawnCategory.AT_BRANCH_ENDPOINTS:
			return 1.3  # Specialized branch termination points
		PathSpawnProfile.PathSpawnCategory.MAIN_CHECKPOINTS:
			return 2.0  # Highest weight for strategic checkpoint spawning
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
		PathSpawnProfile.PathSpawnCategory.AT_BRANCH_ENDPOINTS:
			return "BranchEndpoints"
		PathSpawnProfile.PathSpawnCategory.MAIN_CHECKPOINTS:
			return "MainCheckpoints"
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return "Clearings"
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return "AroundPaths"
		_:
			return "Unknown"

## Convert legacy spawn zone dictionaries to SpawnZone objects for compatibility
func _convert_legacy_spawn_zones() -> Array:
	var zones: Array = []

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
	var positions: Array = []
	var weight: float = 1.0
