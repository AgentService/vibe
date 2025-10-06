@tool
class_name PathConfiguration
extends Resource

## Path-only configuration for dungeon-style walkable path generation
## Focused solely on creating navigable routes between connection points

@export_group("Path Network Setup")
## Enable path generation system
@export var enable_path_generation: bool = true

## Number of connection points for path network (configurable chain length)
@export_range(2, 10, 1) var connection_points: int = 2

## Chain length for the outward path (how many points in sequence)
@export_range(2, 10, 1) var chain_length: int = 4

## Minimum distance between connection points (pixels)
@export_range(50, 500, 10) var min_point_distance: float = 80.0

# path_extension_width parameter removed

@export_group("Path Properties")
## Path corridor width for navigation (pixels)
@export_range(32, 128, 8) var path_width: float = 64.0

## Smoothing factor for path curves (0=angular, 1=smooth)
@export_range(0.0, 1.0, 0.1) var path_smoothing: float = 0.4

@export_group("Natural Path Variation")
## Add randomness to path routing for organic feel
@export var enable_path_variation: bool = true

## Maximum angle variation for path segments (degrees)
@export_range(10, 45, 5) var max_path_variation: float = 20.0

## Add intermediate waypoints for more natural paths
@export var add_intermediate_waypoints: bool = true

## Probability of adding waypoints (0.0-1.0)
@export_range(0.0, 1.0, 0.1) var waypoint_probability: float = 0.6

@export_group("Dynamic Branching System")
## Enable dynamic branch generation at chain points
@export var enable_dynamic_branching: bool = true

## Probability each eligible point spawns branches (0.0-1.0)
@export_range(0.0, 1.0, 0.1) var branch_probability: float = 0.4

## Minimum branches per selected point
@export_range(1, 2, 1) var min_branches_per_point: int = 1

## Maximum branches per selected point
@export_range(1, 3, 1) var max_branches_per_point: int = 2

## Minimum branch length (pixels)
@export_range(50, 300, 25) var min_branch_length: float = 100.0

## Maximum branch length (pixels)
@export_range(200, 800, 50) var max_branch_length: float = 500.0

## Branch angle offset from main path direction (degrees)
@export_range(30, 120, 15) var branch_angle_degrees: float = 60.0

@export_group("Endpoint Event Areas")
## Create circular clearings at all endpoints for events
@export var create_endpoint_clearings: bool = true

## Radius of circular clearings at endpoints (pixels)
@export_range(75, 200, 25) var endpoint_clearing_radius: float = 125.0

@export_group("Ground Corridor Coverage")
## Ground extension beyond path centerline (tiles)
@export_range(5, 50, 5) var ground_extension: int = 20

@export_group("Debug Visualization")
## Show path network preview
@export var debug_show_paths: bool = false

## Show connection points
@export var debug_show_points: bool = false

# Internal classes for path representation

## Represents a connection point in the path network
class PathPoint:
	var position: Vector2
	var connections: Array[PathPoint] = []
	var id: int

	func _init(pos: Vector2, point_id: int):
		position = pos
		id = point_id

	func add_connection(other_point: PathPoint) -> void:
		if other_point not in connections:
			connections.append(other_point)
			if self not in other_point.connections:
				other_point.connections.append(self)

## Represents a path segment between two points
class PathSegment:
	var start_point: PathPoint
	var end_point: PathPoint
	var waypoints: Array[Vector2] = []
	var width: float

	func _init(start: PathPoint, end: PathPoint, segment_width: float):
		start_point = start
		end_point = end
		width = segment_width

	func add_waypoint(position: Vector2) -> void:
		waypoints.append(position)

	func get_full_path() -> Array[Vector2]:
		var full_path: Array[Vector2] = [start_point.position]
		full_path.append_array(waypoints)
		full_path.append(end_point.position)
		return full_path

## Generate clean path network for walkable corridors
func generate_path_network(rng: RandomNumberGenerator) -> Dictionary:
	if not enable_path_generation:
		return {"points": [], "paths": [], "corridor_bounds": Rect2()}

	# Generate connection points
	var points = _generate_connection_points(rng)
	if points.size() < connection_points:
		Logger.warn("Could not generate required connection points", "pathgen")
		return {"points": [], "paths": [], "corridor_bounds": Rect2()}

	# Create path network
	var paths = _create_path_network(points, rng)

	# Get endpoint positions for circular clearings
	var endpoints: Array[Vector2] = []
	if create_endpoint_clearings:
		endpoints = _get_all_endpoints(paths)

	# Calculate corridor bounds including path segments and endpoint clearings
	var corridor_bounds = _calculate_corridor_bounds_with_endpoints(paths, endpoints)

	Logger.info("Generated %d connection points, %d paths, %d endpoints" % [
		points.size(), paths.size(), endpoints.size()
	], "pathgen")

	return {
		"points": points,
		"paths": paths,
		"corridor_bounds": corridor_bounds,
		"endpoints": endpoints,
		"endpoint_clearing_radius": endpoint_clearing_radius if create_endpoint_clearings else 0.0
	}

## Generate connection points for single outward-extending chain
func _generate_connection_points(rng: RandomNumberGenerator) -> Array[PathPoint]:
	var points: Array[PathPoint] = []

	# Create a single chain extending outward using configurable chain length
	var total_chain_length = chain_length  # Use configurable chain length

	# Start at center
	var current_position = Vector2.ZERO
	var center_point = PathPoint.new(current_position, 0)
	points.append(center_point)

	# Choose initial random direction
	var current_direction = Vector2(cos(rng.randf() * TAU), sin(rng.randf() * TAU))

	# Generate points extending outward in sequence using configurable chain length
	for i in range(1, total_chain_length):
		# Distance for this segment using configurable min distance
		var segment_distance = min_point_distance * rng.randf_range(0.8, 1.2)

		# Add directional variation for natural curving path
		var direction_variation = deg_to_rad(rng.randf_range(-30.0, 30.0))
		current_direction = current_direction.rotated(direction_variation).normalized()

		# Calculate next position
		current_position += current_direction * segment_distance

		var new_point = PathPoint.new(current_position, i)
		points.append(new_point)

	Logger.debug("Generated single outward chain: %d points" % points.size(), "pathgen")
	return points

## Create connected path network between points (single linear chain)
func _create_path_network(points: Array[PathPoint], rng: RandomNumberGenerator) -> Array[PathSegment]:
	var paths: Array[PathSegment] = []

	if points.size() < 2:
		Logger.warn("Not enough points for chain", "pathgen")
		return paths

	# Single linear chain: connect each point to the next in sequence
	# Point 0 → Point 1 → Point 2 → Point 3
	for i in range(points.size() - 1):
		var start_point = points[i]
		var end_point = points[i + 1]

		# Connect points in sequence
		_connect_points(start_point, end_point)

		# Create path segment
		var path = PathSegment.new(start_point, end_point, path_width)
		paths.append(path)

	# Simplified branching system: generate single-line branches from eligible chain points
	if enable_dynamic_branching and points.size() >= 3:
		var total_branches_created = 0
		var branch_id_counter = points.size()

		# Check each point from index 1 to second-to-last for branching
		for i in range(1, points.size() - 1):
			if rng.randf() < branch_probability:
				var branch_origin = points[i]
				var branch_count = rng.randi_range(min_branches_per_point, max_branches_per_point)

				Logger.debug("Creating %d simple branch(es) from point %d" % [branch_count, i], "pathgen")

				for b in range(branch_count):
					var branch_points = _generate_simple_branch(
						branch_origin, points, i, branch_id_counter, rng, b
					)

					if not branch_points.is_empty():
						# Create single path segment for this simple branch (origin → endpoint)
						var branch_path = PathSegment.new(
							branch_points[0], branch_points[1], path_width
						)
						paths.append(branch_path)

						branch_id_counter += branch_points.size()
						total_branches_created += 1

		Logger.debug("Generated %d simple single-line branches" % total_branches_created, "pathgen")

	Logger.debug("Created path network: %d path segments total" % paths.size(), "pathgen")

	# Add waypoints for natural path variation
	if add_intermediate_waypoints:
		_add_waypoints_to_paths(paths, rng)

	return paths

## Connect two points bidirectionally
func _connect_points(point1: PathPoint, point2: PathPoint) -> void:
	point1.add_connection(point2)

## Generate a simple single-line branch from a chain point with angle-based direction
func _generate_simple_branch(origin: PathPoint, main_points: Array[PathPoint], origin_index: int, start_id: int, rng: RandomNumberGenerator, branch_index: int) -> Array[PathPoint]:
	var branch_points: Array[PathPoint] = [origin]  # Start with the origin point

	# Get main path direction at the branch point
	var main_direction: Vector2
	if origin_index > 0 and origin_index < main_points.size() - 1:
		# Calculate main path direction from previous to next point
		var before_to_origin = (origin.position - main_points[origin_index - 1].position).normalized()
		var origin_to_after = (main_points[origin_index + 1].position - origin.position).normalized()
		main_direction = (before_to_origin + origin_to_after).normalized()
	else:
		# Fallback: use direction to next or previous point
		if origin_index > 0:
			main_direction = (origin.position - main_points[origin_index - 1].position).normalized()
		else:
			main_direction = (main_points[origin_index + 1].position - origin.position).normalized()

	# Simple angle-based direction: alternate between left and right sides
	var branch_angle = deg_to_rad(branch_angle_degrees)  # Use configurable angle
	if branch_index % 2 == 1:
		branch_angle = -branch_angle  # Alternate sides

	var branch_direction = main_direction.rotated(branch_angle)

	# Random branch length (keep this for variety)
	var branch_length = rng.randf_range(min_branch_length, max_branch_length)

	# Create single endpoint for direct line branch
	var endpoint_position = origin.position + (branch_direction * branch_length)
	var endpoint = PathPoint.new(endpoint_position, start_id)
	branch_points.append(endpoint)

	# Connect origin to endpoint
	_connect_points(origin, endpoint)

	Logger.debug("Generated simple branch: %.1f° angle, %.1fpx length" % [
		rad_to_deg(branch_angle), branch_length
	], "pathgen")

	return branch_points

## Get all endpoint positions for circular clearing generation
func _get_all_endpoints(paths: Array[PathSegment]) -> Array[Vector2]:
	var endpoints: Array[Vector2] = []
	var collected_positions: Dictionary = {}  # Avoid duplicates

	for path in paths:
		var path_points = path.get_full_path()
		if path_points.size() >= 2:
			var start_pos = path_points[0]
			var end_pos = path_points[-1]

			# Check if these are true endpoints (not connected to other paths)
			var start_key = str(start_pos.x) + "," + str(start_pos.y)
			var end_key = str(end_pos.x) + "," + str(end_pos.y)

			if not collected_positions.has(start_key):
				var is_start_endpoint = _is_true_endpoint(start_pos, paths)
				if is_start_endpoint:
					endpoints.append(start_pos)
					collected_positions[start_key] = true

			if not collected_positions.has(end_key):
				var is_end_endpoint = _is_true_endpoint(end_pos, paths)
				if is_end_endpoint:
					endpoints.append(end_pos)
					collected_positions[end_key] = true

	Logger.debug("Found %d true endpoints for circular clearings" % endpoints.size(), "pathgen")
	return endpoints

## Check if a position is a true endpoint (appears in only one path)
func _is_true_endpoint(position: Vector2, paths: Array[PathSegment]) -> bool:
	var count = 0
	var tolerance = 5.0  # Small tolerance for floating point comparison

	for path in paths:
		var path_points = path.get_full_path()
		for point in path_points:
			if position.distance_to(point) < tolerance:
				count += 1
				if count > 1:
					return false  # This position is shared, not an endpoint

	return count == 1

## Add intermediate waypoints to paths for natural variation
func _add_waypoints_to_paths(paths: Array[PathSegment], rng: RandomNumberGenerator) -> void:
	for path in paths:
		if rng.randf() < waypoint_probability:
			# Add 1-2 waypoints per path
			var waypoint_count = rng.randi_range(1, 2)

			for i in range(waypoint_count):
				var t = (i + 1.0) / (waypoint_count + 1.0)
				var base_pos = path.start_point.position.lerp(path.end_point.position, t)

				# Add variation perpendicular to path direction
				var path_direction = (path.end_point.position - path.start_point.position).normalized()
				var perpendicular = Vector2(-path_direction.y, path_direction.x)

				var variation_distance = rng.randf_range(-max_path_variation, max_path_variation)
				var waypoint = base_pos + (perpendicular * variation_distance)

				path.add_waypoint(waypoint)

## Calculate bounding rectangle for all path corridors
func _calculate_corridor_bounds(points: Array[PathPoint]) -> Rect2:
	if points.is_empty():
		return Rect2()

	# Calculate bounding rect of all connection points
	var min_pos = points[0].position
	var max_pos = points[0].position

	for point in points:
		min_pos.x = min(min_pos.x, point.position.x)
		min_pos.y = min(min_pos.y, point.position.y)
		max_pos.x = max(max_pos.x, point.position.x)
		max_pos.y = max(max_pos.y, point.position.y)

	# Extend bounds for path width, ground extension, and point space radius
	var total_extension = path_width + (ground_extension * 16)  # Simplified extension calculation
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

	return Rect2(min_pos, max_pos - min_pos)

## Calculate bounding rectangle from paths AND endpoint clearings
func _calculate_corridor_bounds_with_endpoints(paths: Array[PathSegment], endpoints: Array[Vector2]) -> Rect2:
	if paths.is_empty():
		return Rect2()

	# Start with path bounds
	var all_positions: Array[Vector2] = []

	# Collect all path positions
	for path in paths:
		var path_points = path.get_full_path()
		all_positions.append_array(path_points)

	# Add endpoint clearing areas
	for endpoint in endpoints:
		# Add points around each endpoint to expand the bounds
		var clearing_radius = endpoint_clearing_radius
		all_positions.append(endpoint + Vector2(-clearing_radius, -clearing_radius))
		all_positions.append(endpoint + Vector2(clearing_radius, clearing_radius))
		all_positions.append(endpoint + Vector2(-clearing_radius, clearing_radius))
		all_positions.append(endpoint + Vector2(clearing_radius, -clearing_radius))

	if all_positions.is_empty():
		return Rect2()

	# Calculate bounding rect of ALL positions (paths + endpoint clearings)
	var min_pos = all_positions[0]
	var max_pos = all_positions[0]

	for pos in all_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	# Extend bounds for path width and ground extension
	var total_extension = path_width + (ground_extension * 16)
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

	Logger.debug("Corridor bounds with endpoints: %.1f x %.1f, %d endpoints with %.1fpx clearings" % [
		max_pos.x - min_pos.x, max_pos.y - min_pos.y, endpoints.size(), endpoint_clearing_radius
	], "pathgen")

	return Rect2(min_pos, max_pos - min_pos)

## Calculate bounding rectangle from ALL path segments (includes branches)
func _calculate_corridor_bounds_from_paths(paths: Array[PathSegment]) -> Rect2:
	if paths.is_empty():
		return Rect2()

	# Extract all endpoints from all path segments (main + branches)
	var all_positions: Array[Vector2] = []

	for path in paths:
		var path_points = path.get_full_path()
		all_positions.append_array(path_points)

	if all_positions.is_empty():
		return Rect2()

	# Calculate bounding rect of ALL path positions (including branch endpoints)
	var min_pos = all_positions[0]
	var max_pos = all_positions[0]

	for pos in all_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	# Extend bounds for path width and ground extension
	var total_extension = path_width + (ground_extension * 16)
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

	Logger.debug("Corridor bounds from paths: %.1f x %.1f at (%.1f, %.1f)" % [
		max_pos.x - min_pos.x, max_pos.y - min_pos.y, min_pos.x, min_pos.y
	], "pathgen")

	return Rect2(min_pos, max_pos - min_pos)

## Generate path extension positions around existing path tiles
func generate_path_extensions(ground_positions: Array[Vector2]) -> Array[Vector2]:
	# path_extension_width parameter removed - no extensions generated
	return []

## Generate dual-layer forest rings using optimized spatial collision detection
func generate_dual_forest_rings(ground_positions: Array[Vector2], paths: Array = []) -> Dictionary:
	# path_extension_width parameter removed - no forest rings generated
	return {"green": [], "dark": []}

## Check if position is within walkable corridor (path width only)
func is_position_in_walkable_corridor(position: Vector2, paths: Array[PathSegment]) -> bool:
	for path in paths:
		var path_points = path.get_full_path()
		var walkable_half_width = path.width * 0.5

		# Check distance to each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]
			var distance = _point_to_line_distance(position, start_point, end_point)

			if distance <= walkable_half_width:
				return true

	return false

## Calculate distance from point to line segment
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var line_length_squared = line_vec.length_squared()

	if line_length_squared == 0.0:
		return point.distance_to(line_start)

	var t = max(0, min(1, (point - line_start).dot(line_vec) / line_length_squared))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

## Build fast spatial collision grid for path corridors (performance optimization)
func _build_path_collision_grid(paths: Array[PathSegment], grid_size: float) -> Dictionary:
	var collision_grid: Dictionary = {}
	var half_width = path_width * 0.5

	for path in paths:
		var path_points = path.get_full_path()

		# Process each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]

			# Calculate bounding box for this segment
			var min_x = min(start_point.x, end_point.x) - half_width
			var max_x = max(start_point.x, end_point.x) + half_width
			var min_y = min(start_point.y, end_point.y) - half_width
			var max_y = max(start_point.y, end_point.y) + half_width

			# Mark all grid cells that this segment affects
			var start_grid_x = int(floor(min_x / grid_size))
			var end_grid_x = int(ceil(max_x / grid_size))
			var start_grid_y = int(floor(min_y / grid_size))
			var end_grid_y = int(ceil(max_y / grid_size))

			for grid_x in range(start_grid_x, end_grid_x + 1):
				for grid_y in range(start_grid_y, end_grid_y + 1):
					var grid_key = Vector2i(grid_x, grid_y)
					if not collision_grid.has(grid_key):
						collision_grid[grid_key] = []
					collision_grid[grid_key].append([start_point, end_point])

	Logger.debug("Built collision grid: %d cells covering %d path segments" % [
		collision_grid.size(), paths.size()
	], "pathgen")

	return collision_grid

## Fast collision check using spatial grid (O(1) average case vs O(n) for full path check)
func _is_position_in_collision_grid(position: Vector2, collision_grid: Dictionary, grid_size: float) -> bool:
	var grid_x = int(floor(position.x / grid_size))
	var grid_y = int(floor(position.y / grid_size))
	var grid_key = Vector2i(grid_x, grid_y)

	if not collision_grid.has(grid_key):
		return false

	var segments: Array = collision_grid[grid_key]
	var half_width = path_width * 0.5

	# Only check segments in this grid cell (massive reduction vs checking all segments)
	for segment in segments:
		var start_point = segment[0]
		var end_point = segment[1]
		var distance = _point_to_line_distance(position, start_point, end_point)

		if distance <= half_width:
			return true

	return false

## Get ground corridor tile positions for walkable areas
func get_ground_corridor_positions(paths: Array[PathSegment], corridor_bounds: Rect2) -> Array[Vector2]:
	var ground_positions: Array[Vector2] = []
	var tile_size = 48  # Match forest tileset 48x48 tiles

	Logger.debug("Checking corridor bounds: %s, paths: %d" % [corridor_bounds, paths.size()], "pathgen")

	# Grid-based approach for ground tiles
	var start_x = int(corridor_bounds.position.x / tile_size) * tile_size
	var start_y = int(corridor_bounds.position.y / tile_size) * tile_size
	var end_x = start_x + corridor_bounds.size.x
	var end_y = start_y + corridor_bounds.size.y

	var total_positions_checked = 0
	var positions_in_corridor = 0

	# Sample all positions and place ground where corridors exist
	for x in range(start_x, end_x, tile_size):
		for y in range(start_y, end_y, tile_size):
			var test_position = Vector2(x, y)
			total_positions_checked += 1

			# Place ground tiles where position IS in walkable corridors
			if is_position_in_walkable_corridor(test_position, paths):
				ground_positions.append(test_position)
				positions_in_corridor += 1

	Logger.debug("Ground position check: %d/%d positions in corridor, first path width: %.1f" % [
		positions_in_corridor, total_positions_checked,
		paths[0].width if paths.size() > 0 else 0.0
	], "pathgen")

	return ground_positions
