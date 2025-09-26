@tool
extends Node
class_name TreeBoundaryGenerator

## Tree boundary generation system that responds to path data for natural arena containment
## Implements "Path Drives → Boundary Responds" principle with intelligent adaptation

@export_group("Configuration")
@export var tree_config: TreeBoundaryConfiguration

@export_group("Performance Monitoring")
@export var target_generation_time_ms: float = 3.0
@export var log_performance_metrics: bool = true

# Generation state
var current_tree_data: Dictionary = {}
var current_path_data: Dictionary = {}
var current_extension_data: Dictionary = {}
var rng: RandomNumberGenerator
var generation_seed: int

## Generate tree boundaries that respond to path data
func generate_tree_boundaries(path_data: Dictionary, seed: int, extension_data: Dictionary = {}) -> Array[Vector2]:
	var start_time = Time.get_ticks_msec()
	generation_seed = seed
	current_path_data = path_data

	# Store extension data for proper boundary calculations around complete visual area
	current_extension_data = extension_data

	# Initialize deterministic RNG
	rng = RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Validate configuration
	if not tree_config:
		Logger.warn("No TreeBoundaryConfiguration assigned, creating default", "treegen")
		tree_config = TreeBoundaryConfiguration.new()

	# Validate path data input
	if not _validate_path_data(path_data):
		Logger.warn("Invalid path data provided for tree boundary generation", "treegen")
		return []

	# Generate tree boundaries using configuration (trees avoid only base path corridors)
	var tree_positions = tree_config.generate_tree_boundaries(path_data, rng)

	# Validate boundary quality (trees should only avoid base path corridors)
	var validation_result = _validate_boundary_quality(tree_positions, path_data)

	# Store generation results
	current_tree_data = {
		"tree_positions": tree_positions,
		"generation_seed": generation_seed,
		"path_data": path_data,
		"validation": validation_result
	}

	# Performance monitoring
	var elapsed_time = Time.get_ticks_msec() - start_time
	_log_generation_metrics(elapsed_time, tree_positions.size(), validation_result)

	# Verify performance target
	if elapsed_time > target_generation_time_ms:
		Logger.warn("Tree generation exceeded target time: %.1fms > %.1fms" % [elapsed_time, target_generation_time_ms], "performance")

	return tree_positions

## Validate that path data contains required information
func _validate_path_data(path_data: Dictionary) -> bool:
	var required_keys = ["paths", "corridor_bounds"]

	for key in required_keys:
		if not path_data.has(key):
			Logger.warn("Path data missing required key: %s" % key, "treegen")
			return false

	var paths: Array = path_data.get("paths", [])
	var corridor_bounds: Rect2 = path_data.get("corridor_bounds", Rect2())

	if paths.is_empty():
		Logger.warn("Path data contains no paths", "treegen")
		return false

	if corridor_bounds == Rect2():
		Logger.warn("Path data contains invalid corridor bounds", "treegen")
		return false

	return true

## Validate boundary generation quality
func _validate_boundary_quality(tree_positions: Array[Vector2], path_data: Dictionary) -> Dictionary:
	var validation = {
		"is_adequate": false,
		"coverage_ratio": 0.0,
		"containment_check": false,
		"path_avoidance_check": false,
		"issues": []
	}

	if tree_positions.is_empty():
		validation.issues.append("No tree positions generated")
		return validation

	var corridor_bounds: Rect2 = path_data.get("corridor_bounds", Rect2())

	# Validate arena containment coverage
	if tree_config and tree_config.validate_arena_containment(tree_positions, corridor_bounds):
		validation.containment_check = true
		validation.coverage_ratio = _calculate_boundary_coverage(tree_positions, corridor_bounds)
	else:
		validation.issues.append("Inadequate arena containment")

	# Validate path corridor avoidance (base path only, not extensions)
	var path_avoidance_ok = _validate_path_avoidance(tree_positions, path_data.get("paths", []))
	validation.path_avoidance_check = path_avoidance_ok
	if not path_avoidance_ok:
		validation.issues.append("Trees placed in path corridors")

	validation.is_adequate = validation.containment_check and validation.path_avoidance_check

	return validation

## Calculate boundary coverage ratio
func _calculate_boundary_coverage(tree_positions: Array[Vector2], corridor_bounds: Rect2) -> float:
	if tree_positions.is_empty() or corridor_bounds == Rect2():
		return 0.0

	# Create perimeter points for coverage analysis
	var perimeter_points = _get_boundary_perimeter(corridor_bounds)
	var covered_points = 0
	var max_gap = tree_config.max_boundary_gap if tree_config else 48.0

	for perimeter_point in perimeter_points:
		var nearest_distance = _find_nearest_tree_distance(perimeter_point, tree_positions)
		if nearest_distance <= max_gap:
			covered_points += 1

	return float(covered_points) / float(perimeter_points.size()) if perimeter_points.size() > 0 else 0.0

## Get perimeter points for coverage analysis
func _get_boundary_perimeter(bounds: Rect2) -> Array[Vector2]:
	var perimeter_points: Array[Vector2] = []
	var step_size = tree_config.tree_spacing if tree_config else 32.0

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

## Validate that trees avoid path corridors (base paths only)
func _validate_path_avoidance(tree_positions: Array[Vector2], paths: Array) -> bool:
	if not tree_config:
		return true  # Skip validation if no config

	var violations = 0
	var total_trees = tree_positions.size()

	for tree_pos in tree_positions:
		if tree_config._is_position_in_path_buffer_zone(tree_pos, paths):
			violations += 1

	var violation_ratio = float(violations) / float(total_trees) if total_trees > 0 else 0.0
	var is_acceptable = violation_ratio <= 0.05  # Allow up to 5% violations due to edge cases

	if not is_acceptable:
		Logger.warn("Path avoidance violations: %d/%d trees (%.1f%%)" % [violations, total_trees, violation_ratio * 100], "treegen")

	return is_acceptable

## Get random tree tile for placement
func get_random_tree_tile() -> Vector2i:
	if tree_config:
		return tree_config.get_random_tree_tile(rng)
	else:
		return Vector2i(0, 28)  # Default tree tile

## Generate with new random seed (for UI testing)
func generate_with_new_seed(path_data: Dictionary) -> Array[Vector2]:
	var new_seed = randi()
	return generate_tree_boundaries(path_data, new_seed)

## Get current tree generation data
func get_current_tree_data() -> Dictionary:
	return current_tree_data

## Check if position has tree placement
func has_tree_at_position(position: Vector2, tolerance: float = 16.0) -> bool:
	var tree_positions: Array[Vector2] = current_tree_data.get("tree_positions", [])

	for tree_pos in tree_positions:
		if position.distance_to(tree_pos) <= tolerance:
			return true

	return false

## Get trees within radius of position
func get_trees_in_radius(center: Vector2, radius: float) -> Array[Vector2]:
	var nearby_trees: Array[Vector2] = []
	var tree_positions: Array[Vector2] = current_tree_data.get("tree_positions", [])

	for tree_pos in tree_positions:
		if center.distance_to(tree_pos) <= radius:
			nearby_trees.append(tree_pos)

	return nearby_trees

## Log comprehensive generation metrics
func _log_generation_metrics(elapsed_ms: float, tree_count: int, validation_result: Dictionary) -> void:
	if not log_performance_metrics:
		return

	# Performance metrics
	Logger.debug("Tree generation performance: %.1fms (target: %.1fms)" % [elapsed_ms, target_generation_time_ms], "performance")

	# Quality metrics
	var coverage_ratio = validation_result.get("coverage_ratio", 0.0)
	var coverage_status = "✓" if coverage_ratio >= 0.8 else "⚠"
	Logger.debug("Boundary coverage %s: %.1f%%" % [coverage_status, coverage_ratio * 100], "treegen")

	# Tree placement metrics
	Logger.debug("Tree placement: %d trees generated" % tree_count, "treegen")

	# Validation summary
	var containment_ok = validation_result.get("containment_check", false)
	var avoidance_ok = validation_result.get("path_avoidance_check", false)
	Logger.debug("Validation: containment=%s, path_avoidance=%s" % [
		"✓" if containment_ok else "✗",
		"✓" if avoidance_ok else "✗"
	], "treegen")

	# Configuration summary
	if tree_config:
		Logger.debug("Config: spacing=%.1f, density=%.2f, clustering=%s" % [
			tree_config.tree_spacing,
			tree_config.tree_density,
			"✓" if tree_config.enable_natural_clustering else "✗"
		], "treegen")

## Get comprehensive debug information
func get_debug_info() -> Dictionary:
	var debug_info = {
		"generation_seed": generation_seed,
		"tree_count": 0,
		"path_data_received": false,
		"corridor_bounds": Rect2(),
		"validation_result": {},
		"config_summary": {}
	}

	if not current_tree_data.is_empty():
		var tree_positions: Array[Vector2] = current_tree_data.get("tree_positions", [])
		debug_info.tree_count = tree_positions.size()
		debug_info.validation_result = current_tree_data.get("validation", {})

	if not current_path_data.is_empty():
		debug_info.path_data_received = true
		debug_info.corridor_bounds = current_path_data.get("corridor_bounds", Rect2())

	if tree_config:
		debug_info.config_summary = {
			"tree_spacing": tree_config.tree_spacing,
			"tree_density": tree_config.tree_density,
			"path_buffer_distance": tree_config.path_buffer_distance,
			"enable_clustering": tree_config.enable_natural_clustering,
			"enforce_continuity": tree_config.enforce_boundary_continuity
		}

	return debug_info

## Validate tree boundary generation system
func validate_system_health() -> Dictionary:
	var health = {
		"is_healthy": false,
		"configuration_check": false,
		"path_data_check": false,
		"generation_check": false,
		"issues": []
	}

	# Configuration validation
	if tree_config:
		health.configuration_check = true
	else:
		health.issues.append("No TreeBoundaryConfiguration assigned")

	# Path data validation
	if not current_path_data.is_empty() and _validate_path_data(current_path_data):
		health.path_data_check = true
	else:
		health.issues.append("Invalid or missing path data")

	# Generation validation
	if not current_tree_data.is_empty():
		var validation_result = current_tree_data.get("validation", {})
		if validation_result.get("is_adequate", false):
			health.generation_check = true
		else:
			var issues = validation_result.get("issues", [])
			health.issues.append("Generation quality issues: " + ", ".join(issues))
	else:
		health.issues.append("No tree generation data available")

	health.is_healthy = health.configuration_check and health.path_data_check and health.generation_check

	if health.is_healthy:
		Logger.info("TreeBoundaryGenerator system health: ✓", "treegen")
	else:
		Logger.warn("TreeBoundaryGenerator system health issues: %s" % ", ".join(health.issues), "treegen")

	return health
