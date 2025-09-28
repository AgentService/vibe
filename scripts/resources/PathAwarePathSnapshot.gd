class_name PathAwarePathSnapshot
extends Resource

## Snapshot of generated path data for consumption by spawning systems
## Immutable data structure that captures the complete spatial layout of a generated arena
## Used by PathAwareSpaceService and spawning systems to make spatial queries

@export_group("Core Path Geometry")
## Main path points in world coordinates (center spine of the arena)
@export var main_path_points: Array[Vector2] = []

## Branch information including connection points and path segments
@export var branch_data: Array[PathBranchInfo] = []

## Connection points where paths meet (intersections and endpoints)
@export var connection_points: Array[PathConnectionPoint] = []

@export_group("Derived Spatial Data")
## Width-aware path segments with corridor boundaries
@export var path_corridors: Array[PathCorridor] = []

## Open areas between path boundaries suitable for spawning
@export var clearings: Array[PathClearing] = []

## Tree/obstacle boundary areas where spawning should be avoided
@export var boundary_zones: Array[PathBoundaryZone] = []

@export_group("Spawn-Relevant Metadata")
## Endpoint positions (branch terminals, good for boss spawns)
@export var endpoint_positions: Array[Vector2] = []

## Checkpoint positions along paths (for progression-based spawning)
@export var checkpoint_positions: Array[Vector2] = []

## Total bounding rectangle of the entire arena
@export var total_arena_bounds: Rect2

## Seed used for generation (for reproducibility and debugging)
@export var generation_seed: int

## Timestamp when this snapshot was created
@export var generation_timestamp: float

## Get all path points in a flat array (main + branches)
func get_all_path_points() -> Array[Vector2]:
	var all_points: Array[Vector2] = []
	all_points.append_array(main_path_points)

	for branch in branch_data:
		if branch.points:
			all_points.append_array(branch.points)

	return all_points

## Get the center position of the arena
func get_arena_center() -> Vector2:
	if total_arena_bounds.size == Vector2.ZERO:
		return Vector2.ZERO
	return total_arena_bounds.get_center()

## Check if a position is within the arena bounds
func is_position_in_arena(position: Vector2) -> bool:
	return total_arena_bounds.has_point(position)

## Get the nearest endpoint to a given position
func get_nearest_endpoint(position: Vector2) -> Vector2:
	if endpoint_positions.is_empty():
		return Vector2.ZERO

	var nearest_endpoint = endpoint_positions[0]
	var min_distance = position.distance_to(nearest_endpoint)

	for endpoint in endpoint_positions:
		var distance = position.distance_to(endpoint)
		if distance < min_distance:
			min_distance = distance
			nearest_endpoint = endpoint

	return nearest_endpoint

## Get clearings within a specified radius of a position
func get_clearings_in_range(center: Vector2, radius: float) -> Array[PathClearing]:
	var nearby_clearings: Array[PathClearing] = []

	for clearing in clearings:
		if clearing.center.distance_to(center) <= radius:
			nearby_clearings.append(clearing)

	return nearby_clearings

## Get path corridors that intersect with a given area
func get_corridors_in_area(area: Rect2) -> Array[PathCorridor]:
	var intersecting_corridors: Array[PathCorridor] = []

	for corridor in path_corridors:
		if _corridor_intersects_rect(corridor, area):
			intersecting_corridors.append(corridor)

	return intersecting_corridors

## Check if a corridor intersects with a rectangle
func _corridor_intersects_rect(corridor: PathCorridor, rect: Rect2) -> bool:
	# Simple check: see if any corridor point is within the rectangle
	# or if corridor bounds intersect with rectangle
	if corridor.center_line.is_empty():
		return false

	for point in corridor.center_line:
		if rect.has_point(point):
			return true

	# Also check if corridor bounding box intersects
	if corridor.bounds != Rect2() and corridor.bounds.intersects(rect):
		return true

	return false

## Get total path length (main path + all branches)
func get_total_path_length() -> float:
	var total_length = 0.0

	# Main path length
	total_length += _calculate_path_length(main_path_points)

	# Branch lengths
	for branch in branch_data:
		if branch.points:
			total_length += _calculate_path_length(branch.points)

	return total_length

## Calculate the length of a path given its points
func _calculate_path_length(points: Array[Vector2]) -> float:
	if points.size() < 2:
		return 0.0

	var length = 0.0
	for i in range(points.size() - 1):
		length += points[i].distance_to(points[i + 1])

	return length

## Get spawn quality score for a position (higher = better spawn location)
func get_spawn_quality_score(position: Vector2) -> float:
	var score = 1.0

	# Penalty for being outside arena bounds
	if not is_position_in_arena(position):
		return 0.0

	# Bonus for being in clearings
	for clearing in clearings:
		var distance_to_clearing = position.distance_to(clearing.center)
		if distance_to_clearing <= clearing.radius:
			score += 0.5  # Clearing bonus

	# Penalty for being too close to boundary zones
	for boundary in boundary_zones:
		var distance_to_boundary = position.distance_to(boundary.center)
		if distance_to_boundary <= boundary.radius * 1.2:  # Safety margin
			score *= 0.5  # Boundary penalty

	# Bonus for being near paths but not on them
	var nearest_path_distance = _get_distance_to_nearest_path(position)
	if nearest_path_distance > 30.0 and nearest_path_distance < 100.0:
		score += 0.3  # Sweet spot near paths

	return score

## Get distance to the nearest path point
func _get_distance_to_nearest_path(position: Vector2) -> float:
	var min_distance = float('inf')

	# Check main path
	for point in main_path_points:
		var distance = position.distance_to(point)
		if distance < min_distance:
			min_distance = distance

	# Check branches
	for branch in branch_data:
		if branch.points:
			for point in branch.points:
				var distance = position.distance_to(point)
				if distance < min_distance:
					min_distance = distance

	return min_distance if min_distance != float('inf') else 0.0

## Get debug summary for logging
func get_debug_summary() -> String:
	return "PathSnapshot[seed=%d, main_points=%d, branches=%d, clearings=%d, endpoints=%d, bounds=%s]" % [
		generation_seed,
		main_path_points.size(),
		branch_data.size(),
		clearings.size(),
		endpoint_positions.size(),
		str(total_arena_bounds)
	]

## Validate snapshot integrity
func is_valid() -> bool:
	# Basic validation checks
	if main_path_points.is_empty():
		Logger.warn("PathAwarePathSnapshot: No main path points", "pathspawn")
		return false

	if total_arena_bounds.size == Vector2.ZERO:
		Logger.warn("PathAwarePathSnapshot: Invalid arena bounds", "pathspawn")
		return false

	if generation_seed == 0:
		Logger.warn("PathAwarePathSnapshot: Invalid generation seed", "pathspawn")
		return false

	return true

# Supporting data structures for path snapshot - defined as inner Resource classes

## Information about a branch path
class PathBranchInfo extends Resource:
	@export var branch_id: int = 0
	@export var points: Array[Vector2] = []
	@export var parent_connection_point: Vector2 = Vector2.ZERO
	@export var branch_type: String = ""  # "main", "secondary", etc.
	@export var length: float = 0.0

	func _init(id: int = 0):
		branch_id = id

	func calculate_length() -> void:
		if points.size() < 2:
			length = 0.0
			return
		length = 0.0
		for i in range(points.size() - 1):
			length += points[i].distance_to(points[i + 1])

## Connection point where paths meet
class PathConnectionPoint extends Resource:
	@export var position: Vector2 = Vector2.ZERO
	@export var connected_branch_ids: Array[int] = []
	@export var connection_type: String = ""  # "intersection", "endpoint", "split"

	func _init(pos: Vector2 = Vector2.ZERO):
		position = pos

	func get_connection_count() -> int:
		return connected_branch_ids.size()

## Width-aware path corridor
class PathCorridor extends Resource:
	@export var center_line: Array[Vector2] = []
	@export var width: float = 64.0
	@export var bounds: Rect2 = Rect2()
	@export var corridor_type: String = ""  # "main", "branch", "connector"

	func get_half_width() -> float:
		return width * 0.5

	func calculate_bounds() -> void:
		if center_line.is_empty():
			bounds = Rect2()
			return

		var min_pos = center_line[0]
		var max_pos = center_line[0]

		for point in center_line:
			min_pos.x = min(min_pos.x, point.x)
			min_pos.y = min(min_pos.y, point.y)
			max_pos.x = max(max_pos.x, point.x)
			max_pos.y = max(max_pos.y, point.y)

		# Expand by corridor width
		var half_width = get_half_width()
		min_pos -= Vector2(half_width, half_width)
		max_pos += Vector2(half_width, half_width)

		bounds = Rect2(min_pos, max_pos - min_pos)

## Open area suitable for spawning
class PathClearing extends Resource:
	@export var center: Vector2 = Vector2.ZERO
	@export var radius: float = 50.0
	@export var clearing_type: String = ""  # "intersection", "endpoint", "natural"
	@export var spawn_priority: float = 1.0

	func _init(pos: Vector2 = Vector2.ZERO, r: float = 50.0):
		center = pos
		radius = r

	func contains_point(point: Vector2) -> bool:
		return center.distance_to(point) <= radius

## Boundary zone where spawning should be avoided
class PathBoundaryZone extends Resource:
	@export var center: Vector2 = Vector2.ZERO
	@export var radius: float = 30.0
	@export var zone_type: String = ""  # "tree", "obstacle", "wall"
	@export var avoidance_priority: float = 1.0

	func _init(pos: Vector2 = Vector2.ZERO, r: float = 30.0):
		center = pos
		radius = r

	func should_avoid_point(point: Vector2, safety_margin: float = 1.2) -> bool:
		return center.distance_to(point) <= (radius * safety_margin)