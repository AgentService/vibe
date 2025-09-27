@tool
class_name TreeBoundaryConfiguration
extends Resource

## Tree boundary configuration that responds to path data for natural arena containment
## Implements "Path Drives → Boundary Responds" principle

@export_group("Tree Placement")
## Tree tile variants to use for boundary trees
@export var tree_tile_variants: Array[Vector2i] = [Vector2i(0, 28), Vector2i(9, 28)]

## Tree spacing between boundary trees (pixels) - reduced for better coverage
@export_range(16, 64, 4) var tree_spacing: float = 25.0

## Tree density along boundaries (higher for robust coverage)
@export_range(0.5, 1.0, 0.05) var tree_density: float = 0.95

@export_group("Gradient Density Control")
## Minimum baseline density near paths (always maintained, even in sparse areas)
@export_range(0.01, 1.0, 0.01) var min_density_near_path: float = 0.01

## Maximum density near paths (1.0 = full density, 0.5 = half density, <0.3 = very sparse)
@export_range(0.05, 1.0, 0.05) var max_density_near_path: float = 0.05

## Minimum density at boundary edges (0.1 = sparse, 0.5 = moderate, >1.0 = super dense)
@export_range(0.05, 50.0, 0.05) var min_density_at_edges: float = 50.0

## Density falloff curve (1.0 = linear, 2.0 = steep falloff, 0.5 = gentle, <0.1 = very gentle)
@export_range(0.01, 3.0, 0.01) var density_falloff_curve: float = 0.013

@export_group("Boundary Adaptation")
## Additional buffer around paths before placing trees (pixels)
@export_range(24, 96, 4) var path_buffer_distance: float = 48.0

## Distance of tree boundaries away from paths (pixels) - negative values allow tree overlap
@export_range(-999999, 999999, 24) var boundary_distance: float = 96.0

## How much to extend tree boundaries beyond path network (tiles)
@export_range(5, 50, 5) var boundary_extension: int = 20

## Base tree boundary thickness (pixels) - controls outer tree space around paths
@export_range(25, 200, 25) var boundary_thickness: float = 75.0

## Use efficient path-radius generation (only trees around paths, no huge rectangles)
@export var use_path_radius_generation: bool = true

@export_group("Natural Clustering")
## Enable Perlin noise for realistic tree clustering
@export var enable_natural_clustering: bool = true

## Noise scale for tree clustering (larger = more spread out clusters)
@export_range(0.01, 0.2, 0.01) var clustering_noise_scale: float = 0.05

## Noise threshold for tree placement (higher = fewer trees)
@export_range(-1.0, 1.0, 0.1) var clustering_threshold: float = 0.2

@export_group("Asymmetric Placement")
## Enable staggered placement for natural asymmetric pattern
@export var enable_staggered_placement: bool = true

## Placement randomness factor (0=perfect grid, 1=high variation)
@export_range(0.0, 1.0, 0.1) var placement_randomness: float = 0.3

## Maximum random offset in pixels for asymmetric placement
@export_range(0, 32, 2) var max_random_offset: float = 8.0

@export_group("Boundary Optimization")
## Ensure trees form continuous boundary for arena containment
@export var enforce_boundary_continuity: bool = true

## Maximum gap allowed in tree boundary (pixels)
@export_range(16, 64, 8) var max_boundary_gap: float = 48.0

@export_group("Performance Optimization")
## Use pre-built tree field approach (much faster)
@export var use_prebuilt_tree_field: bool = true

## Tree field density for pre-generation (lower = more trees)
@export_range(0.3, 0.9, 0.1) var prebuilt_field_density: float = 0.7

## Use localized path corridors instead of full arena coverage (most efficient)
@export var use_localized_path_corridors: bool = false

## Width of tree corridors along paths (pixels from path edge)
@export_range(100, 500, 25) var corridor_tree_width: float = 200.0

## Extra corridor extension at path endpoints for visual closure
@export_range(50, 200, 25) var endpoint_extension: float = 100.0

@export_group("Debug Visualization")
## Show tree boundary preview
@export var debug_show_tree_boundaries: bool = false

## Show path buffer zones
@export var debug_show_path_buffers: bool = false

## Generate tree boundary positions that respond to path data
func generate_tree_boundaries(path_data: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2]:
	var paths: Array = path_data.get("paths", [])
	var corridor_bounds: Rect2 = path_data.get("corridor_bounds", Rect2())
	var endpoints: Array = path_data.get("endpoints", [])
	var endpoint_radius: float = path_data.get("endpoint_clearing_radius", 0.0)

	if paths.is_empty() or corridor_bounds == Rect2():
		Logger.warn("No path data available for tree boundary generation", "treegen")
		return []

	Logger.debug("Tree generation with %d endpoints, %.1fpx clearing radius" % [
		endpoints.size(), endpoint_radius
	], "treegen")

	# Choose generation approach based on optimization settings
	var tree_positions: Array[Vector2]
	var generation_method: String

	# NEW: Path-radius generation takes precedence when enabled (plugin control)
	if use_path_radius_generation:
		tree_positions = _generate_path_radius_trees(paths, corridor_bounds, rng)
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

		# Apply natural clustering if enabled
		if enable_natural_clustering:
			tree_positions = _apply_natural_clustering(tree_positions, rng)

		# Ensure boundary continuity for arena containment
		if enforce_boundary_continuity:
			tree_positions = _optimize_boundary_continuity(tree_positions, corridor_bounds, rng)

	Logger.info("Generated %d tree boundary positions using %s approach" % [
		tree_positions.size(), generation_method
	], "treegen")
	return tree_positions

## Generate trees using path-radius approach with dense coverage and path clearing
func _generate_path_radius_trees(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var used_tiles: Dictionary = {}
	var tile_size = 48  # Match forest tileset 48x48 tiles

	Logger.debug("Generating dense trees with path-radius approach, boundary_thickness: %.1fpx" % [boundary_thickness], "treegen")

	# Generate trees with gradient density: dense near path, sparse farther away
	for path in paths:
		var path_points: Array[Vector2] = path.get_full_path()

		# STEP 1: Generate main path trees
		_generate_gradient_density_trees(path_points, path.width, tile_size, rng, tree_positions, used_tiles)

		# STEP 2: Add explicit circular endpoint coverage (like branches)
		if path_points.size() >= 2:
			_generate_endpoint_circular_coverage(path_points[0], path.width, tile_size, rng, tree_positions, used_tiles)  # Start point
			_generate_endpoint_circular_coverage(path_points[-1], path.width, tile_size, rng, tree_positions, used_tiles)  # End point

	# Clear walkable path areas (remove trees too close to paths)
	tree_positions = _clear_walkable_paths_simple(tree_positions, paths)

	Logger.debug("Generated %d trees using gradient density approach (dense near path, sparse at edges)" % [tree_positions.size()], "treegen")
	return tree_positions

## Generate radial trees around a specific path point for complete coverage
func _generate_radial_trees_around_point(center: Vector2, path_width: float, tile_size: int, rng: RandomNumberGenerator, tree_positions: Array[Vector2], used_tiles: Dictionary) -> void:
	var path_half_width = path_width * 0.5
	var tree_radius = abs(boundary_thickness)
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

			# Add random offset for natural placement (zigzag effect)
			var random_offset = Vector2.ZERO
			if enable_staggered_placement:
				random_offset = Vector2(
					rng.randf_range(-max_random_offset, max_random_offset),
					rng.randf_range(-max_random_offset, max_random_offset)
				)

			# Snap to tile grid with random offset
			tree_pos = Vector2(
				round((tree_pos.x + random_offset.x) / tile_size) * tile_size,
				round((tree_pos.y + random_offset.y) / tile_size) * tile_size
			)

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
	var tree_radius = abs(boundary_thickness)
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

			# Add random offset for natural placement (zigzag effect)
			var random_offset = Vector2.ZERO
			if enable_staggered_placement:
				random_offset = Vector2(
					rng.randf_range(-max_random_offset, max_random_offset),
					rng.randf_range(-max_random_offset, max_random_offset)
				)

			# Snap to tile grid with random offset
			tree_pos = Vector2(
				round((tree_pos.x + random_offset.x) / tile_size) * tile_size,
				round((tree_pos.y + random_offset.y) / tile_size) * tile_size
			)

			# Calculate gradient density based on distance from endpoint
			var distance_from_endpoint = distance - (path_half_width + 12.0)
			var max_boundary_distance = tree_radius - 12.0
			var normalized_distance = distance_from_endpoint / max_boundary_distance

			# Apply configurable density curve with three-point gradient
			var curve_factor = pow(1.0 - normalized_distance, density_falloff_curve)
			# Calculate density using three-point gradient for endpoints
			var density_factor: float
			if normalized_distance <= 0.5:
				# Near endpoint area: interpolate from min_density_near_path to max_density_near_path
				var near_curve = curve_factor * 2.0
				density_factor = lerp(min_density_near_path, max_density_near_path, near_curve)
			else:
				# Far from endpoint area: interpolate from max_density_near_path to min_density_at_edges
				var far_curve = (curve_factor - 0.5) * 2.0
				if min_density_at_edges <= max_density_near_path:
					# Normal case: dense near path, sparse at edges
					density_factor = lerp(max_density_near_path, min_density_at_edges, 1.0 - far_curve)
				else:
					# Inverted case: sparse near path, dense at edges
					density_factor = lerp(max_density_near_path, min_density_at_edges, far_curve)
			density_factor = clamp(density_factor, min(min_density_near_path, min_density_at_edges), max(max_density_near_path, min_density_at_edges))

			# Apply density probability
			if rng.randf() > density_factor * tree_density:
				continue

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
	var tree_radius = abs(boundary_thickness)
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

			# Apply configurable density curve for radial falloff with three-point gradient
			var radial_curve_factor = pow(1.0 - normalized_radial_distance, density_falloff_curve)
			# Calculate density using three-point gradient: min_near → max_near → edges
			var radial_density_factor: float
			if normalized_radial_distance <= 0.5:
				# Near path area: interpolate from min_density_near_path to max_density_near_path
				var near_curve = radial_curve_factor * 2.0  # Stretch curve for near area
				radial_density_factor = lerp(min_density_near_path, max_density_near_path, near_curve)
			else:
				# Far from path area: interpolate from max_density_near_path to min_density_at_edges
				var far_curve = (radial_curve_factor - 0.5) * 2.0  # Stretch curve for far area
				if min_density_at_edges <= max_density_near_path:
					# Normal case: dense near path, sparse at edges
					radial_density_factor = lerp(max_density_near_path, min_density_at_edges, 1.0 - far_curve)
				else:
					# Inverted case: sparse near path, dense at edges
					radial_density_factor = lerp(max_density_near_path, min_density_at_edges, far_curve)


			# Calculate lateral density based on distance to path corridor edges
			var lateral_density_factor = _calculate_lateral_density_factor(sample_pos, path_points, path_half_width, tree_radius)

			# Combine radial and lateral density factors (take minimum for conservative approach)
			var combined_density_factor = min(radial_density_factor, lateral_density_factor)
			combined_density_factor = clamp(combined_density_factor, min_density_at_edges, max_density_near_path)

			# Apply density probability
			if rng.randf() > combined_density_factor * tree_density:
				continue

			# Add random offset for natural placement (zigzag effect)
			var random_offset = Vector2.ZERO
			if enable_staggered_placement:
				random_offset = Vector2(
					rng.randf_range(-max_random_offset, max_random_offset),
					rng.randf_range(-max_random_offset, max_random_offset)
				)

			# Snap to tile grid with random offset
			var tree_pos = Vector2(
				round((sample_pos.x + random_offset.x) / tile_size) * tile_size,
				round((sample_pos.y + random_offset.y) / tile_size) * tile_size
			)

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
	var total_expansion = boundary_thickness

	Logger.debug("Tree boundary expansion: %.1fpx (configurable boundary thickness)" % [
		total_expansion
	], "treegen")

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
			Logger.debug("Applied minimum bounds for negative expansion", "treegen")

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

			# Apply asymmetric staggered placement pattern
			var final_position = _apply_asymmetric_placement(base_position, row_index, col_index, rng)

			# Check if position is NOT in any path corridor with buffer
			if not _is_position_in_path_buffer_zone(final_position, paths):
				# Apply basic density filter
				if rng.randf() < tree_density:
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

	Logger.debug("Prebuilt tree field: %.1f x %.1f expansion, %.1fpx total" % [
		field_bounds.size.x, field_bounds.size.y, field_expansion
	], "treegen")

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
			var final_position = _apply_asymmetric_placement(base_position, row_index, col_index, rng)

			# Apply prebuilt field density (most positions become trees)
			if rng.randf() < prebuilt_field_density:
				total_field_positions.append(final_position)

			col_index += 1
		row_index += 1

	Logger.debug("Generated prebuilt tree field: %d potential tree positions" % total_field_positions.size(), "treegen")

	# STEP 2: Carve paths by removing trees within path corridors
	for tree_pos in total_field_positions:
		# Keep tree if it's NOT in any path corridor
		if not _is_position_in_path_buffer_zone(tree_pos, paths):
			tree_positions.append(tree_pos)

	var carved_trees = total_field_positions.size() - tree_positions.size()
	Logger.debug("Carved %d trees from field, %d trees remaining" % [carved_trees, tree_positions.size()], "treegen")

	# STEP 3: Optional clustering (but less aggressive since field is pre-dense)
	if enable_natural_clustering:
		var original_count = tree_positions.size()
		tree_positions = _apply_light_clustering(tree_positions, rng)
		Logger.debug("Light clustering: %d → %d trees" % [original_count, tree_positions.size()], "treegen")

	return tree_positions

## Apply light clustering for prebuilt fields (less aggressive than full clustering)
func _apply_light_clustering(tree_positions: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var clustered_positions: Array[Vector2] = []
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = clustering_noise_scale * 0.5  # Reduced frequency for lighter effect

	# Use more permissive threshold for prebuilt fields
	var light_threshold = clustering_threshold - 0.3

	for position in tree_positions:
		var noise_value = noise.get_noise_2d(position.x, position.y)

		if noise_value > light_threshold:
			clustered_positions.append(position)

	return clustered_positions

## MOST EFFICIENT: Generate localized tree corridors along paths only
func _generate_localized_path_corridors(paths: Array, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var tile_size = 48

	Logger.debug("Generating localized corridors: %d paths, %.1fpx width, %.1fpx endpoint extension" % [
		paths.size(), corridor_tree_width, endpoint_extension
	], "treegen")

	for path in paths:
		var path_points = path.get_full_path()

		# Generate trees along each path segment
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]
			var segment_trees = _generate_trees_along_segment(start_point, end_point, rng)
			tree_positions.append_array(segment_trees)

		# Add endpoint extensions for visual closure
		if path_points.size() >= 2:
			var first_point = path_points[0]
			var last_point = path_points[-1]

			# Extension at start
			var start_extension = _generate_endpoint_extension(first_point, path_points[1], true, rng)
			tree_positions.append_array(start_extension)

			# Extension at end
			var end_extension = _generate_endpoint_extension(last_point, path_points[-2], false, rng)
			tree_positions.append_array(end_extension)

	Logger.debug("Generated %d trees across %d localized path corridors" % [
		tree_positions.size(), paths.size()
	], "treegen")

	return tree_positions

## Generate trees along a single path segment
func _generate_trees_along_segment(start: Vector2, end: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var segment_trees: Array[Vector2] = []
	var segment_direction = (end - start).normalized()
	var perpendicular = Vector2(-segment_direction.y, segment_direction.x)
	var segment_length = start.distance_to(end)

	# Sample points along the segment
	var step_size = tree_spacing * 0.8  # Slightly denser for good coverage
	var num_steps = int(segment_length / step_size)

	for step in range(num_steps + 1):
		var t = float(step) / max(1, num_steps)
		var segment_point = start.lerp(end, t)

		# Place trees on both sides of the path
		for side in [-1, 1]:
			# Multiple tree rows for corridor depth
			for row in range(1, int(corridor_tree_width / tree_spacing) + 1):
				var tree_distance = (64.0 * 0.5) + (row * tree_spacing)  # Use default path width
				var tree_pos = segment_point + (perpendicular * side * tree_distance)

				# Add natural variation
				if placement_randomness > 0.0:
					var random_offset = Vector2(
						(rng.randf() - 0.5) * max_random_offset * placement_randomness,
						(rng.randf() - 0.5) * max_random_offset * placement_randomness
					)
					tree_pos += random_offset

				# Apply density filter
				if rng.randf() < tree_density:
					segment_trees.append(tree_pos)

	return segment_trees

## Generate trees at path endpoints for visual closure
func _generate_endpoint_extension(endpoint: Vector2, adjacent_point: Vector2, is_start: bool, rng: RandomNumberGenerator) -> Array[Vector2]:
	var extension_trees: Array[Vector2] = []
	var direction_to_path = (adjacent_point - endpoint).normalized()
	var back_direction = -direction_to_path
	var perpendicular = Vector2(-direction_to_path.y, direction_to_path.x)

	# Create semi-circular extension behind the endpoint
	var extension_center = endpoint + (back_direction * endpoint_extension * 0.5)
	var extension_radius = endpoint_extension

	# Grid-based semicircle generation
	for x_offset in range(-int(extension_radius / tree_spacing), int(extension_radius / tree_spacing) + 1):
		for y_offset in range(-int(extension_radius / tree_spacing), int(extension_radius / tree_spacing) + 1):
			var local_pos = Vector2(x_offset * tree_spacing, y_offset * tree_spacing)
			var world_pos = extension_center + local_pos

			# Check if within extension radius and behind the endpoint
			var dist_to_center = local_pos.length()
			var dot_product = (world_pos - endpoint).dot(back_direction)

			if dist_to_center <= extension_radius and dot_product > 0:
				# Apply gradient density with three-point gradient for endpoints
				var distance_from_endpoint = dist_to_center
				var normalized_distance = distance_from_endpoint / extension_radius
				var curve_factor = pow(1.0 - normalized_distance, density_falloff_curve)
				# Calculate endpoint density using three-point gradient
				var endpoint_density: float
				if normalized_distance <= 0.5:
					# Near endpoint area: interpolate from min_density_near_path to max_density_near_path
					var near_curve = curve_factor * 2.0
					endpoint_density = lerp(min_density_near_path, max_density_near_path, near_curve)
				else:
					# Far from endpoint area: interpolate from max_density_near_path to min_density_at_edges
					var far_curve = (curve_factor - 0.5) * 2.0
					if min_density_at_edges <= max_density_near_path:
						# Normal case: dense near path, sparse at edges
						endpoint_density = lerp(max_density_near_path, min_density_at_edges, 1.0 - far_curve)
					else:
						# Inverted case: sparse near path, dense at edges
						endpoint_density = lerp(max_density_near_path, min_density_at_edges, far_curve)
				endpoint_density = clamp(endpoint_density, min(min_density_near_path, min_density_at_edges), max(max_density_near_path, min_density_at_edges))

				if rng.randf() < endpoint_density * tree_density:
					var random_offset = Vector2(
						(rng.randf() - 0.5) * max_random_offset,
						(rng.randf() - 0.5) * max_random_offset
					)
					extension_trees.append(world_pos + random_offset)

	return extension_trees

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

## Apply asymmetric staggered placement pattern to tree position
func _apply_asymmetric_placement(base_position: Vector2, row_index: int, col_index: int, rng: RandomNumberGenerator) -> Vector2:
	var final_position = base_position

	# Apply staggered placement offset (net-like pattern)
	if enable_staggered_placement and (row_index % 2 == 1):
		# Offset every other row by half spacing for staggered pattern
		final_position.x += tree_spacing * 0.5

	# Apply random offset for natural variation
	if placement_randomness > 0.0:
		var random_range = max_random_offset * placement_randomness
		final_position.x += (rng.randf() - 0.5) * 2.0 * random_range
		final_position.y += (rng.randf() - 0.5) * 2.0 * random_range

	return final_position

## Check if position is within path buffer zone (walkable area + buffer)
func _is_position_in_path_buffer_zone(position: Vector2, paths: Array) -> bool:
	for path in paths:
		var path_points: Array[Vector2] = path.get_full_path()
		# Use path width plus configurable boundary thickness for tree separation
		# boundary_thickness controls both expansion area AND tree-to-path distance
		# Negative boundary_thickness allows trees to be placed closer to paths
		var buffer_width = (path.width * 0.5) + boundary_thickness + (tree_spacing * 0.5)
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

	return false

## Apply Perlin noise for natural tree clustering
func _apply_natural_clustering(tree_positions: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var clustered_positions: Array[Vector2] = []
	var noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = clustering_noise_scale

	for position in tree_positions:
		var noise_value = noise.get_noise_2d(position.x, position.y)

		# Only keep trees where noise exceeds threshold
		if noise_value > clustering_threshold:
			clustered_positions.append(position)

	Logger.debug("Applied clustering: %d → %d trees" % [tree_positions.size(), clustered_positions.size()], "treegen")
	return clustered_positions

## Optimize boundary continuity to ensure arena containment with adaptive expansion
func _optimize_boundary_continuity(tree_positions: Array[Vector2], corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var optimized_positions = tree_positions.duplicate()

	# Use configurable boundary thickness for perimeter
	var total_expansion = boundary_thickness

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

	Logger.debug("Boundary optimization: %d → %d trees (added %d supplemental trees for %.1fpx expansion)" % [
		tree_positions.size(), optimized_positions.size(), supplemental_trees, total_expansion
	], "treegen")
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
func get_random_tree_tile(rng: RandomNumberGenerator) -> Vector2i:
	if tree_tile_variants.is_empty():
		return Vector2i(0, 28)  # Default tree tile

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
		Logger.warn("Inadequate boundary coverage: %.1f%%" % (coverage_ratio * 100), "treegen")

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
	var tree_radius = abs(boundary_thickness)  # How far from path to place trees
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

				# Add random offset for natural placement (zigzag effect)
				var random_offset = Vector2.ZERO
				if enable_staggered_placement:
					random_offset = Vector2(
						rng.randf_range(-max_random_offset, max_random_offset),
						rng.randf_range(-max_random_offset, max_random_offset)
					)

				# Snap to tile grid with random offset
				tree_pos = Vector2(
					round((tree_pos.x + random_offset.x) / tile_size) * tile_size,
					round((tree_pos.y + random_offset.y) / tile_size) * tile_size
				)

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
	var tree_radius = abs(boundary_thickness)
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

				# Add random offset for natural placement (zigzag effect)
				var random_offset = Vector2.ZERO
				if enable_staggered_placement:
					random_offset = Vector2(
						rng.randf_range(-max_random_offset, max_random_offset),
						rng.randf_range(-max_random_offset, max_random_offset)
					)

				# Snap to tile grid with random offset
				tree_pos = Vector2(
					round((tree_pos.x + random_offset.x) / tile_size) * tile_size,
					round((tree_pos.y + random_offset.y) / tile_size) * tile_size
				)

				# Check if this position respects tree_spacing from existing trees
				if _is_valid_tree_position(tree_pos, tree_positions):
					var tile_coord = Vector2i(int(tree_pos.x / tile_size), int(tree_pos.y / tile_size))
					if not used_tiles.has(tile_coord):
						used_tiles[tile_coord] = true
						tree_positions.append(tree_pos)

				distance += tree_spacing

## Simple path clearing (remove trees too close to walkable areas)
func _clear_walkable_paths_simple(tree_positions: Array[Vector2], paths: Array) -> Array[Vector2]:
	var cleared_positions: Array[Vector2] = []

	for tree_pos in tree_positions:
		var keep_tree = true

		# Check if too close to any path
		for path in paths:
			var path_points: Array[Vector2] = path.get_full_path()
			var clearance = (path.width * 0.5) + 12.0  # Path width + small buffer

			for i in range(path_points.size() - 1):
				var distance = _point_to_line_distance(tree_pos, path_points[i], path_points[i + 1])
				if distance <= clearance:
					keep_tree = false
					break

			if not keep_tree:
				break

		if keep_tree:
			cleared_positions.append(tree_pos)

	return cleared_positions

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

	# If no valid segments found, return max density (no lateral fading)
	if min_lateral_distance == INF:
		return max_density_near_path

	# Calculate lateral density based on distance to nearest corridor edge
	var lateral_fade_distance = tree_radius * 0.5  # Use half the tree radius for lateral fading
	var normalized_lateral_distance = min_lateral_distance / lateral_fade_distance

	# Apply density curve with three-point gradient for lateral fading
	var lateral_curve_factor = pow(1.0 - clamp(normalized_lateral_distance, 0.0, 1.0), density_falloff_curve)
	# Calculate lateral density using three-point gradient
	var lateral_density: float
	if normalized_lateral_distance <= 0.5:
		# Near corridor edge: interpolate from min_density_near_path to max_density_near_path
		var near_curve = lateral_curve_factor * 2.0
		lateral_density = lerp(min_density_near_path, max_density_near_path, near_curve)
	else:
		# Far from corridor edge: interpolate from max_density_near_path to min_density_at_edges
		var far_curve = (lateral_curve_factor - 0.5) * 2.0
		if min_density_at_edges <= max_density_near_path:
			# Normal case: dense near path, sparse at edges
			lateral_density = lerp(max_density_near_path, min_density_at_edges, 1.0 - far_curve)
		else:
			# Inverted case: sparse near path, dense at edges
			lateral_density = lerp(max_density_near_path, min_density_at_edges, far_curve)

	return clamp(lateral_density, min(min_density_near_path, min_density_at_edges), max(max_density_near_path, min_density_at_edges))
