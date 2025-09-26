@tool
class_name PathNetworkConfig
extends Resource

## Multi-point path generation configuration for arena connectivity
## Creates connected areas within the arena with paths that avoid tree placement

@export_group("Path Network")
## Enable multi-point path generation system
@export var enable_path_network: bool = false

## Number of connection points to generate (fixed at 3 for now)
@export_range(3, 3, 1) var point_count: int = 3

## Minimum distance between points in pixels
@export_range(50, 200, 10) var min_point_distance: float = 50.0

## Path width in pixels (creates corridors free of trees)
@export_range(32, 128, 8) var path_width: float = 64.0

@export_group("Path Generation")
## Minimum angle change between path segments (degrees)
@export_range(15, 90, 5) var min_angle_change: float = 30.0

## Maximum angle change between path segments (degrees)
@export_range(90, 180, 10) var max_angle_change: float = 120.0

## Smoothing factor for path curves (0=sharp angles, 1=smooth curves)
@export_range(0.0, 1.0, 0.1) var path_smoothing: float = 0.3

@export_group("Connectivity")
## Ensure all points are connected in a network (not just linear chain)
@export var create_network_connectivity: bool = true

## Add random intermediate waypoints along paths for more natural routing
@export var add_intermediate_waypoints: bool = true

## Maximum additional waypoints per path segment
@export_range(0, 3, 1) var max_intermediate_waypoints: int = 1

@export_group("Debug")
## Show path network preview in editor
@export var debug_show_path_preview: bool = false

## Show point locations in editor
@export var debug_show_points: bool = false

## Represents a single connection point in the network
class PathPoint:
	var position: Vector2
	var connections: Array[PathPoint] = []

	func _init(pos: Vector2):
		position = pos

	func add_connection(other_point: PathPoint) -> void:
		if other_point not in connections:
			connections.append(other_point)
			if self not in other_point.connections:
				other_point.connections.append(self)

## Represents a path segment between two points
class PathSegment:
	var start_point: PathPoint
	var end_point: PathPoint
	var waypoints: Array[Vector2] = []  # Intermediate points along the path
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

## Generate the path network within the given arena bounds
func generate_path_network(arena_bounds: Rect2i, rng: RandomNumberGenerator) -> Array[PathSegment]:
	if not enable_path_network:
		return []

	# Generate points within arena bounds
	var points = _generate_points(arena_bounds, rng)
	if points.size() < point_count:
		return []  # Failed to place minimum required points

	# Create connections between points
	var segments = _create_path_segments(points, rng)

	# Add intermediate waypoints for natural routing
	if add_intermediate_waypoints:
		_add_waypoints_to_segments(segments, rng)

	return segments

## Generate random points within arena bounds with minimum distance constraints
func _generate_points(arena_bounds: Rect2i, rng: RandomNumberGenerator) -> Array[PathPoint]:
	var points: Array[PathPoint] = []
	var max_attempts = 50  # Prevent infinite loops

	# Shrink bounds slightly to keep points well within arena
	var safe_bounds = Rect2i(
		arena_bounds.position + Vector2i(int(min_point_distance), int(min_point_distance)),
		arena_bounds.size - Vector2i(int(min_point_distance * 2), int(min_point_distance * 2))
	)

	for i in range(point_count):
		var attempts = 0
		var valid_position = false
		var new_position: Vector2

		while not valid_position and attempts < max_attempts:
			# Generate random position within safe bounds
			new_position = Vector2(
				rng.randf_range(safe_bounds.position.x, safe_bounds.position.x + safe_bounds.size.x),
				rng.randf_range(safe_bounds.position.y, safe_bounds.position.y + safe_bounds.size.y)
			)

			# Check minimum distance from existing points
			valid_position = true
			for existing_point in points:
				if new_position.distance_to(existing_point.position) < min_point_distance:
					valid_position = false
					break

			attempts += 1

		if valid_position:
			points.append(PathPoint.new(new_position))
		else:
			print("Warning: Could not place point ", i, " with minimum distance constraints")

	return points

## Create path segments connecting the points
func _create_path_segments(points: Array[PathPoint], rng: RandomNumberGenerator) -> Array[PathSegment]:
	var segments: Array[PathSegment] = []

	if points.size() < 2:
		return segments

	if create_network_connectivity:
		# Create a connected network - each point connects to at least one other
		segments.append_array(_create_network_connections(points, rng))
	else:
		# Create simple linear chain
		segments.append_array(_create_linear_connections(points))

	return segments

## Create network connections ensuring all points are reachable
func _create_network_connections(points: Array[PathPoint], rng: RandomNumberGenerator) -> Array[PathSegment]:
	var segments: Array[PathSegment] = []

	# Start with minimum spanning tree approach
	var connected: Array[PathPoint] = [points[0]]
	var unconnected: Array[PathPoint] = points.slice(1)

	# Connect each unconnected point to the closest connected point
	while not unconnected.is_empty():
		var closest_pair = _find_closest_pair(connected, unconnected)
		var connected_point = closest_pair[0]
		var new_point = closest_pair[1]

		# Create connection
		connected_point.add_connection(new_point)
		segments.append(PathSegment.new(connected_point, new_point, path_width))

		# Move to connected set
		connected.append(new_point)
		unconnected.erase(new_point)

	# Optionally add one more connection for redundancy (triangle instead of tree)
	if points.size() == 3 and rng.randf() < 0.7:  # 70% chance of triangle completion
		# Connect the two endpoints to form a triangle
		var endpoints = _find_endpoints(points)
		if endpoints.size() == 2:
			endpoints[0].add_connection(endpoints[1])
			segments.append(PathSegment.new(endpoints[0], endpoints[1], path_width))

	return segments

## Create simple linear chain connections
func _create_linear_connections(points: Array[PathPoint]) -> Array[PathSegment]:
	var segments: Array[PathSegment] = []

	for i in range(points.size() - 1):
		points[i].add_connection(points[i + 1])
		segments.append(PathSegment.new(points[i], points[i + 1], path_width))

	return segments

## Find the closest pair between connected and unconnected points
func _find_closest_pair(connected: Array[PathPoint], unconnected: Array[PathPoint]) -> Array[PathPoint]:
	var min_distance = INF
	var closest_pair: Array[PathPoint] = []

	for connected_point in connected:
		for unconnected_point in unconnected:
			var distance = connected_point.position.distance_to(unconnected_point.position)
			if distance < min_distance:
				min_distance = distance
				closest_pair = [connected_point, unconnected_point]

	return closest_pair

## Find endpoints (points with only one connection) for triangle completion
func _find_endpoints(points: Array[PathPoint]) -> Array[PathPoint]:
	var endpoints: Array[PathPoint] = []

	for point in points:
		if point.connections.size() == 1:
			endpoints.append(point)

	return endpoints

## Add intermediate waypoints to path segments for natural routing
func _add_waypoints_to_segments(segments: Array[PathSegment], rng: RandomNumberGenerator) -> void:
	for segment in segments:
		var waypoint_count = rng.randi_range(0, max_intermediate_waypoints)

		for i in range(waypoint_count):
			var t = (i + 1.0) / (waypoint_count + 1.0)  # Evenly distribute waypoints
			var base_position = segment.start_point.position.lerp(segment.end_point.position, t)

			# Add random offset with angle constraints
			var offset_angle = rng.randf_range(
				deg_to_rad(-max_angle_change / 2),
				deg_to_rad(max_angle_change / 2)
			)
			var offset_distance = rng.randf_range(path_width * 0.5, path_width * 1.5)
			var offset = Vector2.from_angle(offset_angle) * offset_distance

			segment.add_waypoint(base_position + offset)

## Check if a position is within any path corridor (for tree exclusion)
func is_position_on_path(position: Vector2, segments: Array[PathSegment]) -> bool:
	for segment in segments:
		if _is_position_on_segment(position, segment):
			return true
	return false

## Check if position is within a specific path segment's corridor
func _is_position_on_segment(position: Vector2, segment: PathSegment) -> bool:
	var path_points = segment.get_full_path()
	var half_width = segment.width * 0.5

	# Check distance to each path line segment
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