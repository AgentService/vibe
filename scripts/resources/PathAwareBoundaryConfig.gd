@tool
class_name PathAwareBoundaryConfig
extends Resource

## Path-aware boundary generation that creates boundaries naturally following path networks
## This creates more organic, realistic boundaries where paths are integral to the design

@export_group("Path Network Setup")
## Enable path-aware boundary generation
@export var enable_path_aware_boundaries: bool = false

## Number of spoke points extending from center (fixed at 3 for hub-and-spoke)
@export_range(3, 3, 1) var connection_points: int = 3

## Minimum distance between connection points (pixels)
@export_range(50, 200, 10) var min_point_distance: float = 80.0

## Arena size for point generation bounds
@export_range(100, 500, 20) var arena_size: float = 300.0

@export_group("Path Configuration")
## Path width that boundaries will follow (pixels)
@export_range(32, 128, 8) var path_width: float = 64.0

## Additional boundary thickness around paths (pixels)
@export_range(16, 64, 4) var boundary_thickness: float = 32.0

## Smoothing factor for path curves (0=angular, 1=smooth)
@export_range(0.0, 1.0, 0.1) var path_smoothing: float = 0.4


@export_group("Ground Coverage")
## Ground extension beyond boundary trees (tiles)
@export_range(5, 50, 5) var ground_extension: int = 20

@export_group("Natural Generation")
## Add randomness to path routing for organic feel
@export var enable_path_variation: bool = true

## Maximum angle variation for path segments (degrees)
@export_range(10, 45, 5) var max_path_variation: float = 20.0

## Add intermediate waypoints for more natural paths
@export var add_intermediate_waypoints: bool = true

## Probability of adding waypoints (0.0-1.0)
@export_range(0.0, 1.0, 0.1) var waypoint_probability: float = 0.6

@export_group("Debug")
## Show path network and boundary preview
@export var debug_show_boundaries: bool = false

## Show connection points
@export var debug_show_points: bool = false

# Internal classes for path-aware boundary representation

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

## Represents a boundary path between two points
class BoundaryPath:
	var start_point: PathPoint
	var end_point: PathPoint
	var waypoints: Array[Vector2] = []
	var width: float
	var boundary_thickness: float

	func _init(start: PathPoint, end: PathPoint, path_width: float, thickness: float):
		start_point = start
		end_point = end
		width = path_width
		boundary_thickness = thickness

	func add_waypoint(position: Vector2) -> void:
		waypoints.append(position)

	func get_full_path() -> Array[Vector2]:
		var full_path: Array[Vector2] = [start_point.position]
		full_path.append_array(waypoints)
		full_path.append(end_point.position)
		return full_path

	func get_total_width() -> float:
		return width + (boundary_thickness * 2)

## Generate path-aware boundary system
func generate_path_aware_boundaries(rng: RandomNumberGenerator) -> Dictionary:
	if not enable_path_aware_boundaries:
		return {"points": [], "paths": [], "boundary_points": []}

	# Generate connection points
	var points = _generate_connection_points(rng)
	if points.size() < connection_points:
		print("Warning: Could not generate required connection points")
		return {"points": [], "paths": [], "boundary_points": []}

	# Create path network
	var paths = _create_path_network(points, rng)

	# Generate boundary points along paths
	var boundary_points = _generate_boundary_points_along_paths(paths, rng)

	print("Generated ", points.size(), " connection points, ", paths.size(), " paths, ", boundary_points.size(), " boundary points")

	return {
		"points": points,
		"paths": paths,
		"boundary_points": boundary_points
	}

## Generate connection points for single outward-extending chain
func _generate_connection_points(rng: RandomNumberGenerator) -> Array[PathPoint]:
	var points: Array[PathPoint] = []

	# Create a single chain extending outward: center → point1 → point2 → point3
	var chain_length = 4  # center + 3 points extending outward

	# Start at center
	var current_position = Vector2.ZERO
	var center_point = PathPoint.new(current_position, 0)
	points.append(center_point)

	# Choose initial random direction
	var current_direction = Vector2(cos(rng.randf() * TAU), sin(rng.randf() * TAU))

	# Generate 3 points extending outward in sequence
	for i in range(1, chain_length):
		# Distance for this segment
		var segment_distance = min_point_distance * rng.randf_range(0.8, 1.2)

		# Add directional variation for natural curving path
		var direction_variation = deg_to_rad(rng.randf_range(-30.0, 30.0))
		current_direction = current_direction.rotated(direction_variation).normalized()

		# Calculate next position
		current_position += current_direction * segment_distance

		var new_point = PathPoint.new(current_position, i)
		points.append(new_point)

	print("Generated single outward chain: ", points.size(), " points")
	return points

## Create connected path network between points (single linear chain)
func _create_path_network(points: Array[PathPoint], rng: RandomNumberGenerator) -> Array[BoundaryPath]:
	var paths: Array[BoundaryPath] = []

	if points.size() < 2:
		print("Warning: Not enough points for chain")
		return paths

	# Single linear chain: connect each point to the next in sequence
	# Point 0 → Point 1 → Point 2 → Point 3
	for i in range(points.size() - 1):
		var start_point = points[i]
		var end_point = points[i + 1]

		# Connect points in sequence
		_connect_points(start_point, end_point)

		# Create boundary path
		var path = BoundaryPath.new(start_point, end_point, path_width, boundary_thickness)
		paths.append(path)

	print("Created single linear chain: ", paths.size(), " path segments connecting ", points.size(), " points")

	# Add waypoints for natural path variation
	if add_intermediate_waypoints:
		_add_waypoints_to_paths(paths, rng)

	return paths

## Connect two points bidirectionally
func _connect_points(point1: PathPoint, point2: PathPoint) -> void:
	point1.add_connection(point2)

## Add intermediate waypoints to paths for natural variation
func _add_waypoints_to_paths(paths: Array[BoundaryPath], rng: RandomNumberGenerator) -> void:
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

## Generate boundary marker points along paths (for visualization/debug)
func _generate_boundary_points_along_paths(paths: Array[BoundaryPath], rng: RandomNumberGenerator) -> Array[Vector2]:
	var boundary_points: Array[Vector2] = []

	for path in paths:
		var path_points = path.get_full_path()

		# Generate boundary marker points along both sides of the path
		for i in range(path_points.size() - 1):
			var segment_start = path_points[i]
			var segment_end = path_points[i + 1]
			var segment_length = segment_start.distance_to(segment_end)

			# Calculate number of marker points along this segment
			var point_spacing = 32.0  # Fixed spacing for boundary markers
			var point_count = int(segment_length / point_spacing)

			for j in range(point_count):
				var t = float(j) / float(point_count)
				var point_on_path = segment_start.lerp(segment_end, t)

				# Get direction perpendicular to path
				var path_direction = (segment_end - segment_start).normalized()
				var perpendicular = Vector2(-path_direction.y, path_direction.x)

				# Place markers on both sides of path
				var total_width = path.get_total_width()
				var left_offset = perpendicular * (total_width * 0.5)
				var right_offset = perpendicular * (-total_width * 0.5)

				# Add boundary marker points
				boundary_points.append(point_on_path + left_offset)
				boundary_points.append(point_on_path + right_offset)

	return boundary_points

## Check if a position is inside the walkable area (between path boundaries)
func is_inside_walkable_area(position: Vector2, paths: Array[BoundaryPath]) -> bool:
	# Simple implementation: check if position is within any path corridor
	for path in paths:
		if _is_position_in_path_corridor(position, path):
			return true
	return false

## Check if position is within a path corridor
func _is_position_in_path_corridor(position: Vector2, path: BoundaryPath) -> bool:
	var path_points = path.get_full_path()
	var half_width = path.width * 0.5

	# Check distance to path centerline
	for i in range(path_points.size() - 1):
		var start_point = path_points[i]
		var end_point = path_points[i + 1]
		var distance = _point_to_line_distance(position, start_point, end_point)

		if distance <= half_width:
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


## Get all path points for ground tile generation
func get_path_corridor_bounds() -> Rect2:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var boundary_data = generate_path_aware_boundaries(rng)
	var points: Array = boundary_data.get("points", [])

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

	# Extend bounds for path width and ground extension
	var total_extension = path_width + boundary_thickness + (ground_extension * 16)  # Convert tiles to pixels
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

	return Rect2(min_pos, max_pos - min_pos)



## Check if position is within any path corridor (walkable area)
func _is_position_in_any_corridor(position: Vector2, paths: Array[BoundaryPath]) -> bool:
	for path in paths:
		if _is_position_in_path_corridor_extended(position, path):
			return true
	return false

## Enhanced corridor detection with proper width calculation
func _is_position_in_path_corridor_extended(position: Vector2, path: BoundaryPath) -> bool:
	var path_points = path.get_full_path()
	# Use total width (path + boundary thickness) for walkable corridor
	var corridor_half_width = (path.width + boundary_thickness) * 0.5

	# Check distance to each path segment
	for i in range(path_points.size() - 1):
		var start_point = path_points[i]
		var end_point = path_points[i + 1]
		var distance = _point_to_line_distance(position, start_point, end_point)

		if distance <= corridor_half_width:
			return true

	return false


## Check if position is within walkable corridor (path width only, no boundary thickness)
func _is_position_in_walkable_corridor(position: Vector2, paths: Array[BoundaryPath]) -> bool:
	for path in paths:
		var path_points = path.get_full_path()
		# Use only path width for ground tiles (no boundary thickness)
		var walkable_half_width = path.width * 0.5

		# Check distance to each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]
			var distance = _point_to_line_distance(position, start_point, end_point)

			if distance <= walkable_half_width:
				return true

	return false

## Get ground corridor tile positions (light green walkable areas in the image)
func get_ground_corridor_positions(rng: RandomNumberGenerator = null) -> Array[Vector2]:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.seed = 12345

	var boundary_data = generate_path_aware_boundaries(rng)
	var paths: Array = boundary_data.get("paths", [])

	if paths.is_empty():
		return []

	return _generate_ground_corridor_tiles(paths)

## Generate ground tiles for walkable corridors
func _generate_ground_corridor_tiles(paths: Array[BoundaryPath]) -> Array[Vector2]:
	var ground_positions: Array[Vector2] = []
	var tile_size = 16
	var arena_bounds = get_path_corridor_bounds()

	# Grid-based approach for ground tiles
	var start_x = int(arena_bounds.position.x / tile_size) * tile_size
	var start_y = int(arena_bounds.position.y / tile_size) * tile_size
	var end_x = start_x + arena_bounds.size.x
	var end_y = start_y + arena_bounds.size.y

	# Sample all positions and place ground where corridors exist
	for x in range(start_x, end_x, tile_size):
		for y in range(start_y, end_y, tile_size):
			var test_position = Vector2(x, y)

			# Place ground tiles where position IS in walkable corridors (narrower than full corridor)
			if _is_position_in_walkable_corridor(test_position, paths):
				ground_positions.append(test_position)

	return ground_positions

## Get path centerline tile positions (red path areas in the image)
func get_path_centerline_positions(rng: RandomNumberGenerator = null) -> Array[Vector2]:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.seed = 12345

	var boundary_data = generate_path_aware_boundaries(rng)
	var paths: Array = boundary_data.get("paths", [])

	if paths.is_empty():
		return []

	return _generate_path_centerline_tiles(paths)

## Generate tiles for the actual path centerlines (narrower than corridors)
func _generate_path_centerline_tiles(paths: Array[BoundaryPath]) -> Array[Vector2]:
	var path_positions: Array[Vector2] = []
	var tile_size = 16

	for path in paths:
		var path_points = path.get_full_path()
		var path_half_width = path.width * 0.25  # Narrower centerline

		# Generate centerline tiles along each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]
			var segment_length = start_point.distance_to(end_point)
			var segment_dir = (end_point - start_point).normalized()

			# Sample along the path centerline
			var step_size = tile_size
			var steps = int(segment_length / step_size)

			for j in range(steps + 1):
				var t = float(j) / float(steps) if steps > 0 else 0.0
				var point_on_path = start_point.lerp(end_point, t)
				path_positions.append(point_on_path)

	return path_positions
