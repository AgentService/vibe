@tool
extends SceneTree

## Simple A/B test for PathSegmentGrid optimization
## Tests accuracy and performance without resource dependencies

var rng: RandomNumberGenerator

func _initialize():
	print("=== PathSegmentGrid Simple A/B Test ===")

	# Setup test environment
	rng = RandomNumberGenerator.new()
	rng.seed = 12345

	# Create test configuration in memory
	var test_config = TreeBoundaryConfiguration.new()
	test_config.tree_spacing = 25.0
	test_config.tree_density = 0.95
	test_config.tree_boundary_width = 300.0

	# Run A/B comparison tests
	_test_optimization_accuracy(test_config)
	_test_optimization_performance(test_config)

	print("✅ PathSegmentGrid A/B test completed!")
	quit()

## Test accuracy: Legacy vs Optimized methods produce identical results
func _test_optimization_accuracy(config: TreeBoundaryConfiguration):
	print("\n🎯 Testing optimization accuracy...")

	# Create test paths
	var test_paths = _create_test_paths()
	var test_positions = _generate_test_positions(500)

	# Test legacy method
	config.use_optimized_path_collision = false
	var legacy_result = config._clear_walkable_paths_simple(test_positions, test_paths)

	# Test optimized method
	config.use_optimized_path_collision = true
	var optimized_result = config._clear_walkable_paths_simple(test_positions, test_paths)

	# Compare results
	var accuracy = _compare_results(legacy_result, optimized_result)

	print("Legacy result: %d trees kept" % legacy_result.size())
	print("Optimized result: %d trees kept" % optimized_result.size())
	print("Accuracy: %.1f%%" % (accuracy * 100))

	if accuracy > 0.99:
		print("✅ Excellent accuracy - methods produce nearly identical results")
	else:
		print("⚠️ Accuracy issue detected")
		_debug_result_differences(legacy_result, optimized_result)

## Test performance improvement
func _test_optimization_performance(config: TreeBoundaryConfiguration):
	print("\n⚡ Testing optimization performance...")

	# Create performance test scenario
	var test_paths = _create_complex_paths()
	var test_positions = _generate_test_positions(2000)

	print("Performance test: %d paths, %d positions" % [test_paths.size(), test_positions.size()])

	# Benchmark legacy method (3 trials)
	var legacy_times = []
	config.use_optimized_path_collision = false
	for i in range(3):
		var start_time = Time.get_ticks_usec()
		var result = config._clear_walkable_paths_simple(test_positions, test_paths)
		var elapsed = Time.get_ticks_usec() - start_time
		legacy_times.append(elapsed)

	# Benchmark optimized method (3 trials)
	var optimized_times = []
	config.use_optimized_path_collision = true
	for i in range(3):
		var start_time = Time.get_ticks_usec()
		var result = config._clear_walkable_paths_simple(test_positions, test_paths)
		var elapsed = Time.get_ticks_usec() - start_time
		optimized_times.append(elapsed)

	# Calculate performance improvement
	var legacy_avg = _calculate_average(legacy_times)
	var optimized_avg = _calculate_average(optimized_times)
	var speedup = legacy_avg / optimized_avg

	print("Performance results:")
	print("  Legacy average: %.3fms" % (legacy_avg / 1000.0))
	print("  Optimized average: %.3fms" % (optimized_avg / 1000.0))
	print("  Speedup: %.1fx faster" % speedup)

	if speedup >= 3.0:
		print("✅ Excellent performance improvement (>3x)")
	elif speedup >= 2.0:
		print("✅ Good performance improvement (>2x)")
	else:
		print("⚠️ Performance improvement below target")

## Create test paths for validation
func _create_test_paths() -> Array:
	var paths = []

	# Create 5 test paths
	for i in range(5):
		var path = PathTestDouble.new()
		var points: Array[Vector2] = []

		# Create a simple path with 4 segments
		var start = Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
		points.append(start)

		for j in range(3):
			var next_point = points[-1] + Vector2(
				rng.randf_range(-100, 100),
				rng.randf_range(-100, 100)
			)
			points.append(next_point)

		path.setup(points, rng.randf_range(40, 80))
		paths.append(path)

	return paths

## Create more complex paths for performance testing
func _create_complex_paths() -> Array:
	var paths = []

	# Create 8 complex paths
	for i in range(8):
		var path = PathTestDouble.new()
		var points: Array[Vector2] = []

		# Create longer paths with more segments
		var start = Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
		points.append(start)

		for j in range(8):  # 8 segments per path
			var next_point = points[-1] + Vector2(
				rng.randf_range(-80, 80),
				rng.randf_range(-80, 80)
			)
			points.append(next_point)

		path.setup(points, rng.randf_range(50, 90))
		paths.append(path)

	return paths

## Generate test positions
func _generate_test_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var bounds = Rect2(-500, -500, 1000, 1000)

	for i in range(count):
		var pos = Vector2(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		positions.append(pos)

	return positions

## Compare two result arrays for accuracy
func _compare_results(legacy: Array[Vector2], optimized: Array[Vector2]) -> float:
	if legacy.size() != optimized.size():
		return float(min(legacy.size(), optimized.size())) / float(max(legacy.size(), optimized.size()))

	# Convert to sets for comparison (order doesn't matter)
	var legacy_set = {}
	var optimized_set = {}

	for pos in legacy:
		var key = "%d,%d" % [int(pos.x), int(pos.y)]  # Round to avoid floating point issues
		legacy_set[key] = true

	for pos in optimized:
		var key = "%d,%d" % [int(pos.x), int(pos.y)]
		optimized_set[key] = true

	# Count matches
	var matches = 0
	for key in legacy_set.keys():
		if optimized_set.has(key):
			matches += 1

	return float(matches) / float(legacy_set.size())

## Debug result differences
func _debug_result_differences(legacy: Array[Vector2], optimized: Array[Vector2]):
	print("Debugging result differences:")
	print("  Legacy size: %d, Optimized size: %d" % [legacy.size(), optimized.size()])

	if legacy.size() != optimized.size():
		var diff = abs(legacy.size() - optimized.size())
		print("  Size difference: %d trees" % diff)

## Calculate average of measurements
func _calculate_average(values: Array) -> float:
	var sum = 0.0
	for value in values:
		sum += value
	return sum / values.size()

## Test double that mimics path object interface
class PathTestDouble:
	var _points: Array[Vector2]
	var width: float

	func setup(points: Array[Vector2], w: float):
		_points = points
		width = w

	func get_full_path() -> Array[Vector2]:
		return _points.duplicate()