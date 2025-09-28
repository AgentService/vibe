@tool
extends RefCounted
class_name PathAwareDebugRenderer

## Dedicated debug visualization renderer for PathAwareArenaGenerator
## Keeps debug logic separate from core generation logic

static func render_debug_visualization(generator: PathAwareArenaGenerator) -> void:
	"""Main entry point - render all debug visualization for the generator"""
	if not generator:
		Logger.warn("PathAwareDebugRenderer: generator is null", "pathdebug")
		return

	Logger.debug("PathAwareDebugRenderer: Starting debug visualization", "pathdebug")

	# Clear any existing debug markers
	_clear_debug_markers(generator)

	# Create debug markers based on generator settings
	if generator.show_debug_markers:
		_create_start_marker(generator)
		_create_main_path_markers(generator)

	if generator.show_path_connections:
		_create_path_connection_lines(generator)

	Logger.debug("PathAwareDebugRenderer: Debug visualization complete", "pathdebug")

static func _clear_debug_markers(generator: PathAwareArenaGenerator) -> void:
	"""Clear existing debug markers"""
	for marker in generator.debug_markers:
		if marker and is_instance_valid(marker):
			marker.queue_free()
	generator.debug_markers.clear()

	for line in generator.debug_lines:
		if line and is_instance_valid(line):
			line.queue_free()
	generator.debug_lines.clear()

static func _create_start_marker(generator: PathAwareArenaGenerator) -> void:
	"""Create the yellow START marker"""
	var points: Array = generator.current_path_data.get("points", [])
	if points.size() > 0:
		var point = points[0]
		var marker = _create_start_point_marker(point.position)
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created START marker at position %s" % point.position, "pathdebug")

static func _create_main_path_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create numbered blue markers for main path chain points"""
	var connection_points: Array = generator.current_path_data.get("points", [])
	Logger.debug("Creating main path markers for %d connection points" % connection_points.size(), "pathdebug")

	# Skip the first point (index 0) since we already have START marker there
	for i in range(1, connection_points.size()):
		var point = connection_points[i]
		var marker = _create_main_path_point_marker(point.position, i)
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created main path marker %d at position %s" % [i, point.position], "pathdebug")

static func _create_path_connection_lines(generator: PathAwareArenaGenerator) -> void:
	"""Create cyan lines showing path connections"""
	var paths: Array = generator.current_path_data.get("paths", [])

	for path in paths:
		if path.has_method("get_full_path"):
			var line = _create_connection_line(path, generator)
			generator.add_child(line)
			generator.debug_lines.append(line)

static func _create_start_point_marker(position: Vector2) -> Node2D:
	"""Create a yellow START marker"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "StartPointMarker"

	# Create yellow circle using ColorRect
	var circle = ColorRect.new()
	circle.name = "StartCircle"
	circle.color = Color.YELLOW
	circle.size = Vector2(40, 40)
	circle.position = Vector2(-20, -20)
	marker.add_child(circle)

	# Create border
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	border.size = Vector2(44, 44)
	border.position = Vector2(-22, -22)
	marker.add_child(border)
	marker.move_child(border, 0)

	# Create text label
	var label = Label.new()
	label.name = "StartLabel"
	label.text = "START"
	label.add_theme_color_override("font_color", Color.BLACK)
	label.position = Vector2(-15, -5)
	marker.add_child(label)

	return marker

static func _create_main_path_point_marker(position: Vector2, point_index: int) -> Node2D:
	"""Create a blue numbered marker for main path points"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "MainPathPoint_" + str(point_index)

	# Create blue circle
	var circle = ColorRect.new()
	circle.name = "PathCircle"
	circle.color = Color.BLUE
	var size = 24
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)
	marker.add_child(circle)

	# Create border
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	var border_size = size + 3
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)
	marker.add_child(border)
	marker.move_child(border, 0)

	# Create text label
	var label = Label.new()
	label.name = "PathLabel"
	label.text = str(point_index)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-5, -8)
	marker.add_child(label)

	return marker

static func _create_connection_line(path, generator: PathAwareArenaGenerator) -> Line2D:
	"""Create a cyan line for path connection"""
	var line = Line2D.new()
	line.name = "PathConnection"
	line.width = generator.line_width
	line.default_color = Color.CYAN
	line.antialiased = true

	# Add points for the full path
	var path_points = path.get_full_path()
	for point in path_points:
		line.add_point(point)

	return line

## Future extension points for additional visualizations:

static func render_spawn_zones(generator: PathAwareArenaGenerator) -> void:
	"""Render spawn zone previews - to be implemented"""
	# TODO: Add spawn zone visualization
	pass

static func render_clearings(generator: PathAwareArenaGenerator) -> void:
	"""Render clearing area markers - to be implemented"""
	# TODO: Add clearing visualization
	pass

static func render_branch_points(generator: PathAwareArenaGenerator) -> void:
	"""Render branch connection points - to be implemented"""
	# TODO: Add branch visualization
	pass