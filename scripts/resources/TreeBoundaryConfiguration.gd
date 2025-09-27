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

@export_group("Boundary Adaptation")
## Additional buffer around paths before placing trees (pixels)
@export_range(24, 96, 4) var path_buffer_distance: float = 48.0

## Distance of tree boundaries away from paths (pixels) - negative values allow tree overlap
@export_range(-999999, 999999, 24) var boundary_distance: float = 96.0

## How much to extend tree boundaries beyond path network (tiles)
@export_range(5, 50, 5) var boundary_extension: int = 20

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

@export_group("Debug Visualization")
## Show tree boundary preview
@export var debug_show_tree_boundaries: bool = false

## Show path buffer zones
@export var debug_show_path_buffers: bool = false

## Generate tree boundary positions that respond to path data
func generate_tree_boundaries(path_data: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2]:
	var paths: Array = path_data.get("paths", [])
	var corridor_bounds: Rect2 = path_data.get("corridor_bounds", Rect2())

	if paths.is_empty() or corridor_bounds == Rect2():
		Logger.warn("No path data available for tree boundary generation", "treegen")
		return []

	# Generate comprehensive tree coverage avoiding path corridors (base paths only)
	var tree_positions = _generate_corridor_avoiding_trees(paths, corridor_bounds, rng)

	# Apply natural clustering if enabled
	if enable_natural_clustering:
		tree_positions = _apply_natural_clustering(tree_positions, rng)

	# Ensure boundary continuity for arena containment
	if enforce_boundary_continuity:
		tree_positions = _optimize_boundary_continuity(tree_positions, corridor_bounds, rng)

	Logger.info("Generated %d tree boundary positions" % tree_positions.size(), "treegen")
	return tree_positions

## Generate trees that avoid path corridors with buffer using asymmetric placement
func _generate_corridor_avoiding_trees(paths: Array, corridor_bounds: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	var tile_size = 48  # Match forest tileset 48x48 tiles

	# Adaptive expansion based on arena size and network complexity
	var arena_diagonal = corridor_bounds.size.length()
	var network_complexity_factor = min(paths.size() / 3.0, 2.0)  # Scale with path count, cap at 2x

	# Reduced expansion: 800px base + 25% arena + 15% network scaling (much more reasonable)
	var base_expansion = 800.0
	var arena_scaling = arena_diagonal * 0.25
	var network_scaling = arena_diagonal * 0.15 * network_complexity_factor
	var total_expansion = base_expansion + arena_scaling + network_scaling

	Logger.debug("Tree boundary expansion: %.1fpx (base: %.1f + arena: %.1f + network: %.1f)" % [
		total_expansion, base_expansion, arena_scaling, network_scaling
	], "treegen")

	# Expand bounds for full coverage with adaptive scaling
	var extended_bounds = Rect2(
		corridor_bounds.position - Vector2(total_expansion, total_expansion),
		corridor_bounds.size + Vector2(total_expansion * 2, total_expansion * 2)
	)

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

			# Check if position is NOT in any path corridor with buffer (base paths only)
			if not _is_position_in_path_buffer_zone(final_position, paths):
				# Apply basic density filter
				if rng.randf() < tree_density:
					tree_positions.append(final_position)

			col_index += 1
		row_index += 1

	return tree_positions

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
		# Use path width plus configurable boundary distance for tree separation
		# Combine boundary distance with tree spacing for controlled spacing
		# Negative boundary_distance allows trees to overlap paths
		var buffer_width = (path.width * 0.5) + boundary_distance + (tree_spacing * 0.5)
		# Ensure minimum buffer of 0 to prevent unexpected behavior
		buffer_width = max(0.0, buffer_width)

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

	# Calculate adaptive expansion for perimeter (same as tree generation)
	var arena_diagonal = corridor_bounds.size.length()
	var base_expansion = 800.0
	var arena_scaling = arena_diagonal * 0.25
	var network_scaling = arena_diagonal * 0.15  # Simplified for perimeter
	var total_expansion = base_expansion + arena_scaling + network_scaling

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

## Get random tree tile variant for visual variety
func get_random_tree_tile(rng: RandomNumberGenerator) -> Vector2i:
	if tree_tile_variants.is_empty():
		return Vector2i(0, 28)  # Default tree tile

	return tree_tile_variants[rng.randi() % tree_tile_variants.size()]

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
