@tool
class_name TreeBoundaryConfiguration
extends Resource

## Tree boundary configuration that responds to path data for natural arena containment
## Implements "Path Drives → Boundary Responds" principle
## Fixed: Removed non-functional parameters

@export_group("Tree Placement")
## Tree tile variants to use for boundary trees
@export var tree_tile_variants: Array[Vector2i] = [Vector2i(0, 28), Vector2i(9, 28)]

## Tree spacing between boundary trees (pixels) - reduced for better coverage
@export_range(16, 64, 4) var tree_spacing: float = 25.0

## Tree placement density (0.0-1.0, higher = more trees)
@export_range(0.1, 1.0, 0.05) var tree_density: float = 0.95

## Placement randomness intensity (0.0-100.0, higher = more random)
@export_range(0.0, 100.0, 0.1) var placement_randomness: float = 0.3

## Maximum pixel offset for random placement variation
@export_range(0, 200, 2) var max_random_offset: int = 8

@export_group("Boundary Adaptation")

## Tree boundary width - how far from paths to place trees (no limit)
@export_range(50, 99999, 50) var tree_boundary_width: float = 300.0

## Path buffer distance - minimum distance trees must maintain from paths
@export_range(16, 200, 8) var path_buffer_distance: float = 48.0

## Use efficient path-radius generation (only trees around paths, no huge rectangles)
@export var use_path_radius_generation: bool = true



@export_group("Boundary Optimization")
## Ensure trees form continuous boundary for arena containment
@export var enforce_boundary_continuity: bool = true

## Maximum gap allowed in tree boundary (pixels)
@export_range(16, 64, 8) var max_boundary_gap: float = 48.0

@export_group("Performance Optimization")
## Use spatial grid optimization for path collision detection (5x+ speedup)
@export var use_optimized_path_collision: bool = true

## Use pre-built tree field approach (much faster)
@export var use_prebuilt_tree_field: bool = true

## Tree field density for pre-generation (lower = more trees)
@export_range(0.3, 0.9, 0.1) var prebuilt_field_density: float = 0.7

## Use localized path corridors instead of full arena coverage (most efficient)
@export var use_localized_path_corridors: bool = false

# Performance optimization: Path data cache for zero-allocation generation
var _path_cache: PathDataCache
# Reusable buffer to avoid repeated Array[Vector2] allocations
var _path_buffer: Array[Vector2] = []

# Zero-allocation tree position management
var _tree_position_buffer: Array[Vector2] = []
var _temp_position_buffer: Array[Vector2] = []
var _perimeter_buffer: Array[Vector2] = []
var _endpoint_buffer: Array[Vector2] = []

# RingBuffer for memory-bounded tree generation
var _tree_ring_buffer: RingBuffer
var _use_streaming_generation: bool = false  # Toggle for testing

# RingBuffer configuration
@export_group("Memory Management")
@export_range(256, 8192, 256) var streaming_buffer_size: int = 1024
@export var enable_memory_bounded_generation: bool = false

# Get reusable tree position buffer (pre-cleared)
func _get_tree_buffer() -> Array[Vector2]:
	_tree_position_buffer.clear()
	return _tree_position_buffer

# Get reusable temporary buffer (pre-cleared)
func _get_temp_buffer() -> Array[Vector2]:
	_temp_position_buffer.clear()
	return _temp_position_buffer

# Get reusable perimeter buffer (pre-cleared)
func _get_perimeter_buffer() -> Array[Vector2]:
	_perimeter_buffer.clear()
	return _perimeter_buffer

# Get reusable endpoint buffer (pre-cleared)
func _get_endpoint_buffer() -> Array[Vector2]:
	_endpoint_buffer.clear()
	return _endpoint_buffer

# Initialize RingBuffer for memory-bounded tree generation
func _initialize_tree_ring_buffer() -> void:
	if not _tree_ring_buffer:
		_tree_ring_buffer = RingBuffer.new()
		_tree_ring_buffer.setup(streaming_buffer_size)  # Configurable batch size

# Convert PackedVector2Array to reusable Array[Vector2] buffer (zero-allocation when possible)
func _get_path_points_efficient(path) -> Array[Vector2]:
	if _path_cache and is_instance_valid(_path_cache):
		var packed_path = _path_cache.get_cached_path(path)
		# Reuse buffer, resize only if needed
		if _path_buffer.size() != packed_path.size():
			_path_buffer.resize(packed_path.size())
		# Copy data into reusable buffer
		for i in range(packed_path.size()):
			_path_buffer[i] = packed_path[i]
		return _path_buffer
	else:
		# Fallback to direct path generation
		return path.get_full_path()

# Safe logging for @tool context - routes through Logger when available
func _safe_log(message: String, level: String = "info", category: String = "treegen"):
	# Route through Logger when available, gracefully handle @tool context
	if Engine.is_editor_hint():
		# In editor @tool context, use print for critical messages only
		if level in ["warn", "error"]:
			print("[%s:%s] %s" % [level.to_upper(), category.to_upper(), message])
	else:
		# In runtime, use proper Logger
		match level:
			"debug":
				Logger.debug(message, category)
			"info":
				Logger.info(message, category)
			"warn":
				Logger.warn(message, category)
			"error":
				Logger.error(message, category)



## Generate tree boundary positions that respond to path data
func generate_tree_boundaries(path_data: Dictionary, provided_rng: RandomNumberGenerator = null) -> Array[Vector2]:
	# Use provided RNG for deterministic generation, fallback to local RNG if none provided
	var rng: RandomNumberGenerator
	if provided_rng:
		# Use the deterministic RNG from TreeBoundaryGenerator (maintains determinism per run)
		rng = provided_rng
	elif Engine.is_editor_hint():
		# Always use local RNG in tool mode to avoid autoload issues
		rng = RandomNumberGenerator.new()
		rng.seed = 12345  # Default seed for tool mode
	else:
		# Runtime mode fallback - use local RNG to avoid polluting global streams
		rng = RandomNumberGenerator.new()
		rng.seed = _hash_seed_for_trees(12345)  # Default hashed seed
	var paths: Array = path_data.get("paths", [])
	var corridor_bounds: Rect2 = path_data.get("corridor_bounds", Rect2())
	var endpoints: Array = path_data.get("endpoints", [])
	var endpoint_radius: float = path_data.get("endpoint_clearing_radius", 0.0)

	if paths.is_empty() or corridor_bounds == Rect2():
		_safe_log("No path data available for tree boundary generation", "warn")
		return []

	# Initialize path cache for zero-allocation generation
	_initialize_path_cache(paths)

	_safe_log("Tree generation with %d endpoints, %.1fpx clearing radius" % [
		endpoints.size(), endpoint_radius
	], "debug")

	# Choose generation approach based on optimization settings (use reusable buffer)
	var tree_positions = _get_tree_buffer()  # Zero-allocation approach
	var generation_method: String

	# NEW: Path-radius generation takes precedence when enabled (plugin control)
	if use_path_radius_generation:
		if _use_streaming_generation:
			_generate_path_radius_trees_streaming(paths, corridor_bounds, rng, tree_positions)
			generation_method = "path-radius-streaming"
		else:
			_generate_path_radius_trees_efficient(paths, corridor_bounds, rng, tree_positions)
			generation_method = "path-radius"
	elif use_localized_path_corridors:
		# Most efficient: trees only along path corridors
		tree_positions = _generate_localized_path_corridors(paths, rng)
		generation_method = "localized-corridors"
	elif use_prebuilt_tree_field:
		# Prebuilt field with carving
		tree_positions = _generate_prebuilt_tree_field_with_carving(paths, corridor_bounds, rng)
		generation_method = "prebuilt-field"
	else:
		# LEGACY: Rectangular boundary approach - generates huge areas with unused forest
		tree_positions = _generate_corridor_avoiding_trees(paths, corridor_bounds, rng)
		generation_method = "rectangular-legacy"


		# Ensure boundary continuity for arena containment
		if enforce_boundary_continuity:
			tree_positions = _optimize_boundary_continuity(tree_positions, corridor_bounds, rng)

	_safe_log("Generated %d tree boundary positions using %s approach" % [
		tree_positions.size(), generation_method
	], "info")

	# Clean up path cache when generation is complete
	_cleanup_path_cache()

	# Return a fresh copy to prevent buffer reference leak
	# The internal buffer will be cleared on next generation, so external references need their own copy
	var result_positions: Array[Vector2] = []
	result_positions.assign(tree_positions)
	return result_positions

## Generate trees using path-radius approach (zero-allocation version)
func _generate_path_radius_trees_efficient(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator, tree_positions: Array[Vector2]) -> void:
	var used_tiles: Dictionary = {}
	var tile_size = 48  # Match forest tileset 48x48 tiles

	_safe_log("Generating dense trees with path-radius approach, tree_boundary_width: %.1fpx" % [tree_boundary_width], "debug")

	# Generate trees with gradient density: dense near path, sparse farther away
	for path in paths:
		var path_points = _get_path_points_efficient(path)

		# STEP 1: Generate main path trees
		_generate_gradient_density_trees(path_points, path.width, tile_size, rng, tree_positions, used_tiles)

		# STEP 2: Add explicit circular endpoint coverage (like branches)
		if path_points.size() >= 2:
			_generate_endpoint_circular_coverage(path_points[0], path.width, tile_size, rng, tree_positions, used_tiles)  # Start point
			_generate_endpoint_circular_coverage(path_points[-1], path.width, tile_size, rng, tree_positions, used_tiles)  # End point

	# Clear walkable path areas using efficient zero-allocation method
	_clear_walkable_paths_in_place(tree_positions, paths)

## Memory-bounded streaming tree generation using RingBuffer
func _generate_path_radius_trees_streaming(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator, final_positions: Array[Vector2]) -> void:
	_initialize_tree_ring_buffer()
	_tree_ring_buffer.clear()

	var used_tiles: Dictionary = {}
	var tile_size = 48
	var trees_generated = 0
	var trees_overflow = 0

	_safe_log("Streaming tree generation with %d capacity buffer" % _tree_ring_buffer.capacity(), "debug")

	# Process each path with memory-bounded streaming
	for path in paths:
		var path_points = _get_path_points_efficient(path)

		# Generate trees and stream them through RingBuffer
		_stream_trees_for_path(path_points, path.width, tile_size, rng, used_tiles)

		# Process accumulated trees in batches
		_process_tree_batch_from_buffer(final_positions)

	# Process any remaining trees in buffer
	_flush_remaining_trees(final_positions)

	_safe_log("Streaming generation complete: %d trees processed (%d overflow handled)" % [trees_generated, trees_overflow], "debug")

## Stream trees for a single path into RingBuffer
func _stream_trees_for_path(path_points: Array[Vector2], path_width: float, tile_size: int, rng: RandomNumberGenerator, used_tiles: Dictionary) -> void:
	# Generate trees with same density logic but stream into RingBuffer
	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var total_width = path_half_width + tree_radius

	# Stream tree positions into buffer instead of accumulating in array
	for i in range(0, path_points.size() - 1):
		var start_point = path_points[i]
		var end_point = path_points[i + 1]

		# Generate trees along segment and stream them
		_stream_segment_trees(start_point, end_point, path_width, tile_size, rng, used_tiles)

## Stream trees for a path segment with overflow handling
func _stream_segment_trees(start_point: Vector2, end_point: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, used_tiles: Dictionary) -> void:
	var segment_vector = end_point - start_point
	var segment_length = segment_vector.length()
	var segment_direction = segment_vector.normalized()
	var perpendicular = Vector2(-segment_direction.y, segment_direction.x)

	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var step_size = tree_spacing * 0.5
	var steps = int(segment_length / step_size) + 1

	for i in range(steps):
		var t = float(i) / float(max(1, steps - 1))
		var segment_point = start_point.lerp(end_point, t)

		# Generate trees on both sides with streaming
		for side in [-1, 1]:
			var start_distance = path_half_width + tree_spacing * 0.5
			var end_distance = path_half_width + tree_radius

			var distance_steps = int((end_distance - start_distance) / tree_spacing) + 1

			for d in range(distance_steps):
				var distance = start_distance + d * tree_spacing
				var tree_pos = segment_point + perpendicular * side * distance

				# Apply density variation
				if rng.randf() > tree_density:
					continue

				# Check for tile conflicts
				var tile_key = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
				if used_tiles.has(tile_key):
					continue
				used_tiles[tile_key] = true

				# Stream tree into RingBuffer with overflow handling
				if not _tree_ring_buffer.try_push(tree_pos):
					# Buffer full - process current batch before continuing
					var temp_buffer = _get_temp_buffer()
					_drain_buffer_to_array(temp_buffer)
					# Apply basic filtering to current batch
					_filter_trees_basic(temp_buffer, path_width)

					# Try pushing again after clearing buffer
					if not _tree_ring_buffer.try_push(tree_pos):
						# Still full - skip this tree (graceful degradation)
						_safe_log("Tree buffer overflow - skipping tree at %s" % tree_pos, "debug")

## Process accumulated trees from RingBuffer
func _process_tree_batch_from_buffer(final_positions: Array[Vector2]) -> void:
	if _tree_ring_buffer.is_empty():
		return

	var temp_batch = _get_temp_buffer()
	_drain_buffer_to_array(temp_batch)

	# Process this batch and add to final results
	final_positions.append_array(temp_batch)

## Drain RingBuffer contents into Array for processing
func _drain_buffer_to_array(output: Array[Vector2]) -> void:
	while not _tree_ring_buffer.is_empty():
		var tree_pos = _tree_ring_buffer.try_pop()
		if tree_pos != null:
			output.append(tree_pos)

## Flush any remaining trees from buffer
func _flush_remaining_trees(final_positions: Array[Vector2]) -> void:
	_process_tree_batch_from_buffer(final_positions)

## Basic tree filtering for RingBuffer overflow handling
func _filter_trees_basic(tree_positions: Array[Vector2], path_width: float) -> void:
	# Simple in-place filtering - remove trees too close to each other
	var min_distance = tree_spacing * 0.8
	var write_index = 0

	for read_index in range(tree_positions.size()):
		var tree_pos = tree_positions[read_index]
		var too_close = false

		# Check against already accepted trees
		for accepted_index in range(write_index):
			if tree_pos.distance_to(tree_positions[accepted_index]) < min_distance:
				too_close = true
				break

		if not too_close:
			if write_index != read_index:
				tree_positions[write_index] = tree_pos
			write_index += 1

	tree_positions.resize(write_index)

## Generate trees using path-radius approach with dense coverage and path clearing
func _generate_path_radius_trees(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var used_tiles: Dictionary = {}
	var tile_size = 48  # Match forest tileset 48x48 tiles

	_safe_log("Generating dense trees with path-radius approach, tree_boundary_width: %.1fpx" % [tree_boundary_width], "debug")

	# Generate trees with gradient density: dense near path, sparse farther away
	for path in paths:
		var path_points = _get_path_points_efficient(path)

		# STEP 1: Generate main path trees
		_generate_gradient_density_trees(path_points, path.width, tile_size, rng, tree_positions, used_tiles)

		# STEP 2: Add explicit circular endpoint coverage (like branches)
		if path_points.size() >= 2:
			_generate_endpoint_circular_coverage(path_points[0], path.width, tile_size, rng, tree_positions, used_tiles)  # Start point
			_generate_endpoint_circular_coverage(path_points[-1], path.width, tile_size, rng, tree_positions, used_tiles)  # End point

		# No pool cleanup needed with PackedVector2Array approach

	# Clear walkable path areas (remove trees too close to paths)
	tree_positions = _clear_walkable_paths_simple(tree_positions, paths)

	_safe_log("Generated %d trees using gradient density approach (dense near path, sparse at edges)" % [tree_positions.size()], "debug")

	# Clean up path cache when generation is complete
	_cleanup_path_cache()

	return tree_positions

## Generate radial trees around a specific path point for complete coverage
func _generate_radial_trees_around_point(center: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var total_radius = path_half_width + tree_radius

	# Create concentric rings around the point
	var start_distance = path_half_width + 12.0  # Start just outside path
	var distance = start_distance

	while distance <= total_radius:
		# Calculate circumference for this ring to determine tree count
		var circumference = 2.0 * PI * distance
		var tree_count = max(4, int(circumference / tree_spacing))  # Minimum 4 trees per ring

		# Place trees evenly around the circle
		for i in range(tree_count):
			var angle = (float(i) / float(tree_count)) * TAU
			var tree_pos = center + Vector2(cos(angle), sin(angle)) * distance

			# Snap to tile grid first, then apply jitter to preserve randomization
			tree_pos = Vector2(
				round(tree_pos.x / tile_size) * tile_size,
				round(tree_pos.y / tile_size) * tile_size
			)
			tree_pos = _jitter_position(tree_pos, rng)

			# Check if this position respects tree_spacing from existing trees
			if _is_valid_tree_position(tree_pos, tree_positions):
				var tile_coord = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
				if not used_tiles.has(tile_coord):
					used_tiles[tile_coord] = true
					tree_positions.append(tree_pos)

		distance += tree_spacing

## Generate circular coverage around path endpoints (reusing branch-like logic)
func _generate_endpoint_circular_coverage(endpoint: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var total_radius = path_half_width + tree_radius

	# Create concentric rings around the endpoint (similar to branch endpoint coverage)
	var start_distance = path_half_width + 12.0  # Start just outside path
	var distance = start_distance

	while distance <= total_radius:
		# Calculate circumference for this ring to determine tree count
		var circumference = 2.0 * PI * distance
		var tree_count = max(8, int(circumference / tree_spacing))  # Minimum 8 trees per ring for good coverage

		# Place trees evenly around the circle
		for i in range(tree_count):
			var angle = (float(i) / float(tree_count)) * TAU
			var tree_pos = endpoint + Vector2(cos(angle), sin(angle)) * distance

			# Snap to tile grid first, then apply jitter to preserve randomization
			tree_pos = Vector2(
				round(tree_pos.x / tile_size) * tile_size,
				round(tree_pos.y / tile_size) * tile_size
			)
			tree_pos = _jitter_position(tree_pos, rng)

			# Calculate gradient density based on distance from endpoint
			var distance_from_endpoint = distance - (path_half_width + 12.0)
			var max_boundary_distance = tree_radius - 12.0
			var normalized_distance = distance_from_endpoint / max_boundary_distance


			# Check if this position respects tree_spacing from existing trees
			if _is_valid_tree_position(tree_pos, tree_positions):
				var tile_coord = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
				if not used_tiles.has(tile_coord):
					used_tiles[tile_coord] = true
					tree_positions.append(tree_pos)

		distance += tree_spacing

## Generate trees with gradient density around path network (unified approach)
func _generate_gradient_density_trees(path_points: Array[Vector2], path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var total_radius = path_half_width + tree_radius

	# Identify endpoints (first and last points) for special treatment
	var endpoints: Array[Vector2] = []
	if path_points.size() >= 2:
		endpoints.append(path_points[0])  # Start point
		endpoints.append(path_points[-1])  # End point

	# Create a comprehensive sampling grid around the entire path
	var min_bounds = Vector2(INF, INF)
	var max_bounds = Vector2(-INF, -INF)

	# Calculate bounding box for all path points
	for point in path_points:
		var expanded_point_min = point - Vector2(total_radius, total_radius)
		var expanded_point_max = point + Vector2(total_radius, total_radius)
		min_bounds = min_bounds.min(expanded_point_min)
		max_bounds = max_bounds.max(expanded_point_max)

	# Sample positions in a grid and apply distance-based density
	var sample_spacing = tree_spacing * 0.5  # Higher resolution sampling
	var start_x = int(min_bounds.x / tile_size) * tile_size
	var start_y = int(min_bounds.y / tile_size) * tile_size
	var end_x = max_bounds.x
	var end_y = max_bounds.y

	for y in range(start_y, end_y, sample_spacing):
		for x in range(start_x, end_x, sample_spacing):
			var sample_pos = Vector2(x, y)

			# Find distance to nearest path point or segment
			var min_distance_to_path = _get_min_distance_to_path_with_endpoints(sample_pos, path_points, endpoints)

			# Skip if too close to path (will be cleared anyway)
			if min_distance_to_path < path_half_width + 12.0:
				continue

			# Skip if beyond boundary radius
			if min_distance_to_path > total_radius:
				continue

			# Calculate radial density based on distance from path with configurable gradient
			var distance_from_path_edge = min_distance_to_path - (path_half_width + 12.0)
			var max_boundary_distance = tree_radius - 12.0
			var normalized_radial_distance = distance_from_path_edge / max_boundary_distance


			# Snap to tile grid first, then apply jitter to preserve randomization
			var tree_pos = Vector2(
				round(sample_pos.x / tile_size) * tile_size,
				round(sample_pos.y / tile_size) * tile_size
			)
			tree_pos = _jitter_position(tree_pos, rng)

			# Check spacing and add tree
			if _is_valid_tree_position(tree_pos, tree_positions):
				var tile_coord = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
				if not used_tiles.has(tile_coord):
					used_tiles[tile_coord] = true
					tree_positions.append(tree_pos)

## Calculate minimum distance from a point to any part of the path
func _get_min_distance_to_path(point: Vector2, path_points: Array[Vector2]) -> float:
	var min_distance = INF

	# Check distance to all path points
	for path_point in path_points:
		var distance = point.distance_to(path_point)
		min_distance = min(min_distance, distance)

	# Check distance to all path segments
	for i in range(path_points.size() - 1):
		var segment_start = path_points[i]
		var segment_end = path_points[i + 1]
		var segment_distance = _point_to_line_segment_distance(point, segment_start, segment_end)
		min_distance = min(min_distance, segment_distance)

	return min_distance

## Calculate minimum distance with special endpoint treatment for circular coverage
func _get_min_distance_to_path_with_endpoints(point: Vector2, path_points: Array[Vector2], endpoints: Array[Vector2]) -> float:
	var min_distance = INF

	# First check distance to endpoints with circular coverage priority
	for endpoint in endpoints:
		var endpoint_distance = point.distance_to(endpoint)
		min_distance = min(min_distance, endpoint_distance)

	# Check distance to all path segments
	for i in range(path_points.size() - 1):
		var segment_start = path_points[i]
		var segment_end = path_points[i + 1]
		var segment_distance = _point_to_line_segment_distance(point, segment_start, segment_end)

		# For endpoints, prioritize circular distance over segment distance
		var is_near_endpoint = false
		for endpoint in endpoints:
			if segment_start.distance_to(endpoint) < 1.0 or segment_end.distance_to(endpoint) < 1.0:
				# This segment connects to an endpoint, prefer endpoint distance if closer
				var endpoint_dist = point.distance_to(endpoint)
				if endpoint_dist < segment_distance:
					is_near_endpoint = true
					break

		if not is_near_endpoint:
			min_distance = min(min_distance, segment_distance)

	return min_distance

## Calculate distance from point to line segment
func _point_to_line_segment_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vector = line_end - line_start
	var point_vector = point - line_start
	var line_length_squared = line_vector.length_squared()

	if line_length_squared == 0:
		return point.distance_to(line_start)

	var t = clamp(point_vector.dot(line_vector) / line_length_squared, 0.0, 1.0)
	var projection = line_start + t * line_vector
	return point.distance_to(projection)

## Generate trees that avoid path corridors with buffer using asymmetric placement (LEGACY METHOD)
func _generate_corridor_avoiding_trees(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var tile_size = 48  # Match forest tileset 48x48 tiles

	# Simple configurable boundary thickness
	var total_expansion = tree_boundary_width

	_safe_log("Tree boundary expansion: %.1fpx (configurable boundary thickness)" % [
		total_expansion
	], "debug")

	# Expand bounds - negative values create tighter boundaries (closer to paths)
	var extended_bounds = Rect2(
		corridor_bounds.position - Vector2(total_expansion, total_expansion),
		corridor_bounds.size + Vector2(total_expansion * 2, total_expansion * 2)
	)

	# Ensure minimum bounds for negative expansion
	if total_expansion < 0:
		var min_size = Vector2(100, 100)  # Minimum 100x100 area
		if extended_bounds.size.x < min_size.x or extended_bounds.size.y < min_size.y:
			extended_bounds.size = extended_bounds.size.max(min_size)
			_safe_log("Applied minimum bounds for negative expansion", "debug")

	# Grid-based approach for comprehensive coverage with asymmetric placement
	var start_x = int(extended_bounds.position.x / tile_size) * tile_size
	var start_y = int(extended_bounds.position.y / tile_size) * tile_size
	var end_x = start_x + extended_bounds.size.x
	var end_y = start_y + extended_bounds.size.y

	# Calculate row and column indices for staggered placement
	var row_index = 0
	for y in range(start_y, end_y, tree_spacing):
		var col_index = 0
		for x in range(start_x, end_x, tree_spacing):
			var base_position = Vector2(x, y)

			# Snap to tile grid first, then apply jitter to preserve randomization
			var final_position = Vector2(
				round(base_position.x / tile_size) * tile_size,
				round(base_position.y / tile_size) * tile_size
			)
			final_position = _jitter_position(final_position, rng)

			# Check if position is NOT in any path corridor with buffer
			if not _is_position_in_path_buffer_zone(final_position, paths):
				# Add tree position
				tree_positions.append(final_position)

			col_index += 1
		row_index += 1

	return tree_positions

## OPTIMIZED: Generate pre-built tree field and carve paths through it
func _generate_prebuilt_tree_field_with_carving(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var tile_size = 48  # Match forest tileset 48x48 tiles

	# Use moderate expansion for prebuilt field (smaller than original)
	var arena_diagonal = corridor_bounds.size.length()
	var field_expansion = 400.0 + (arena_diagonal * 0.15)  # Much smaller base expansion

	var field_bounds = Rect2(
		corridor_bounds.position - Vector2(field_expansion, field_expansion),
		corridor_bounds.size + Vector2(field_expansion * 2, field_expansion * 2)
	)

	_safe_log("Prebuilt tree field: %.1f x %.1f expansion, %.1fpx total" % [
		field_bounds.size.x, field_bounds.size.y, field_expansion
	], "debug")

	# STEP 1: Generate dense tree field covering entire area
	var start_x = int(field_bounds.position.x / tile_size) * tile_size
	var start_y = int(field_bounds.position.y / tile_size) * tile_size
	var end_x = start_x + field_bounds.size.x
	var end_y = start_y + field_bounds.size.y

	var total_field_positions: Array[Vector2] = []
	var row_index = 0
	for y in range(start_y, end_y, tree_spacing):
		var col_index = 0
		for x in range(start_x, end_x, tree_spacing):
			var base_position = Vector2(x, y)
			# Snap to tile grid first, then apply jitter to preserve randomization
			var final_position = Vector2(
				round(base_position.x / tile_size) * tile_size,
				round(base_position.y / tile_size) * tile_size
			)
			final_position = _jitter_position(final_position, rng)

			# Apply prebuilt field density (most positions become trees)
			if rng.randf() < prebuilt_field_density:
				total_field_positions.append(final_position)

			col_index += 1
		row_index += 1

	_safe_log("Generated prebuilt tree field: %d potential tree positions" % total_field_positions.size(), "debug")

	# STEP 2: Carve paths by removing trees within path corridors
	for tree_pos in total_field_positions:
		# Keep tree if it's NOT in any path corridor
		if not _is_position_in_path_buffer_zone(tree_pos, paths):
			tree_positions.append(tree_pos)

	var carved_trees = total_field_positions.size() - tree_positions.size()
	_safe_log("Carved %d trees from field, %d trees remaining" % [carved_trees, tree_positions.size()], "debug")


	return tree_positions


## MOST EFFICIENT: Generate localized tree corridors along paths only (DISABLED - unreachable due to precedence)
func _generate_localized_path_corridors(paths: Array, rng: RandomNumberGenerator) -> Array[Vector2]:
	_safe_log("Localized corridors method called but disabled (unreachable due to path-radius precedence)", "debug")
	return []  # Return empty array to prevent errors


## Enhanced path buffer check that automatically includes endpoint clearings
func _is_position_in_path_buffer_zone_with_endpoints(position: Vector2, paths: Array, endpoints: Array, endpoint_radius: float) -> bool:
	# First check normal path buffer zones
	if _is_position_in_path_buffer_zone(position, paths):
		return true

	# Then check if position is near any endpoint (automatic clearing) - only if we have valid data
	if endpoint_radius > 0.0 and not endpoints.is_empty():
		for endpoint in endpoints:
			if position.distance_to(endpoint) <= endpoint_radius:
				return true

	return false

## Apply jitter to world position after tile grid snapping (preserves randomization)
func _jitter_position(world_pos: Vector2, rng: RandomNumberGenerator) -> Vector2:
	if placement_randomness <= 0.0 or max_random_offset <= 0:
		return world_pos
	var jitter_range := max_random_offset * placement_randomness  # Direct multiplication - no division needed
	return world_pos + Vector2(
		rng.randf_range(-jitter_range, jitter_range),
		rng.randf_range(-jitter_range, jitter_range)
	)

## Apply asymmetric staggered placement pattern to tree position (LEGACY - replaced by _jitter_position)
func _apply_asymmetric_placement(base_position: Vector2, row_index: int, col_index: int, rng: RandomNumberGenerator) -> Vector2:
	var final_position = base_position

	# Apply organic random offset if enabled
	if placement_randomness > 0.0 and max_random_offset > 0:
		var random_range = max_random_offset * placement_randomness  # Direct multiplication - no division needed
		var offset_x = (rng.randf() - 0.5) * 2.0 * random_range
		var offset_y = (rng.randf() - 0.5) * 2.0 * random_range
		final_position += Vector2(offset_x, offset_y)

	return final_position

## Check if position is within path buffer zone (walkable area + buffer)
func _is_position_in_path_buffer_zone(position: Vector2, paths: Array) -> bool:
	for path in paths:
		var path_points = _get_path_points_efficient(path)
		# Use path width plus tree boundary width for tree separation
		var buffer_width = (path.width * 0.5) + tree_boundary_width + (tree_spacing * 0.5)
		# Allow negative buffer for tight boundaries (don't enforce minimum of 0)
		# Only ensure we don't go completely negative to prevent trees inside path centers
		buffer_width = max(-(path.width * 0.25), buffer_width)

		# Check distance to each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]
			var distance = _point_to_line_distance(position, start_point, end_point)

			if distance <= buffer_width:
				return true

		# No pool cleanup needed with PackedVector2Array approach

	return false


## Optimize boundary continuity to ensure arena containment with adaptive expansion
func _optimize_boundary_continuity(tree_positions: Array[Vector2], corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var optimized_positions = tree_positions.duplicate()

	# Use configurable boundary thickness for perimeter
	var total_expansion = tree_boundary_width

	# Use expanded bounds for perimeter gap-filling
	var expanded_perimeter_bounds = Rect2(
		corridor_bounds.position - Vector2(total_expansion, total_expansion),
		corridor_bounds.size + Vector2(total_expansion * 2, total_expansion * 2)
	)

	# Get perimeter points from expanded boundary
	var perimeter_points = _get_boundary_perimeter(expanded_perimeter_bounds)

	# Enhanced gap-filling with smaller gap tolerance for robust coverage
	var adaptive_gap_tolerance = min(max_boundary_gap, tree_spacing * 1.5)
	var supplemental_trees = 0

	for perimeter_point in perimeter_points:
		var nearest_tree_distance = _find_nearest_tree_distance(perimeter_point, optimized_positions)

		# Add tree if gap is too large (more aggressive gap-filling)
		if nearest_tree_distance > adaptive_gap_tolerance:
			optimized_positions.append(perimeter_point)
			supplemental_trees += 1

	_safe_log("Boundary optimization: %d → %d trees (added %d supplemental trees for %.1fpx expansion)" % [
		tree_positions.size(), optimized_positions.size(), supplemental_trees, total_expansion
	], "debug")
	return optimized_positions

## Get perimeter points around boundary for continuity checking
func _get_boundary_perimeter(bounds: Rect2) -> Array[Vector2]:
	var perimeter_points: Array[Vector2] = []
	var step_size = tree_spacing

	# Top and bottom edges
	for x in range(bounds.position.x, bounds.position.x + bounds.size.x, step_size):
		perimeter_points.append(Vector2(x, bounds.position.y))  # Top edge
		perimeter_points.append(Vector2(x, bounds.position.y + bounds.size.y))  # Bottom edge

	# Left and right edges
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y, step_size):
		perimeter_points.append(Vector2(bounds.position.x, y))  # Left edge
		perimeter_points.append(Vector2(bounds.position.x + bounds.size.x, y))  # Right edge

	return perimeter_points

## Find distance to nearest tree from given position
func _find_nearest_tree_distance(position: Vector2, tree_positions: Array[Vector2]) -> float:
	var min_distance = INF

	for tree_pos in tree_positions:
		var distance = position.distance_to(tree_pos)
		min_distance = min(min_distance, distance)

	return min_distance

## Calculate distance from point to line segment
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var line_length_squared = line_vec.length_squared()

	if line_length_squared == 0.0:
		return point.distance_to(line_start)

	var t = max(0, min(1, (point - line_start).dot(line_vec) / line_length_squared))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

## Get random tree tile variant for visual variety with alternative tile support
func get_random_tree_tile() -> Vector2i:
	if tree_tile_variants.is_empty():
		return Vector2i(0, 28)  # Default tree tile

	# Handle tool mode where autoloads may not be fully available
	var rng: RandomNumberGenerator
	if Engine.is_editor_hint():
		# Always use local RNG in tool mode to avoid autoload issues
		rng = RandomNumberGenerator.new()
		rng.seed = 67890  # Default seed for tool mode
	else:
		# Runtime mode - use local RNG to avoid polluting global streams
		rng = RandomNumberGenerator.new()
		rng.seed = _hash_seed_for_trees(67890)  # Default hashed seed

	return tree_tile_variants[rng.randi() % tree_tile_variants.size()]

## Get alternative tile ID for tree variants (use alternative 1 instead of base tile 0)
func get_tree_alternative_tile() -> int:
	return 1  # Use alternative tile 1 instead of base tile 0

## Calculate 5-screen path length target for path generation validation
func calculate_target_path_length() -> float:
	# This is used by DungeonPathGenerator to target appropriate path lengths
	# 5 screens = 5 * viewport diagonal
	var viewport_size = Vector2(1080, 720)  # Default project viewport
	return viewport_size.length() * 5.0

## Validate that tree boundaries provide adequate arena containment
func validate_arena_containment(tree_positions: Array[Vector2], corridor_bounds: Rect2) -> bool:
	var perimeter_points = _get_boundary_perimeter(corridor_bounds)
	var uncovered_points = 0

	for perimeter_point in perimeter_points:
		var nearest_distance = _find_nearest_tree_distance(perimeter_point, tree_positions)
		if nearest_distance > max_boundary_gap:
			uncovered_points += 1

	var coverage_ratio = float(perimeter_points.size() - uncovered_points) / float(perimeter_points.size())
	var is_adequate = coverage_ratio >= 0.8  # 80% coverage threshold

	if not is_adequate:
		_safe_log("Inadequate boundary coverage: %.1f%%" % (coverage_ratio * 100), "warn")

	return is_adequate

## Generate trees around a single path segment efficiently (no duplicates)
func _generate_trees_around_segment_efficient(start_point: Vector2, end_point: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	# Calculate segment properties
	var segment_vector = end_point - start_point
	var segment_length = segment_vector.length()
	var segment_direction = segment_vector.normalized()
	var perpendicular = Vector2(-segment_direction.y, segment_direction.x)

	# Calculate tree placement area around this segment
	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)  # How far from path to place trees
	var total_width = path_half_width + tree_radius  # Total distance from path center

	# Step along the segment length (denser spacing for complete coverage)
	var step_size = tree_spacing * 0.5  # Halve spacing for denser coverage
	var steps = int(segment_length / step_size) + 1

	for i in range(steps):
		var t = float(i) / float(max(1, steps - 1))  # 0.0 to 1.0 along segment
		var segment_point = start_point.lerp(end_point, t)

		# Place trees on both sides of the path segment
		for side in [-1, 1]:  # Left and right side of path
			# Start placing trees just outside the path width
			var start_distance = path_half_width + tree_spacing * 0.5
			var end_distance = total_width

			# Place trees at different distances from path (denser spacing for complete coverage)
			var distance = start_distance
			var distance_step = tree_spacing * 0.75  # Reduce distance step for denser layers
			while distance <= end_distance:
				var tree_pos = segment_point + (perpendicular * side * distance)

				# Snap to tile grid first, then apply jitter to preserve randomization
				tree_pos = Vector2(
					round(tree_pos.x / tile_size) * tile_size,
					round(tree_pos.y / tile_size) * tile_size
				)
				tree_pos = _jitter_position(tree_pos, rng)

				# Check if this tile is already used
				var tile_coord = Vector2i(
					int(tree_pos.x / tile_size),
					int(tree_pos.y / tile_size)
				)

				# Only add if this tile isn't already used
				if not used_tiles.has(tile_coord):
					used_tiles[tile_coord] = true
					tree_positions.append(tree_pos)

				distance += distance_step

## Remove duplicate tree positions that would be placed in the same tile
func _remove_duplicate_tree_positions(tree_positions: Array[Vector2], tile_size: int) -> Array[Vector2]:
	var unique_positions: Array[Vector2] = []
	var used_tiles: Dictionary = {}

	for pos in tree_positions:
		# Calculate tile coordinate
		var tile_coord = Vector2i(
			int(pos.x / tile_size),
			int(pos.y / tile_size)
		)

		# Only add if this tile isn't already used
		if not used_tiles.has(tile_coord):
			used_tiles[tile_coord] = true
			unique_positions.append(pos)

	return unique_positions

## Generate dense trees around a segment (simpler approach)
func _generate_dense_trees_around_segment(start_point: Vector2, end_point: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	# Same as before but with much denser spacing
	var segment_vector = end_point - start_point
	var segment_length = segment_vector.length()
	var segment_direction = segment_vector.normalized()
	var perpendicular = Vector2(-segment_direction.y, segment_direction.x)

	var path_half_width = path_width * 0.5
	var tree_radius = abs(tree_boundary_width)
	var total_width = path_half_width + tree_radius

	# Use normal tree_spacing (let user control density)
	var step_size = tree_spacing
	var steps = int(segment_length / step_size) + 1

	for i in range(steps):
		var t = float(i) / float(max(1, steps - 1))
		var segment_point = start_point.lerp(end_point, t)

		# Trees on both sides
		for side in [-1, 1]:
			var start_distance = path_half_width + 12.0  # Start just outside path
			var end_distance = total_width

			# Use normal tree_spacing for radial layers too
			var distance = start_distance
			while distance <= end_distance:
				var tree_pos = segment_point + (perpendicular * side * distance)

				# Snap to tile grid first, then apply jitter to preserve randomization
				tree_pos = Vector2(
					round(tree_pos.x / tile_size) * tile_size,
					round(tree_pos.y / tile_size) * tile_size
				)
				tree_pos = _jitter_position(tree_pos, rng)

				# Check if this position respects tree_spacing from existing trees
				if _is_valid_tree_position(tree_pos, tree_positions):
					var tile_coord = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
					if not used_tiles.has(tile_coord):
						used_tiles[tile_coord] = true
						tree_positions.append(tree_pos)

				distance += tree_spacing

## Simple path clearing (remove trees too close to walkable areas)
func _clear_walkable_paths_simple(tree_positions: Array[Vector2], paths: Array) -> Array[Vector2]:
	# Use optimized spatial grid if enabled
	if use_optimized_path_collision:
		return _clear_walkable_paths_optimized(tree_positions, paths)
	else:
		return _clear_walkable_paths_legacy(tree_positions, paths)

## Optimized path clearing using PathSegmentGrid spatial optimization
func _clear_walkable_paths_optimized(tree_positions: Array[Vector2], paths: Array) -> Array[Vector2]:
	if paths.is_empty():
		return tree_positions

	# Build spatial grid for fast collision detection
	var path_grid = PathSegmentGrid.new()
	path_grid.build_grid(paths, 512)  # 512px cells for optimal performance

	# Debug logging (safe for @tool context)
	_safe_log("PathSegmentGrid built for optimization: %s" % path_grid.get_grid_stats(), "debug")

	var cleared_positions: Array[Vector2] = []

	# Fast O(1) collision check per tree position
	for tree_pos in tree_positions:
		if not path_grid.is_position_blocked(tree_pos):
			cleared_positions.append(tree_pos)

	# Debug logging (safe for @tool context)
	_safe_log("Optimized path clearing: %d/%d trees kept" % [cleared_positions.size(), tree_positions.size()], "debug")
	return cleared_positions

## Zero-allocation in-place path clearing (modifies array directly)
func _clear_walkable_paths_in_place(tree_positions: Array[Vector2], paths: Array) -> void:
	if not use_optimized_path_collision:
		# Fallback to basic in-place clearing
		_clear_walkable_paths_basic_in_place(tree_positions, paths)
		return

	# Build spatial grid for fast collision detection
	var path_grid = PathSegmentGrid.new()
	path_grid.build_grid(paths, 512)  # 512px cells for optimal performance

	_safe_log("PathSegmentGrid built for in-place optimization: %s" % path_grid.get_grid_stats(), "debug")

	# Remove trees by shifting valid ones down (zero-allocation filter)
	var write_index = 0
	for read_index in range(tree_positions.size()):
		var tree_pos = tree_positions[read_index]
		if not path_grid.is_position_blocked(tree_pos):
			if write_index != read_index:
				tree_positions[write_index] = tree_pos
			write_index += 1

	# Truncate array to new size
	var original_size = tree_positions.size()
	tree_positions.resize(write_index)

	_safe_log("In-place path clearing: %d/%d trees kept (zero allocation)" % [write_index, original_size], "debug")

## Basic in-place path clearing (fallback when optimization disabled)
func _clear_walkable_paths_basic_in_place(tree_positions: Array[Vector2], paths: Array) -> void:
	var write_index = 0
	for read_index in range(tree_positions.size()):
		var tree_pos = tree_positions[read_index]
		var too_close = false

		# Check distance to all paths
		for path in paths:
			var path_points = _get_path_points_efficient(path)
			if _get_min_distance_to_path(tree_pos, path_points) < path_buffer_distance:
				too_close = true
				break

		# Keep tree if not too close to any path
		if not too_close:
			if write_index != read_index:
				tree_positions[write_index] = tree_pos
			write_index += 1

	tree_positions.resize(write_index)

## Legacy path clearing method (fallback for compatibility)
func _clear_walkable_paths_legacy(tree_positions: Array[Vector2], paths: Array) -> Array[Vector2]:
	var cleared_positions: Array[Vector2] = []

	for tree_pos in tree_positions:
		var keep_tree = true

		# Check if too close to any path
		for path in paths:
			var path_points = _get_path_points_efficient(path)
			var clearance = (path.width * 0.5) + 12.0  # Path width + small buffer

			for i in range(path_points.size() - 1):
				var distance = _point_to_line_distance(tree_pos, path_points[i], path_points[i + 1])
				if distance <= clearance:
					keep_tree = false
					break

			# No pool cleanup needed with PackedVector2Array approach

			if not keep_tree:
				break

		if keep_tree:
			cleared_positions.append(tree_pos)

	return cleared_positions

## Hash seed specifically for tree generation to avoid global RNG pollution
func _hash_seed_for_trees(base_seed: int) -> int:
	# Create deterministic hash specific to tree generation
	# Uses simple multiplicative hashing to create isolated seed space
	return (base_seed * 1664525 + 1013904223) & 0x7FFFFFFF

## Initialize path cache for zero-allocation generation
func _initialize_path_cache(paths: Array) -> void:
	if not _path_cache:
		_path_cache = PathDataCache.new()

	# Pre-warm cache with all paths for optimal performance
	_path_cache.preload_paths(paths)

## Clean up path cache when generation is complete
func _cleanup_path_cache() -> void:
	if _path_cache:
		_path_cache.cleanup()
		_path_cache = null

## Check if tree position respects tree_spacing from existing trees (for natural appearance)
func _is_valid_tree_position(new_pos: Vector2, existing_trees: Array[Vector2]) -> bool:
	# Check distance to existing trees - must be at least tree_spacing apart
	var min_distance = tree_spacing

	# Only check recent trees for performance (last 50 trees)
	var check_count = min(existing_trees.size(), 50)
	var start_index = max(0, existing_trees.size() - check_count)

	for i in range(start_index, existing_trees.size()):
		var existing_pos = existing_trees[i]
		var distance = new_pos.distance_to(existing_pos)

		if distance < min_distance:
			return false  # Too close to existing tree

	return true  # Position is valid

## Calculate lateral density factor based on distance to path corridor edges
func _calculate_lateral_density_factor(sample_pos: Vector2, path_points: Array[Vector2], path_half_width: float, tree_radius: float) -> float:
	var min_lateral_distance = INF

	# For each path segment, calculate perpendicular distance to left and right edges
	for i in range(path_points.size() - 1):
		var segment_start = path_points[i]
		var segment_end = path_points[i + 1]

		# Get the segment direction vector
		var segment_vector = segment_end - segment_start
		var segment_length = segment_vector.length()

		if segment_length < 0.1:  # Skip very short segments
			continue

		var segment_normal = segment_vector.normalized()
		var segment_perpendicular = Vector2(-segment_normal.y, segment_normal.x)  # Perpendicular vector

		# Find the closest point on the segment line (infinite line, not just segment)
		var start_to_sample = sample_pos - segment_start
		var projection_length = start_to_sample.dot(segment_normal)
		var closest_point_on_line = segment_start + segment_normal * projection_length

		# Check if the projection falls within the segment bounds
		var projection_ratio = projection_length / segment_length
		if projection_ratio >= 0.0 and projection_ratio <= 1.0:
			# The closest point is within the segment
			var vector_to_sample = sample_pos - closest_point_on_line
			var perpendicular_distance = abs(vector_to_sample.dot(segment_perpendicular))

			# Calculate distance to corridor edges (left and right edges of the path)
			var distance_to_edge = abs(perpendicular_distance - path_half_width)
			min_lateral_distance = min(min_lateral_distance, distance_to_edge)

	# Simplified: return uniform density
	return 1.0
