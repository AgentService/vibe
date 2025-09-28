@tool
extends RefCounted
class_name PathSegmentGrid

## Spatial grid for fast path segment collision queries
## Optimizes O(N×M×P) tree clearing to O(1) average case lookups
## Based on existing collision grid from PathConfiguration but enhanced for tree generation

# Grid data structures
var cells: Dictionary  # Vector2i -> Array[PathSegmentInfo]
var cell_size: int
var bounds: Rect2
var segment_count: int = 0

# Segment data for collision queries
class PathSegmentInfo:
	var start: Vector2
	var end: Vector2
	var clearance: float  # Half width + buffer for this segment

	func _init(s: Vector2, e: Vector2, c: float):
		start = s
		end = e
		clearance = c

## Initialize and build the spatial grid from path data
## @param paths: Array of path objects with get_full_path() and width properties
## @param grid_cell_size: Size of grid cells in pixels (default 512px)
func build_grid(paths: Array, grid_cell_size: int = 512) -> void:
	cell_size = grid_cell_size
	cells.clear()
	segment_count = 0

	# Calculate bounds for the entire path network
	_calculate_grid_bounds(paths)

	# Process each path and its segments
	for path in paths:
		var path_points = path.get_full_path()  # Remove strict typing to avoid assignment errors
		var clearance = (path.width * 0.5) + 12.0  # Match tree clearing logic

		# Add each segment to appropriate grid cells
		for i in range(path_points.size() - 1):
			var start_point = path_points[i]
			var end_point = path_points[i + 1]

			_add_segment_to_grid(start_point, end_point, clearance)
			segment_count += 1

	# Debug: Grid built successfully (Logger unavailable in test mode)

## Fast collision check for tree position
## Returns true if position is too close to any path (should reject tree)
## @param position: World position to check
## @return: true if position conflicts with paths
func is_position_blocked(position: Vector2) -> bool:
	var grid_x = int(floor(position.x / cell_size))
	var grid_y = int(floor(position.y / cell_size))
	var grid_key = Vector2i(grid_x, grid_y)

	# No segments in this cell = position is clear
	if not cells.has(grid_key):
		return false

	var segments: Array = cells[grid_key]

	# Check distance to each segment in this cell (much smaller set than full path list)
	for segment_info in segments:
		var distance = _point_to_line_distance(position, segment_info.start, segment_info.end)
		if distance <= segment_info.clearance:
			return true  # Position is blocked

	return false  # Position is clear

## Get debug info about grid performance
func get_grid_stats() -> Dictionary:
	var total_segments = 0
	var max_segments_per_cell = 0
	var occupied_cells = 0

	for cell_segments in cells.values():
		var count = cell_segments.size()
		total_segments += count
		max_segments_per_cell = max(max_segments_per_cell, count)
		if count > 0:
			occupied_cells += 1

	var avg_segments_per_occupied_cell = float(total_segments) / max(1, occupied_cells)

	return {
		"total_cells": cells.size(),
		"occupied_cells": occupied_cells,
		"total_segments": segment_count,
		"max_segments_per_cell": max_segments_per_cell,
		"avg_segments_per_occupied_cell": avg_segments_per_occupied_cell,
		"cell_size": cell_size,
		"bounds": bounds
	}

## Calculate bounding rectangle for all paths
func _calculate_grid_bounds(paths: Array) -> void:
	if paths.is_empty():
		bounds = Rect2()
		return

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for path in paths:
		var path_points = path.get_full_path()  # Remove strict typing
		var buffer = (path.width * 0.5) + 12.0

		for point in path_points:
			min_x = min(min_x, point.x - buffer)
			max_x = max(max_x, point.x + buffer)
			min_y = min(min_y, point.y - buffer)
			max_y = max(max_y, point.y + buffer)

	bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

## Add a path segment to all grid cells it affects
func _add_segment_to_grid(start_point: Vector2, end_point: Vector2, clearance: float) -> void:
	var segment_info = PathSegmentInfo.new(start_point, end_point, clearance)

	# Calculate bounding box for this segment (including clearance)
	var min_x = min(start_point.x, end_point.x) - clearance
	var max_x = max(start_point.x, end_point.x) + clearance
	var min_y = min(start_point.y, end_point.y) - clearance
	var max_y = max(start_point.y, end_point.y) + clearance

	# Find all grid cells this segment affects
	var start_grid_x = int(floor(min_x / cell_size))
	var end_grid_x = int(ceil(max_x / cell_size))
	var start_grid_y = int(floor(min_y / cell_size))
	var end_grid_y = int(ceil(max_y / cell_size))

	# Add segment to all affected cells
	for grid_x in range(start_grid_x, end_grid_x + 1):
		for grid_y in range(start_grid_y, end_grid_y + 1):
			var grid_key = Vector2i(grid_x, grid_y)
			if not cells.has(grid_key):
				cells[grid_key] = []
			cells[grid_key].append(segment_info)

## Calculate distance from point to line segment (copied from existing implementation)
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var line_length_squared = line_vec.length_squared()

	if line_length_squared == 0.0:
		return point.distance_to(line_start)

	var t = max(0, min(1, (point - line_start).dot(line_vec) / line_length_squared))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)