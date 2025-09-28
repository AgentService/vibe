@tool
extends SceneTree

## Unit tests for PathSegmentGrid spatial optimization
## Validates accuracy against current collision detection and measures performance

var rng: RandomNumberGenerator
var test_paths: Array = []

func _initialize():
	print("=== PathSegmentGrid Unit Tests ===")

	# Setup test environment
	rng = RandomNumberGenerator.new()
	rng.seed = 12345

	# Create test paths with known geometry
	_create_test_paths()

	# Run test suite
	_test_accuracy_vs_current_method()
	_test_performance_benchmark()
	_test_grid_statistics()

	print("✅ All PathSegmentGrid tests completed!")
	quit()

## Create test paths with various configurations
func _create_test_paths():
	print("\n📐 Creating test paths...")

	# Simple straight path
	var straight_path = _create_test_path([
		Vector2(100, 100),
		Vector2(500, 100)
	], 64.0)
	test_paths.append(straight_path)

	# L-shaped path
	var l_path = _create_test_path([
		Vector2(200, 200),
		Vector2(400, 200),
		Vector2(400, 400)
	], 80.0)
	test_paths.append(l_path)

	# Complex zigzag path
	var zigzag_path = _create_test_path([
		Vector2(0, 0),
		Vector2(200, 100),
		Vector2(100, 300),
		Vector2(400, 250),
		Vector2(300, 500)
	], 96.0)
	test_paths.append(zigzag_path)

	print("Created %d test paths" % test_paths.size())

## Test accuracy: PathSegmentGrid vs current collision detection
func _test_accuracy_vs_current_method():
	print("\n🎯 Testing accuracy vs current collision detection...")

	# Build the spatial grid
	var grid = PathSegmentGrid.new()
	var grid_build_start = Time.get_ticks_usec()
	grid.build_grid(test_paths, 256)  # Use 256px cells for testing
	var grid_build_time = Time.get_ticks_usec() - grid_build_start

	print("Grid built in %.3fms" % (grid_build_time / 1000.0))
	print("Grid stats: %s" % grid.get_grid_stats())

	# Test positions around paths
	var test_positions = _generate_test_positions(100)
	var matches = 0
	var mismatches = 0

	for pos in test_positions:
		var current_result = _is_position_blocked_current_method(pos)
		var grid_result = grid.is_position_blocked(pos)

		if current_result == grid_result:
			matches += 1
		else:
			mismatches += 1
			print("❌ Mismatch at %s: current=%s, grid=%s" % [pos, current_result, grid_result])

	print("Accuracy test: %d matches, %d mismatches" % [matches, mismatches])

	if mismatches == 0:
		print("✅ Perfect accuracy - grid matches current method 100%")
	else:
		print("⚠️ Accuracy issues detected - needs investigation")

## Performance benchmark: grid vs current method
func _test_performance_benchmark():
	print("\n⚡ Performance benchmark...")

	# Build grid
	var grid = PathSegmentGrid.new()
	grid.build_grid(test_paths, 512)

	# Generate lots of test positions for performance testing
	var benchmark_positions = _generate_test_positions(1000)

	# Benchmark current method
	var current_start = Time.get_ticks_usec()
	for pos in benchmark_positions:
		_is_position_blocked_current_method(pos)
	var current_time = Time.get_ticks_usec() - current_start

	# Benchmark grid method
	var grid_start = Time.get_ticks_usec()
	for pos in benchmark_positions:
		grid.is_position_blocked(pos)
	var grid_time = Time.get_ticks_usec() - grid_start

	# Calculate improvement
	var speedup = float(current_time) / float(grid_time)

	print("Current method: %.3fms (%d queries)" % [current_time / 1000.0, benchmark_positions.size()])
	print("Grid method: %.3fms (%d queries)" % [grid_time / 1000.0, benchmark_positions.size()])
	print("Speedup: %.1fx faster" % speedup)

	# Per-query timing
	var current_per_query = float(current_time) / benchmark_positions.size()
	var grid_per_query = float(grid_time) / benchmark_positions.size()

	print("Per-query timing:")
	print("  Current: %.3f microseconds" % current_per_query)
	print("  Grid: %.3f microseconds" % grid_per_query)

	if speedup > 5.0:
		print("✅ Excellent performance improvement (>5x)")
	elif speedup > 2.0:
		print("✅ Good performance improvement (>2x)")
	else:
		print("⚠️ Performance improvement below target (<2x)")

## Test grid internal statistics
func _test_grid_statistics():
	print("\n📊 Grid statistics analysis...")

	var grid = PathSegmentGrid.new()
	grid.build_grid(test_paths, 512)
	var stats = grid.get_grid_stats()

	print("Grid statistics:")
	for key in stats.keys():
		print("  %s: %s" % [key, stats[key]])

	# Validate grid efficiency
	var cell_utilization = float(stats.occupied_cells) / float(stats.total_cells)
	var avg_segments = stats.avg_segments_per_occupied_cell

	print("Cell utilization: %.1f%%" % (cell_utilization * 100))

	if avg_segments < 10:
		print("✅ Good segment distribution per cell")
	else:
		print("⚠️ High segment density - consider smaller cell size")

## Generate test positions around paths for validation
func _generate_test_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	# Generate positions in a reasonable area around paths
	var bounds = Rect2(0, 0, 600, 600)

	for i in range(count):
		var pos = Vector2(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		positions.append(pos)

	return positions

## Current collision detection method (replicated from TreeBoundaryConfiguration)
func _is_position_blocked_current_method(tree_pos: Vector2) -> bool:
	for path in test_paths:
		var path_points: Array[Vector2] = path.get_full_path()
		var clearance = (path.width * 0.5) + 12.0

		for i in range(path_points.size() - 1):
			var distance = _point_to_line_distance(tree_pos, path_points[i], path_points[i + 1])
			if distance <= clearance:
				return true

	return false

## Point to line distance calculation (replicated from existing code)
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var line_length_squared = line_vec.length_squared()

	if line_length_squared == 0.0:
		return point.distance_to(line_start)

	var t = max(0, min(1, (point - line_start).dot(line_vec) / line_length_squared))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

## Create a test path object that mimics the real path interface
func _create_test_path(points: Array[Vector2], width: float) -> Object:
	var path = PathTestDouble.new()
	path.setup(points, width)
	return path

## Test double that mimics path object interface
class PathTestDouble:
	var _points: Array[Vector2]
	var width: float

	func setup(points: Array[Vector2], w: float):
		_points = points
		width = w

	func get_full_path() -> Array[Vector2]:
		return _points.duplicate()  # Important: simulate allocation like real paths