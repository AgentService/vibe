extends RefCounted
class_name PathSnapshotAnalyzer

## Dedicated analyzer for creating PathAwarePathSnapshot from generated path data
## Extracted from PathAwareArenaGenerator to reduce complexity and improve maintainability

## Create a comprehensive path snapshot for spawning systems
func create_snapshot(path_data: Dictionary, tree_data: Array[Vector2], seed: int) -> PathAwarePathSnapshot:
	var snapshot = PathAwarePathSnapshot.new()

	# Core path data
	snapshot.main_path_points = path_data.get("points", [])
	snapshot.branch_data = _extract_branch_info(path_data)
	snapshot.connection_points = path_data.get("connections", [])

	# Derived spatial analysis
	snapshot.path_corridors = _calculate_corridors(path_data)
	snapshot.clearings = _detect_clearings(path_data)
	snapshot.boundary_zones = _analyze_boundaries(tree_data)
	snapshot.endpoint_positions = _identify_endpoints(path_data)
	snapshot.checkpoint_positions = _generate_checkpoints(path_data)

	# Metadata
	snapshot.total_arena_bounds = _calculate_arena_bounds(path_data, tree_data)
	snapshot.generation_seed = seed
	snapshot.generation_timestamp = Time.get_ticks_msec()

	Logger.debug("Created path snapshot: %s" % snapshot.get_debug_summary(), "pathgen")
	return snapshot

## Extract branch information from current path data
func _extract_branch_info(path_data: Dictionary) -> Array[PathAwarePathSnapshot.PathBranchInfo]:
	var branches: Array[PathAwarePathSnapshot.PathBranchInfo] = []
	var paths: Array = path_data.get("paths", [])

	for i in range(paths.size()):
		var path = paths[i]
		var branch = PathAwarePathSnapshot.PathBranchInfo.new(i)

		if path.has_method("get_full_path"):
			branch.points = path.get_full_path()
			branch.calculate_length()

		# Determine branch type based on path structure
		# More intelligent detection: actual branches are typically the last few paths
		# Main path segments are usually the first several paths in sequence
		var total_paths = paths.size()
		var branch_count = path_data.get("branch_count", 0)
		var main_segment_count = total_paths - branch_count

		if i < main_segment_count:
			branch.branch_type = "main"
		else:
			branch.branch_type = "branch"

		# Set parent connection point (first point of the branch)
		if not branch.points.is_empty():
			branch.parent_connection_point = branch.points[0]

		branches.append(branch)

	return branches

## Calculate path corridors with width information
func _calculate_corridors(path_data: Dictionary) -> Array[PathAwarePathSnapshot.PathCorridor]:
	var corridors: Array[PathAwarePathSnapshot.PathCorridor] = []
	var paths: Array = path_data.get("paths", [])

	for i in range(paths.size()):
		var path = paths[i]
		var corridor = PathAwarePathSnapshot.PathCorridor.new()

		if path.has_method("get_full_path"):
			corridor.center_line = path.get_full_path()
			corridor.width = 64.0  # Default corridor width
			corridor.corridor_type = "main" if i == 0 else "branch"
			corridor.calculate_bounds()
			corridors.append(corridor)

	return corridors

## Detect clearing areas between paths and boundaries
func _detect_clearings(path_data: Dictionary) -> Array[PathAwarePathSnapshot.PathClearing]:
	var clearings: Array[PathAwarePathSnapshot.PathClearing] = []
	var paths: Array = path_data.get("paths", [])

	# Simple clearing detection: create clearings at path intersections and endpoints
	var all_points: Array = path_data.get("points", [])

	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue

		# Check if this point is an intersection or endpoint
		var connections = _count_connections_at_point(position, path_data)

		if connections >= 2:  # Intersection
			var clearing = PathAwarePathSnapshot.PathClearing.new(position, 80.0)
			clearing.clearing_type = "intersection"
			clearing.spawn_priority = 1.5
			clearings.append(clearing)
		elif connections == 1:  # Endpoint
			var clearing = PathAwarePathSnapshot.PathClearing.new(position, 60.0)
			clearing.clearing_type = "endpoint"
			clearing.spawn_priority = 2.0
			clearings.append(clearing)

	# Add natural clearings between paths
	_add_natural_clearings(clearings, all_points, path_data)

	Logger.debug("Detected %d clearings" % clearings.size(), "pathgen")
	return clearings

## Add natural clearings in open areas
func _add_natural_clearings(clearings: Array[PathAwarePathSnapshot.PathClearing], path_points: Array, path_data: Dictionary) -> void:
	# Create a grid to find open areas
	var grid_size = 100
	var bounds = _calculate_arena_bounds(path_data, [])

	for x in range(int(bounds.position.x), int(bounds.position.x + bounds.size.x), grid_size):
		for y in range(int(bounds.position.y), int(bounds.position.y + bounds.size.y), grid_size):
			var test_point = Vector2(x, y)

			# Check if this point is far enough from paths and trees
			if _is_suitable_for_clearing(test_point, path_data, []):
				var clearing = PathAwarePathSnapshot.PathClearing.new(test_point, 50.0)
				clearing.clearing_type = "natural"
				clearing.spawn_priority = 1.0
				clearings.append(clearing)

## Check if a point is suitable for a natural clearing
func _is_suitable_for_clearing(point: Vector2, path_data: Dictionary, tree_data: Array[Vector2]) -> bool:
	var min_distance_to_path = 80.0
	var min_distance_to_tree = 60.0

	# Check distance to paths
	var nearest_path_distance = _get_distance_to_nearest_path_point(point, path_data)
	if nearest_path_distance < min_distance_to_path:
		return false

	# Check distance to trees
	for tree_pos in tree_data:
		if point.distance_to(tree_pos) < min_distance_to_tree:
			return false

	return true

## Get distance to nearest path point
func _get_distance_to_nearest_path_point(point: Vector2, path_data: Dictionary) -> float:
	var min_distance = float('inf')
	var all_points: Array = path_data.get("points", [])

	for path_point in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not path_point is Vector2:
			continue

		var distance = point.distance_to(path_point)
		if distance < min_distance:
			min_distance = distance

	return min_distance if min_distance != float('inf') else 1000.0

## Count how many path connections exist at a specific point
func _count_connections_at_point(point: Vector2, path_data: Dictionary, tolerance: float = 20.0) -> int:
	var connection_count = 0
	var paths: Array = path_data.get("paths", [])

	for path in paths:
		if path.has_method("get_full_path"):
			var path_points = path.get_full_path()
			for path_point in path_points:
				if point.distance_to(path_point) <= tolerance:
					connection_count += 1
					break  # Only count each path once

	return connection_count

## Analyze boundary zones from tree data
func _analyze_boundaries(tree_data: Array[Vector2]) -> Array[PathAwarePathSnapshot.PathBoundaryZone]:
	var boundaries: Array[PathAwarePathSnapshot.PathBoundaryZone] = []

	for tree_pos in tree_data:
		var boundary = PathAwarePathSnapshot.PathBoundaryZone.new(tree_pos, 32.0)
		boundary.zone_type = "tree"
		boundary.avoidance_priority = 1.0
		boundaries.append(boundary)

	Logger.debug("Analyzed %d boundary zones" % boundaries.size(), "pathgen")
	return boundaries

## Identify endpoint positions for boss spawns
func _identify_endpoints(path_data: Dictionary) -> Array[Vector2]:
	var endpoints: Array[Vector2] = []
	var all_points: Array = path_data.get("points", [])

	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue

		# A point is an endpoint if it has exactly one connection
		if _count_connections_at_point(position, path_data) == 1:
			endpoints.append(position)

	Logger.debug("Identified %d endpoints" % endpoints.size(), "pathgen")
	return endpoints

## Generate checkpoint positions along paths
func _generate_checkpoints(path_data: Dictionary) -> Array[Vector2]:
	var checkpoints: Array[Vector2] = []
	var paths: Array = path_data.get("paths", [])
	var checkpoint_spacing = 120.0  # Distance between checkpoints

	for path in paths:
		if path.has_method("get_full_path"):
			var path_points = path.get_full_path()
			var current_distance = 0.0

			for i in range(path_points.size() - 1):
				var start = path_points[i]
				var end = path_points[i + 1]
				var segment_length = start.distance_to(end)

				# Add checkpoints along this segment
				while current_distance + checkpoint_spacing < segment_length:
					current_distance += checkpoint_spacing
					var t = current_distance / segment_length
					var checkpoint = start.lerp(end, t)
					checkpoints.append(checkpoint)

				current_distance += segment_length - current_distance

	Logger.debug("Generated %d checkpoints" % checkpoints.size(), "pathgen")
	return checkpoints

## Calculate total arena bounds
func _calculate_arena_bounds(path_data: Dictionary, tree_data: Array[Vector2], fallback_radius: float = 600.0) -> Rect2:
	var all_positions: Array[Vector2] = []

	# Include path points
	var all_points: Array = path_data.get("points", [])
	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue
		all_positions.append(position)

	# Include tree positions
	all_positions.append_array(tree_data)

	if all_positions.is_empty():
		return Rect2(-fallback_radius, -fallback_radius, fallback_radius * 2, fallback_radius * 2)

	# Find min/max positions
	var min_pos = all_positions[0]
	var max_pos = all_positions[0]

	for pos in all_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	# Add padding
	var padding = 100.0
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)

	var bounds = Rect2(min_pos, max_pos - min_pos)
	Logger.debug("Calculated arena bounds: %s" % bounds, "pathgen")
	return bounds