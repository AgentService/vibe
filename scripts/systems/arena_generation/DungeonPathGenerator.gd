@tool
extends Node
class_name DungeonPathGenerator

## Dedicated path generation system focusing on 5-screen walkable routes
## Implements clean path generation with deterministic seeding and performance optimization

@export_group("Configuration")
@export var path_config: PathConfiguration

@export_group("Performance Monitoring")
@export var target_generation_time_ms: float = 2.0
@export var log_performance_metrics: bool = true

# Generation state
var current_path_data: Dictionary = {}
var rng: RandomNumberGenerator
var generation_seed: int

## Generate path network with 5-screen target length
func generate_dungeon_paths(seed: int) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	generation_seed = seed

	# Initialize deterministic RNG
	rng = RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Validate configuration
	if not path_config:
		Logger.warn("No PathConfiguration assigned, creating default", "pathgen")
		path_config = PathConfiguration.new()

	if not path_config.enable_path_generation:
		Logger.info("Path generation disabled", "pathgen")
		return {"paths": [], "points": [], "corridor_bounds": Rect2(), "target_length": 0.0}

	# Calculate 5-screen target path length
	var target_length = _calculate_5_screen_target_length()

	# Generate path network
	current_path_data = path_config.generate_path_network(rng)
	current_path_data["target_length"] = target_length
	current_path_data["generation_seed"] = generation_seed

	# Validate path length against target
	var actual_length = _calculate_total_path_length(current_path_data.get("paths", []))
	var length_ratio = actual_length / target_length if target_length > 0 else 0.0

	# Performance and quality metrics
	var elapsed_time = Time.get_ticks_msec() - start_time
	_log_generation_metrics(elapsed_time, actual_length, target_length, length_ratio)

	# Verify performance target
	if elapsed_time > target_generation_time_ms:
		Logger.warn("Path generation exceeded target time: %.1fms > %.1fms" % [elapsed_time, target_generation_time_ms], "performance")

	Logger.info("Generated path network: %.1f/%.1f length (%.1f%%), %d paths, %.1fms" % [
		actual_length, target_length, length_ratio * 100,
		current_path_data.get("paths", []).size(), elapsed_time
	], "pathgen")

	return current_path_data

## Calculate 5-screen target path length based on viewport
func _calculate_5_screen_target_length() -> float:
	# Get viewport size from project settings or use default
	var viewport_size = Vector2(1080, 720)  # Default from project.godot

	# Try to get actual viewport if available
	if Engine.is_editor_hint():
		# In editor, use project settings
		var width = ProjectSettings.get_setting("display/window/size/viewport_width", 1080)
		var height = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
		viewport_size = Vector2(width, height)
	else:
		# At runtime, get actual viewport
		var viewport = get_viewport()
		if viewport:
			viewport_size = viewport.get_visible_rect().size

	# 5 screens = 5 * diagonal length
	var target_length = viewport_size.length() * 5.0

	Logger.debug("5-screen target calculation: %s viewport → %.1f length" % [viewport_size, target_length], "pathgen")
	return target_length

## Calculate total length of all path segments
func _calculate_total_path_length(paths: Array) -> float:
	var total_length = 0.0

	for path in paths:
		if path.has_method("get_full_path"):
			var path_points: Array[Vector2] = path.get_full_path()

			# Sum segment lengths
			for i in range(path_points.size() - 1):
				var segment_length = path_points[i].distance_to(path_points[i + 1])
				total_length += segment_length

	return total_length

## Get generated path data for external systems
func get_current_path_data() -> Dictionary:
	return current_path_data

## Get ground corridor positions for tile generation
func get_ground_positions() -> Array[Vector2]:
	if not path_config or current_path_data.is_empty():
		return []

	var paths: Array = current_path_data.get("paths", [])
	var corridor_bounds: Rect2 = current_path_data.get("corridor_bounds", Rect2())

	if paths.is_empty():
		return []

	return path_config.get_ground_corridor_positions(paths, corridor_bounds)

## Check if position is within walkable corridors
func is_position_walkable(position: Vector2) -> bool:
	if not path_config or current_path_data.is_empty():
		return false

	var paths: Array = current_path_data.get("paths", [])
	return path_config.is_position_in_walkable_corridor(position, paths)

## Generate with new random seed (for UI testing)
func generate_with_new_seed() -> Dictionary:
	var new_seed = randi()
	return generate_dungeon_paths(new_seed)

## Log comprehensive generation metrics
func _log_generation_metrics(elapsed_ms: float, actual_length: float, target_length: float, length_ratio: float) -> void:
	if not log_performance_metrics:
		return

	# Performance metrics
	Logger.debug("Path generation performance: %.1fms (target: %.1fms)" % [elapsed_ms, target_generation_time_ms], "performance")

	# Quality metrics
	var length_status = "✓" if length_ratio >= 0.9 and length_ratio <= 1.1 else "⚠"
	Logger.debug("Path length quality %s: %.1f/%.1f (%.1f%%)" % [length_status, actual_length, target_length, length_ratio * 100], "pathgen")

	# Path network metrics
	var paths: Array = current_path_data.get("paths", [])
	var points: Array = current_path_data.get("points", [])
	Logger.debug("Path network: %d paths, %d connection points" % [paths.size(), points.size()], "pathgen")

	# Configuration summary
	if path_config:
		Logger.debug("Config: width=%.1f, variation=%s, waypoints=%s" % [
			path_config.path_width,
			"✓" if path_config.enable_path_variation else "✗",
			"✓" if path_config.add_intermediate_waypoints else "✗"
		], "pathgen")

## Validate path generation quality
func validate_path_quality() -> Dictionary:
	var validation = {
		"is_valid": false,
		"length_ratio": 0.0,
		"connectivity_check": false,
		"performance_check": false,
		"issues": []
	}

	if current_path_data.is_empty():
		validation.issues.append("No path data available")
		return validation

	var paths: Array = current_path_data.get("paths", [])
	var target_length: float = current_path_data.get("target_length", 0.0)

	# Length validation
	var actual_length = _calculate_total_path_length(paths)
	validation.length_ratio = actual_length / target_length if target_length > 0 else 0.0
	var length_ok = validation.length_ratio >= 0.9 and validation.length_ratio <= 1.1

	if not length_ok:
		validation.issues.append("Path length %.1f%% of target" % (validation.length_ratio * 100))

	# Connectivity validation
	validation.connectivity_check = _validate_path_connectivity(paths)
	if not validation.connectivity_check:
		validation.issues.append("Path connectivity issues detected")

	# Performance validation (placeholder - would need timing data)
	validation.performance_check = true  # Assume OK for now

	validation.is_valid = length_ok and validation.connectivity_check and validation.performance_check

	if validation.is_valid:
		Logger.info("Path validation passed: length %.1f%%, connectivity ✓" % (validation.length_ratio * 100), "pathgen")
	else:
		Logger.warn("Path validation failed: %s" % ", ".join(validation.issues), "pathgen")

	return validation

## Validate that all paths form connected network
func _validate_path_connectivity(paths: Array) -> bool:
	if paths.is_empty():
		return false

	# For single chain topology, check that paths form sequence
	var connection_points: Dictionary = {}

	# Collect all connection points
	for path in paths:
		if path.has_method("get_full_path"):
			var path_points = path.get_full_path()
			if path_points.size() >= 2:
				var start_pos = path_points[0]
				var end_pos = path_points[-1]

				connection_points[start_pos] = connection_points.get(start_pos, 0) + 1
				connection_points[end_pos] = connection_points.get(end_pos, 0) + 1

	# For linear chain: should have 2 endpoints (count=1) and N-2 intermediate points (count=2)
	var endpoint_count = 0
	var intermediate_count = 0

	for point in connection_points:
		var count = connection_points[point]
		if count == 1:
			endpoint_count += 1
		elif count == 2:
			intermediate_count += 1

	# Valid chain: exactly 2 endpoints
	var is_valid_chain = endpoint_count == 2

	if not is_valid_chain:
		Logger.debug("Connectivity validation: %d endpoints, %d intermediate (expected: 2 endpoints)" % [endpoint_count, intermediate_count], "pathgen")

	return is_valid_chain

## Get debug information for visualization
func get_debug_info() -> Dictionary:
	var debug_info = {
		"generation_seed": generation_seed,
		"path_count": 0,
		"point_count": 0,
		"total_length": 0.0,
		"target_length": 0.0,
		"corridor_bounds": Rect2(),
		"config_summary": {}
	}

	if not current_path_data.is_empty():
		var paths: Array = current_path_data.get("paths", [])
		var points: Array = current_path_data.get("points", [])

		debug_info.path_count = paths.size()
		debug_info.point_count = points.size()
		debug_info.total_length = _calculate_total_path_length(paths)
		debug_info.target_length = current_path_data.get("target_length", 0.0)
		debug_info.corridor_bounds = current_path_data.get("corridor_bounds", Rect2())

	if path_config:
		debug_info.config_summary = {
			"path_width": path_config.path_width,
			"enable_variation": path_config.enable_path_variation,
			"add_waypoints": path_config.add_intermediate_waypoints,
			"waypoint_probability": path_config.waypoint_probability
		}

	return debug_info
