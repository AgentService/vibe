@tool
class_name PathConfiguration
extends Resource

## Path-only configuration for dungeon-style walkable path generation
## Focused solely on creating navigable routes between connection points

@export_group("Path Network Setup")
## Enable path generation system
@export var enable_path_generation: bool = true

## Number of connection points for path network (configurable chain length)
@export_range(2, 10, 1) var connection_points: int = 3

## Chain length for the outward path (how many points in sequence)
@export_range(2, 10, 1) var chain_length: int = 6

## Minimum distance between connection points (pixels)
@export_range(50, 500, 10) var min_point_distance: float = 120.0

## Point space radius - circular area around each point that pushes boundaries outward
@export_range(50, 200, 10) var point_space_radius: float = 100.0

## Path extension width - Green ring thickness for forest layers (pixels) - unlimited
@export_range(0, 999999, 12) var path_extension_width: float = 48.0

## Second extension width - Dark ring thickness for deeper forest layers (pixels) - unlimited
@export_range(0, 999999, 12) var path_extension_width2: float = 48.0

## Arena size for point generation bounds
@export_range(100, 500, 20) var arena_size: float = 300.0

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

	# Calculate corridor bounds for ground generation (include ALL path segments)
	var corridor_bounds = _calculate_corridor_bounds_from_paths(paths)

	Logger.info("Generated %d connection points, %d paths" % [points.size(), paths.size()], "pathgen")

	return {
		"points": points,
		"paths": paths,
		"corridor_bounds": corridor_bounds
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

	# TEST: Add a branch path from the second point (index 1) to test boundary response
	if points.size() >= 3:
		var branch_point = points[1]  # Second point

		# Create branch direction perpendicular to main path direction
		var main_direction = (points[2].position - points[1].position).normalized()
		var branch_direction = Vector2(-main_direction.y, main_direction.x)  # 90-degree rotation

		# Create two branch points extending outward
		var branch_pos1 = branch_point.position + branch_direction * min_point_distance * 1.2
		var branch_pos2 = branch_pos1 + branch_direction * min_point_distance * 1.0

		var branch_point1 = PathPoint.new(branch_pos1, points.size())
		var branch_point2 = PathPoint.new(branch_pos2, points.size() + 1)

		# Connect branch points
		_connect_points(branch_point, branch_point1)
		_connect_points(branch_point1, branch_point2)

		# Create branch path segments
		var branch_path1 = PathSegment.new(branch_point, branch_point1, path_width)
		var branch_path2 = PathSegment.new(branch_point1, branch_point2, path_width)

		paths.append(branch_path1)
		paths.append(branch_path2)

		Logger.debug("Added test branch: 2 additional path segments from point 1", "pathgen")

	Logger.debug("Created path network with branches: %d path segments total" % paths.size(), "pathgen")

	# Add waypoints for natural path variation
	if add_intermediate_waypoints:
		_add_waypoints_to_paths(paths, rng)

	return paths

## Connect two points bidirectionally
func _connect_points(point1: PathPoint, point2: PathPoint) -> void:
	point1.add_connection(point2)

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
	var total_extension = path_width + (ground_extension * 16) + point_space_radius  # Include point space radius
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

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

	# Extend bounds for path width, ground extension, and point space radius
	var total_extension = path_width + (ground_extension * 16) + point_space_radius
	min_pos -= Vector2(total_extension, total_extension)
	max_pos += Vector2(total_extension, total_extension)

	Logger.debug("Corridor bounds from paths: %.1f x %.1f at (%.1f, %.1f)" % [
		max_pos.x - min_pos.x, max_pos.y - min_pos.y, min_pos.x, min_pos.y
	], "pathgen")

	return Rect2(min_pos, max_pos - min_pos)

## Generate path extension positions around existing path tiles
func generate_path_extensions(ground_positions: Array[Vector2]) -> Array[Vector2]:
	if path_extension_width <= 0:
		return []

	var extension_positions: Array[Vector2] = []
	var tile_size = 48  # Forest tileset uses 48x48 tiles

	# Convert extension width to tile count
	var extension_tiles = int(ceil(path_extension_width / tile_size))

	# For each ground position, generate extension tiles around it
	for ground_pos in ground_positions:
		for x_offset in range(-extension_tiles, extension_tiles + 1):
			for y_offset in range(-extension_tiles, extension_tiles + 1):
				# Skip the center position (already has ground tile)
				if x_offset == 0 and y_offset == 0:
					continue

				# Calculate distance to determine if within extension radius
				var distance = sqrt(x_offset * x_offset + y_offset * y_offset) * tile_size
				if distance <= path_extension_width:
					var extension_pos = ground_pos + Vector2(x_offset * tile_size, y_offset * tile_size)

					# Only add if not already a ground position
					if not extension_pos in ground_positions:
						extension_positions.append(extension_pos)

	# Remove duplicates
	var unique_extensions: Array[Vector2] = []
	for ext_pos in extension_positions:
		if not ext_pos in unique_extensions:
			unique_extensions.append(ext_pos)

	Logger.debug("Generated %d path extension positions with width %.1fpx" % [
		unique_extensions.size(), path_extension_width
	], "pathgen")

	return unique_extensions

## Generate dual-layer forest rings using optimized spatial collision detection
func generate_dual_forest_rings(ground_positions: Array[Vector2], paths: Array = []) -> Dictionary:
	if path_extension_width <= 0:
		return {"green": [], "dark": []}

	# Debug parameter values
	Logger.debug("Ring generation parameters: width1=%.1f, width2=%.1f, path_width=%.1f" % [
		path_extension_width, path_extension_width2, path_width
	], "pathgen")

	# Build fast spatial collision grid for path corridors (performance optimization)
	var collision_grid: Dictionary = {}
	var grid_size = 96.0  # 2x tile size for good granularity vs performance
	if not paths.is_empty():
		collision_grid = _build_path_collision_grid(paths, grid_size)

	var green_tiles: Dictionary = {}  # Vector2i -> bool for deduplication
	var dark_tiles: Dictionary = {}   # Vector2i -> bool for deduplication
	var tile_size = 48.0

	# Calculate path edge distance (where Green ring should start)
	var path_edge_distance = path_width * 0.5  # Half-width = edge of walkable corridor

	# Use independent width parameters for each ring, starting from path edge:
	# Green ring: path_edge_distance to path_edge_distance + path_extension_width
	# Dark ring: path_edge_distance + path_extension_width to path_edge_distance + path_extension_width + path_extension_width2
	var green_inner_radius = path_edge_distance
	var green_outer_radius = path_edge_distance + path_extension_width
	var dark_outer_radius = path_edge_distance + path_extension_width + path_extension_width2

	# Compute once the max tile radius we need (tight loop bounds)
	var max_radius_tiles = int(ceil(dark_outer_radius / tile_size))

	# Squared thresholds in tile space to avoid sqrt
	var green_inner_threshold_sq = (green_inner_radius / tile_size) * (green_inner_radius / tile_size)
	var green_outer_threshold_sq = (green_outer_radius / tile_size) * (green_outer_radius / tile_size)
	var dark_outer_threshold_sq = (dark_outer_radius / tile_size) * (dark_outer_radius / tile_size)

	# Single pass generation: both layers from same loop
	for ground_pos in ground_positions:
		var base_tile_x = int(ground_pos.x / tile_size)
		var base_tile_y = int(ground_pos.y / tile_size)

		for x_offset in range(-max_radius_tiles, max_radius_tiles + 1):
			for y_offset in range(-max_radius_tiles, max_radius_tiles + 1):
				# Skip center position (walkable area)
				if x_offset == 0 and y_offset == 0:
					continue

				# Use squared distance in tile space (no sqrt needed)
				var distance_sq = x_offset * x_offset + y_offset * y_offset
				var tile_pos = Vector2i(base_tile_x + x_offset, base_tile_y + y_offset)

				# Split distance thresholds for proper ring assignment:
				# Green ring: path_edge_distance < distance <= path_edge_distance + path_extension_width
				# Dark ring: path_edge_distance + path_extension_width < distance <= path_edge_distance + 2 * path_extension_width
				if distance_sq > green_inner_threshold_sq and distance_sq <= green_outer_threshold_sq:
					# Fast collision-aware generation using spatial grid
					var world_pos = Vector2(tile_pos.x * tile_size, tile_pos.y * tile_size)
					if paths.is_empty() or not _is_position_in_collision_grid(world_pos, collision_grid, grid_size):
						green_tiles[tile_pos] = true
				elif distance_sq > green_outer_threshold_sq and distance_sq <= dark_outer_threshold_sq:
					# Fast collision-aware generation using spatial grid
					var world_pos = Vector2(tile_pos.x * tile_size, tile_pos.y * tile_size)
					if paths.is_empty() or not _is_position_in_collision_grid(world_pos, collision_grid, grid_size):
						dark_tiles[tile_pos] = true

	# Convert to position arrays for tile placement
	var green_positions: Array[Vector2] = []
	var dark_positions: Array[Vector2] = []

	for tile_coord in green_tiles.keys():
		green_positions.append(Vector2(tile_coord.x * tile_size, tile_coord.y * tile_size))

	for tile_coord in dark_tiles.keys():
		dark_positions.append(Vector2(tile_coord.x * tile_size, tile_coord.y * tile_size))

	Logger.debug("Generated dual forest rings using widths %.1f/%.1fpx: %d green (%.1f-%.1f), %d dark (%.1f-%.1f) [SPATIAL OPTIMIZED]" % [
		path_extension_width, path_extension_width2, green_positions.size(), green_inner_radius, green_outer_radius, dark_positions.size(), green_outer_radius, dark_outer_radius
	], "pathgen")

	return {"green": green_positions, "dark": dark_positions}

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
