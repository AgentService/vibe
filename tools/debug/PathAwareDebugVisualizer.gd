@tool
extends Node2D
class_name PathAwareDebugVisualizer

## Debug visualization tool for path-aware spawning systems
## Creates lightweight overlays so designers can confirm spawn data before systems consume it
## Can be used in editor (with @tool) or at runtime for debugging

@export_group("Debug Configuration")
## Path snapshot data to visualize
@export var snapshot: PathAwarePathSnapshot:
	set(value):
		snapshot = value
		queue_redraw()

## Which spawn categories to display
@export var display_categories: Array[PathSpawnProfile.PathSpawnCategory] = [
	PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH,
	PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES,
	PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS,
	PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS,
	PathSpawnProfile.PathSpawnCategory.AROUND_PATHS,
]:
	set(value):
		display_categories = value
		queue_redraw()

@export_group("Visual Settings")
## Color palette for different spawn categories
@export var category_colors: Dictionary = {
	PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH: Color.CYAN,
	PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES: Color.MAGENTA,
	PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS: Color.YELLOW,
	PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS: Color.GREEN,
	PathSpawnProfile.PathSpawnCategory.AROUND_PATHS: Color.ORANGE,
}:
	set(value):
		category_colors = value
		queue_redraw()

## Size of spawn position markers
@export_range(4.0, 32.0, 2.0) var marker_size: float = 12.0:
	set(value):
		marker_size = value
		queue_redraw()

## Width of path lines
@export_range(1.0, 8.0, 0.5) var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()

## Whether to show spawn position markers
@export var show_spawn_markers: bool = true:
	set(value):
		show_spawn_markers = value
		queue_redraw()

## Whether to show path lines
@export var show_path_lines: bool = true:
	set(value):
		show_path_lines = value
		queue_redraw()

## Whether to show clearing areas
@export var show_clearings: bool = true:
	set(value):
		show_clearings = value
		queue_redraw()

## Whether to show boundary zones
@export var show_boundaries: bool = false:
	set(value):
		show_boundaries = value
		queue_redraw()

@export_group("Arena Integration")
## Arena ID for PathAwareSpaceService queries (if available)
@export var arena_id: String = ""

## Cache for spawn positions by category (populated by _update_spawn_data)
var cached_spawn_positions: Dictionary = {}

## Whether the PathAwareSpaceService is available
var space_service_available: bool = false

func _ready() -> void:
	# Check if PathAwareSpaceService is available (will be created in later milestones)
	space_service_available = false  # TODO: Check for PathAwareSpaceService when implemented

	# If we have an arena_id and service is available, try to get data from it
	if not arena_id.is_empty() and space_service_available:
		_update_spawn_data_from_service()
	elif snapshot:
		_update_spawn_data_from_snapshot()

	# Listen for arena snapshot updates if EventBus is available
	if EventBus:
		EventBus.arena_path_snapshot_ready.connect(_on_arena_snapshot_ready)

func _draw() -> void:
	if not snapshot:
		_draw_no_data_message()
		return

	# Draw path lines
	if show_path_lines:
		_draw_path_lines()

	# Draw clearings
	if show_clearings:
		_draw_clearings()

	# Draw boundary zones
	if show_boundaries:
		_draw_boundary_zones()

	# Draw spawn markers for each category
	if show_spawn_markers:
		for category in display_categories:
			_draw_category_markers(category)

	# Draw legend
	_draw_legend()

## Draw message when no data is available
func _draw_no_data_message() -> void:
	var font = ThemeDB.fallback_font
	var message = "No PathAwarePathSnapshot data available"
	var font_size = 16
	var text_color = Color.RED
	var text_pos = Vector2(10, 30)

	draw_string(font, text_pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

## Draw path lines from snapshot
func _draw_path_lines() -> void:
	if not snapshot:
		return

	# Draw main path
	if snapshot.main_path_points.size() > 1:
		var path_color = Color.WHITE
		var points = PackedVector2Array(snapshot.main_path_points)
		draw_polyline(points, path_color, line_width, true)

	# Draw branch paths
	for branch_info in snapshot.branch_data:
		if branch_info.points.size() > 1:
			var branch_color = Color.LIGHT_GRAY
			var points = PackedVector2Array(branch_info.points)
			draw_polyline(points, branch_color, line_width, true)

## Draw clearing areas
func _draw_clearings() -> void:
	if not snapshot:
		return

	for clearing in snapshot.clearings:
		var clearing_color = Color.GREEN
		clearing_color.a = 0.2  # Transparent
		draw_circle(clearing.center, clearing.radius, clearing_color)

		# Draw clearing outline
		draw_arc(clearing.center, clearing.radius, 0, TAU, 32, Color.GREEN, 1.0)

## Draw boundary zones
func _draw_boundary_zones() -> void:
	if not snapshot:
		return

	for boundary in snapshot.boundary_zones:
		var boundary_color = Color.RED
		boundary_color.a = 0.3  # Transparent
		draw_circle(boundary.center, boundary.radius, boundary_color)

## Draw spawn markers for a specific category
func _draw_category_markers(category: PathSpawnProfile.PathSpawnCategory) -> void:
	var color = category_colors.get(category, Color.WHITE)
	var positions = cached_spawn_positions.get(category, [])

	for position in positions:
		# Draw filled circle
		draw_circle(position, marker_size, color)

		# Draw border for visibility
		draw_arc(position, marker_size, 0, TAU, 16, Color.WHITE, 2.0)

## Draw legend showing category colors
func _draw_legend() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 14
	var legend_start = Vector2(10, 10)
	var line_height = 20
	var legend_bg_color = Color.BLACK
	legend_bg_color.a = 0.7

	# Calculate legend background size
	var legend_width = 200
	var legend_height = (display_categories.size() + 1) * line_height + 10
	var legend_rect = Rect2(legend_start - Vector2(5, 5), Vector2(legend_width, legend_height))

	# Draw legend background
	draw_rect(legend_rect, legend_bg_color)

	# Draw legend title
	var title_pos = legend_start
	draw_string(font, title_pos, "PathAware Spawn Categories:", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# Draw category entries
	for i in range(display_categories.size()):
		var category = display_categories[i]
		var color = category_colors.get(category, Color.WHITE)
		var category_name = _get_category_display_name(category)
		var entry_pos = legend_start + Vector2(0, (i + 1) * line_height)

		# Draw color swatch
		var swatch_rect = Rect2(entry_pos, Vector2(marker_size, marker_size))
		draw_rect(swatch_rect, color)

		# Draw category name
		var text_pos = entry_pos + Vector2(marker_size + 5, marker_size)
		draw_string(font, text_pos, category_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## Get human-readable category name
func _get_category_display_name(category: PathSpawnProfile.PathSpawnCategory) -> String:
	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return "Main Path"
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return "Branches"
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return "Endpoints"
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return "Clearings"
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return "Around Paths"
		_:
			return "Unknown"

## Update spawn data from PathAwareSpaceService (future implementation)
func _update_spawn_data_from_service() -> void:
	# TODO: Implement when PathAwareSpaceService is available
	# For each category, get spawn positions from service
	# cached_spawn_positions[category] = PathAwareSpaceService.get_spawn_positions(arena_id, category)
	pass

## Update spawn data from snapshot directly
func _update_spawn_data_from_snapshot() -> void:
	if not snapshot:
		return

	cached_spawn_positions.clear()

	# Generate spawn positions for each category using the same logic as PathAwareMapConfig
	for category in display_categories:
		var positions = _get_spawn_positions_for_category(category)
		cached_spawn_positions[category] = positions

	Logger.debug("Updated spawn data from snapshot for %d categories" % display_categories.size(), "pathdebug")

## Get spawn positions for a category (mirrors PathAwareMapConfig logic)
func _get_spawn_positions_for_category(category: PathSpawnProfile.PathSpawnCategory) -> Array[Vector2]:
	if not snapshot:
		return []

	match category:
		PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH:
			return _sample_positions_along_path(snapshot.main_path_points, 64.0)
		PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES:
			return _sample_positions_along_branches()
		PathSpawnProfile.PathSpawnCategory.AT_ENDPOINTS:
			return snapshot.endpoint_positions.duplicate()
		PathSpawnProfile.PathSpawnCategory.IN_CLEARINGS:
			return _get_clearing_positions()
		PathSpawnProfile.PathSpawnCategory.AROUND_PATHS:
			return _get_around_path_positions()
		_:
			return []

## Sample positions along a path with specified spacing (mirrors PathAwareMapConfig)
func _sample_positions_along_path(path_points: Array[Vector2], spacing: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if path_points.size() < 2:
		return positions

	for i in range(path_points.size() - 1):
		var start = path_points[i]
		var end = path_points[i + 1]
		var segment_length = start.distance_to(end)
		var steps = int(segment_length / spacing)

		for j in range(steps):
			var t = float(j) / float(steps)
			var position = start.lerp(end, t)
			positions.append(position)

	return positions

## Sample positions along branch paths
func _sample_positions_along_branches() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not snapshot or snapshot.branch_data.is_empty():
		return positions

	for branch_info in snapshot.branch_data:
		if branch_info.points.size() > 0:
			var branch_positions = _sample_positions_along_path(branch_info.points, 64.0)
			positions.append_array(branch_positions)

	return positions

## Get positions in clearing areas
func _get_clearing_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not snapshot or snapshot.clearings.is_empty():
		return positions

	for clearing in snapshot.clearings:
		# Sample a few positions within each clearing
		var center = clearing.center
		var radius = clearing.radius * 0.7  # Use 70% of radius for safety

		# Generate positions in a circle pattern
		var point_count = max(3, int(radius / 32.0))  # At least 3 points
		for i in range(point_count):
			var angle = TAU * float(i) / float(point_count)
			var offset = Vector2(cos(angle), sin(angle)) * radius * randf_range(0.3, 0.9)
			positions.append(center + offset)

	return positions

## Get positions around paths (buffer zones)
func _get_around_path_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if not snapshot or snapshot.path_corridors.is_empty():
		return positions

	for corridor in snapshot.path_corridors:
		if corridor.center_line.size() >= 2:
			var buffer_distance = corridor.width * 0.75  # Position outside corridor

			positions.append_array(_sample_positions_around_line(corridor.center_line, buffer_distance))

	return positions

## Sample positions around a line with specified buffer distance
func _sample_positions_around_line(line_points: Array[Vector2], buffer_distance: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []

	if line_points.size() < 2:
		return positions

	for i in range(line_points.size() - 1):
		var start = line_points[i]
		var end = line_points[i + 1]
		var direction = (end - start).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)

		# Sample along both sides of the line
		var segment_length = start.distance_to(end)
		var steps = max(1, int(segment_length / 48.0))  # One sample per 48 units

		for j in range(steps):
			var t = float(j) / float(steps)
			var point_on_line = start.lerp(end, t)

			# Add positions on both sides
			positions.append(point_on_line + perpendicular * buffer_distance)
			positions.append(point_on_line - perpendicular * buffer_distance)

	return positions

## Handle arena snapshot ready signal
func _on_arena_snapshot_ready(payload: EventBus.ArenaPathSnapshotReadyPayload_Type) -> void:
	# Update our data if this is for our arena
	if arena_id.is_empty() or payload.arena_id == arena_id:
		snapshot = payload.path_snapshot
		_update_spawn_data_from_snapshot()
		queue_redraw()

		Logger.debug("PathAwareDebugVisualizer updated from arena snapshot: %s" % payload.arena_id, "pathdebug")

## Public API for runtime debugging
func set_arena_data(new_arena_id: String, new_snapshot: PathAwarePathSnapshot) -> void:
	"""Set arena data for visualization."""
	arena_id = new_arena_id
	snapshot = new_snapshot
	_update_spawn_data_from_snapshot()
	queue_redraw()

func toggle_category(category: PathSpawnProfile.PathSpawnCategory) -> void:
	"""Toggle display of a specific category."""
	if category in display_categories:
		display_categories.erase(category)
	else:
		display_categories.append(category)
	queue_redraw()

func refresh_data() -> void:
	"""Refresh spawn data from current snapshot."""
	if snapshot:
		_update_spawn_data_from_snapshot()
		queue_redraw()

## Get debug information
func get_debug_info() -> Dictionary:
	return {
		"arena_id": arena_id,
		"has_snapshot": snapshot != null,
		"display_categories": display_categories.size(),
		"cached_positions": cached_spawn_positions.keys().size(),
		"total_spawn_positions": _count_total_spawn_positions()
	}

func _count_total_spawn_positions() -> int:
	var total = 0
	for positions in cached_spawn_positions.values():
		total += positions.size()
	return total