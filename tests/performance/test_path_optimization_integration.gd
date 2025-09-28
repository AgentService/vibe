@tool
extends SceneTree

## A/B integration test for PathSegmentGrid optimization in TreeBoundaryConfiguration
## Validates accuracy and measures performance improvement

var rng: RandomNumberGenerator
var test_config: TreeBoundaryConfiguration

func _initialize():
	print("=== PathSegmentGrid A/B Integration Test ===")

	# Setup test environment
	rng = RandomNumberGenerator.new()
	rng.seed = 12345

	# Load default configuration for realistic testing
	test_config = load("res://data/content/DefaultTreeBoundaryConfiguration.tres")
	if not test_config:
		print("❌ Could not load DefaultTreeBoundaryConfiguration.tres")
		quit()
		return

	# Run A/B comparison tests
	_test_accuracy_validation()
	_test_performance_comparison()
	_test_visual_regression()

	print("✅ All PathSegmentGrid integration tests completed!")
	quit()

## Test accuracy: Legacy vs Optimized methods produce identical results
func _test_accuracy_validation():
	print("\n🎯 Testing accuracy: Legacy vs Optimized collision detection...")

	# Create test paths (simulated realistic arena paths)
	var test_paths = _create_realistic_test_paths()

	# Generate test tree positions
	var test_positions = _generate_test_tree_positions(1000)

	# Test legacy method
	test_config.use_optimized_path_collision = false
	var legacy_start = Time.get_ticks_usec()
	var legacy_result = test_config._clear_walkable_paths_simple(test_positions, test_paths)
	var legacy_time = Time.get_ticks_usec() - legacy_start

	# Test optimized method
	test_config.use_optimized_path_collision = true
	var optimized_start = Time.get_ticks_usec()
	var optimized_result = test_config._clear_walkable_paths_simple(test_positions, test_paths)
	var optimized_time = Time.get_ticks_usec() - optimized_start

	# Compare results
	var accuracy = _compare_results(legacy_result, optimized_result)
	var speedup = float(legacy_time) / float(optimized_time)

	print("Legacy method: %d trees kept in %.3fms" % [legacy_result.size(), legacy_time / 1000.0])
	print("Optimized method: %d trees kept in %.3fms" % [optimized_result.size(), optimized_time / 1000.0])
	print("Accuracy: %.1f%% (%.1fx speedup)" % [accuracy * 100, speedup])

	if accuracy > 0.99:  # Allow for tiny floating point differences
		print("✅ Excellent accuracy - methods produce nearly identical results")
	else:
		print("⚠️ Accuracy issue detected - needs investigation")
		_debug_accuracy_differences(legacy_result, optimized_result)

	if speedup > 2.0:
		print("✅ Good performance improvement (>2x speedup)")
	else:
		print("⚠️ Performance improvement below target (<2x)")

## Test performance with realistic arena generation workload
func _test_performance_comparison():
	print("\n⚡ Testing performance with realistic arena workload...")

	# Create realistic arena scenario
	var arena_paths = _create_realistic_arena_paths()
	var arena_tree_positions = _generate_realistic_tree_positions(6000)  # Match current arena size

	print("Performance test scenario:")
	print("  - Paths: %d" % arena_paths.size())
	print("  - Tree positions: %d" % arena_tree_positions.size())

	# Benchmark legacy method
	test_config.use_optimized_path_collision = false
	var legacy_times = []
	for i in range(5):  # 5 trials for statistical confidence
		var start_time = Time.get_ticks_usec()
		var result = test_config._clear_walkable_paths_simple(arena_tree_positions, arena_paths)
		var elapsed = Time.get_ticks_usec() - start_time
		legacy_times.append(elapsed)

	# Benchmark optimized method
	test_config.use_optimized_path_collision = true
	var optimized_times = []
	for i in range(5):  # 5 trials for statistical confidence
		var start_time = Time.get_ticks_usec()
		var result = test_config._clear_walkable_paths_simple(arena_tree_positions, arena_paths)
		var elapsed = Time.get_ticks_usec() - start_time
		optimized_times.append(elapsed)

	# Calculate statistics
	var legacy_avg = _calculate_average(legacy_times)
	var optimized_avg = _calculate_average(optimized_times)
	var improvement_factor = legacy_avg / optimized_avg

	print("Performance comparison (5 trials each):")
	print("  Legacy average: %.3fms" % (legacy_avg / 1000.0))
	print("  Optimized average: %.3fms" % (optimized_avg / 1000.0))
	print("  Improvement: %.1fx faster" % improvement_factor)

	# Target validation
	if improvement_factor >= 5.0:
		print("✅ Excellent performance - exceeds 5x target")
	elif improvement_factor >= 3.0:
		print("✅ Good performance - exceeds 3x minimum")
	else:
		print("⚠️ Performance below target - expected >3x improvement")

## Test visual regression - ensure tree count and distribution remain similar
func _test_visual_regression():
	print("\n📊 Testing visual regression (tree count and distribution)...")

	# Use realistic arena generation settings
	var arena_paths = _create_realistic_arena_paths()
	var tree_positions = _generate_realistic_tree_positions(6000)

	# Test legacy generation
	test_config.use_optimized_path_collision = false
	var legacy_trees = test_config._clear_walkable_paths_simple(tree_positions, arena_paths)

	# Test optimized generation
	test_config.use_optimized_path_collision = true
	var optimized_trees = test_config._clear_walkable_paths_simple(tree_positions, arena_paths)

	# Compare tree counts
	var count_difference = abs(legacy_trees.size() - optimized_trees.size())
	var count_variance = float(count_difference) / float(legacy_trees.size())

	print("Tree count comparison:")
	print("  Legacy: %d trees" % legacy_trees.size())
	print("  Optimized: %d trees" % optimized_trees.size())
	print("  Variance: %.2f%%" % (count_variance * 100))

	if count_variance < 0.01:  # Less than 1% difference
		print("✅ Excellent tree count consistency")
	elif count_variance < 0.05:  # Less than 5% difference
		print("✅ Good tree count consistency")
	else:
		print("⚠️ Tree count variance higher than expected")

	# Test spatial distribution similarity
	var distribution_similarity = _compare_spatial_distribution(legacy_trees, optimized_trees)
	print("Spatial distribution similarity: %.1f%%" % (distribution_similarity * 100))

	if distribution_similarity > 0.95:
		print("✅ Excellent spatial distribution consistency")
	else:
		print("⚠️ Spatial distribution differs - manual review recommended")

## Helper: Create realistic test paths similar to arena generation
func _create_realistic_test_paths() -> Array:
	var paths = []

	# Create path test doubles that match real path interface
	for i in range(7):  # Match typical arena path count
		var path = PathTestDouble.new()
		var path_points: Array[Vector2] = []

		# Generate curved path
		var start_pos = Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
		var end_pos = Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))

		# Add intermediate points for realistic path complexity
		path_points.append(start_pos)
		for j in range(3):  # 3 intermediate points
			var t = (j + 1) / 4.0
			var intermediate = start_pos.lerp(end_pos, t) + Vector2(
				rng.randf_range(-50, 50), rng.randf_range(-50, 50)
			)
			path_points.append(intermediate)
		path_points.append(end_pos)

		path.setup(path_points, rng.randf_range(40, 80))  # Realistic path widths
		paths.append(path)

	return paths

## Helper: Create full arena-scale path set
func _create_realistic_arena_paths() -> Array:
	var paths = []

	# More complex arena-scale paths
	for i in range(10):  # Larger arena path count
		var path = PathTestDouble.new()
		var path_points: Array[Vector2] = []

		# Generate longer, more complex paths
		var start_pos = Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))

		# Create winding path
		var current_pos = start_pos
		path_points.append(current_pos)

		for segment in range(8):  # 8 segments per path
			var direction = Vector2.from_angle(rng.randf() * TAU)
			var distance = rng.randf_range(80, 150)
			current_pos += direction * distance
			path_points.append(current_pos)

		path.setup(path_points, rng.randf_range(50, 90))
		paths.append(path)

	return paths

## Helper: Generate test tree positions in arena-like distribution
func _generate_test_tree_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var bounds = Rect2(-600, -600, 1200, 1200)  # Arena-scale bounds

	for i in range(count):
		var pos = Vector2(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		positions.append(pos)

	return positions

## Helper: Generate realistic tree positions using current algorithm patterns
func _generate_realistic_tree_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	# Use grid-based generation like the real algorithm
	var spacing = 25.0  # Match tree_spacing
	var bounds = Rect2(-600, -600, 1200, 1200)

	var x = bounds.position.x
	while x < bounds.position.x + bounds.size.x:
		var y = bounds.position.y
		while y < bounds.position.y + bounds.size.y:
			if rng.randf() < 0.7:  # ~70% density like real generation
				var pos = Vector2(x, y) + Vector2(
					rng.randf_range(-spacing * 0.3, spacing * 0.3),
					rng.randf_range(-spacing * 0.3, spacing * 0.3)
				)
				positions.append(pos)

				if positions.size() >= count:
					return positions

			y += spacing
		x += spacing

	return positions

## Helper: Compare two result arrays for accuracy
func _compare_results(legacy: Array[Vector2], optimized: Array[Vector2]) -> float:
	if legacy.size() != optimized.size():
		return 0.0  # Different sizes = poor accuracy

	# Sort both arrays for comparison (order shouldn't matter)
	var legacy_sorted = legacy.duplicate()
	var optimized_sorted = optimized.duplicate()

	legacy_sorted.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	optimized_sorted.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))

	var matches = 0
	for i in range(legacy_sorted.size()):
		if legacy_sorted[i].distance_to(optimized_sorted[i]) < 0.1:  # Allow tiny floating point differences
			matches += 1

	return float(matches) / float(legacy_sorted.size())

## Helper: Compare spatial distribution patterns
func _compare_spatial_distribution(legacy: Array[Vector2], optimized: Array[Vector2]) -> float:
	# Simple distribution comparison using grid cells
	var grid_size = 100.0
	var legacy_grid = {}
	var optimized_grid = {}

	# Count trees per grid cell for legacy
	for pos in legacy:
		var grid_key = Vector2i(int(pos.x / grid_size), int(pos.y / grid_size))
		legacy_grid[grid_key] = legacy_grid.get(grid_key, 0) + 1

	# Count trees per grid cell for optimized
	for pos in optimized:
		var grid_key = Vector2i(int(pos.x / grid_size), int(pos.y / grid_size))
		optimized_grid[grid_key] = optimized_grid.get(grid_key, 0) + 1

	# Compare distributions
	var all_keys = {}
	for key in legacy_grid.keys():
		all_keys[key] = true
	for key in optimized_grid.keys():
		all_keys[key] = true

	var similarity_sum = 0.0
	var cell_count = 0

	for key in all_keys.keys():
		var legacy_count = legacy_grid.get(key, 0)
		var optimized_count = optimized_grid.get(key, 0)
		var max_count = max(legacy_count, optimized_count)

		if max_count > 0:
			var similarity = 1.0 - (abs(legacy_count - optimized_count) / float(max_count))
			similarity_sum += similarity
			cell_count += 1

	return similarity_sum / cell_count if cell_count > 0 else 1.0

## Helper: Calculate average of time measurements
func _calculate_average(times: Array) -> float:
	var sum = 0.0
	for time in times:
		sum += time
	return sum / times.size()

## Helper: Debug accuracy differences
func _debug_accuracy_differences(legacy: Array[Vector2], optimized: Array[Vector2]):
	print("Debugging accuracy differences:")
	print("  Legacy result size: %d" % legacy.size())
	print("  Optimized result size: %d" % optimized.size())

	if legacy.size() != optimized.size():
		print("  Size mismatch detected - investigating tree rejection differences")

## Test double that mimics path object interface
class PathTestDouble:
	var _points: Array[Vector2]
	var width: float

	func setup(points: Array[Vector2], w: float):
		_points = points
		width = w

	func get_full_path() -> Array[Vector2]:
		return _points.duplicate()  # Simulate allocation like real paths