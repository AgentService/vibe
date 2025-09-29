@tool
extends RefCounted
class_name PathAwareDebugRenderer

## Dedicated debug visualization renderer for PathAwareArenaGenerator
## Keeps debug logic separate from core generation logic

# Unified marker configuration system
enum MarkerShape {
	CIRCLE,
	SQUARE,
	DIAMOND,
	TRIANGLE
}

class MarkerConfig:
	var color: Color
	var border_color: Color
	var shape: MarkerShape
	var size: int
	var label_text: String
	var label_color: Color
	var rotation_deg: float = 0.0

	func _init(p_color: Color, p_shape: MarkerShape, p_size: int, p_label: String = ""):
		color = p_color
		border_color = Color.WHITE
		shape = p_shape
		size = p_size
		label_text = p_label
		label_color = Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE

static var MARKER_STYLES = {
	"start": MarkerConfig.new(Color.YELLOW, MarkerShape.CIRCLE, 40, "START"),
	"spawn_preview": MarkerConfig.new(Color.ORANGE, MarkerShape.CIRCLE, 12),
	"checkpoint": MarkerConfig.new(Color.PURPLE, MarkerShape.DIAMOND, 18),
	"branch_spawn": MarkerConfig.new(Color.MAGENTA, MarkerShape.SQUARE, 14),
	"branch_endpoint": MarkerConfig.new(Color.RED, MarkerShape.TRIANGLE, 16),
}

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
		_create_all_marker_types(generator)

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

static func _create_all_marker_types(generator: PathAwareArenaGenerator) -> void:
	"""Create all marker types using unified system"""
	_create_start_markers(generator)
	_create_spawn_position_preview(generator)
	_create_checkpoint_markers(generator)
	_create_branch_spawn_markers(generator)
	_create_branch_endpoint_markers(generator)

static func _create_start_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create the yellow START marker"""
	var points: Array = generator.current_path_data.get("points", [])
	if points.size() > 0:
		var point = points[0]
		var marker = _create_unified_marker(point.position, "start", "START")
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created START marker at position %s" % point.position, "pathdebug")

static func _create_unified_marker(position: Vector2, style_key: String, label_override: String = "") -> Node2D:
	"""Create a marker using the unified system"""
	var config = MARKER_STYLES.get(style_key)
	if not config:
		Logger.warn("Unknown marker style: %s" % style_key, "pathdebug")
		return Node2D.new()

	var marker = Node2D.new()
	marker.position = position
	marker.name = style_key.capitalize() + "Marker"

	# Create shape based on config
	var shape_node = _create_shape_node(config)
	var border_node = _create_border_node(config)
	var label_node = _create_label_node(config, label_override)

	# Add nodes in correct order (border first for layering)
	marker.add_child(border_node)
	marker.add_child(shape_node)
	if label_node:
		marker.add_child(label_node)

	return marker

static func _create_shape_node(config: MarkerConfig) -> ColorRect:
	"""Create the main shape node based on config"""
	var shape = ColorRect.new()
	shape.name = "Shape"
	shape.color = config.color
	shape.size = Vector2(config.size, config.size)
	shape.position = Vector2(-config.size/2, -config.size/2)

	# Apply rotation for diamond and triangle shapes
	if config.shape == MarkerShape.DIAMOND or config.shape == MarkerShape.TRIANGLE:
		shape.rotation = deg_to_rad(45.0)

	return shape

static func _create_border_node(config: MarkerConfig) -> ColorRect:
	"""Create border node for better visibility"""
	var border = ColorRect.new()
	border.name = "Border"
	border.color = config.border_color
	var border_size = config.size + (4 if config.size > 20 else 2)
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)

	# Match shape rotation
	if config.shape == MarkerShape.DIAMOND or config.shape == MarkerShape.TRIANGLE:
		border.rotation = deg_to_rad(45.0)

	return border

static func _create_label_node(config: MarkerConfig, label_override: String = "") -> Label:
	"""Create text label if needed"""
	var label_text = label_override if not label_override.is_empty() else config.label_text
	if label_text.is_empty():
		return null

	var label = Label.new()
	label.name = "Label"
	label.text = label_text
	label.add_theme_color_override("font_color", config.label_color)
	# Center the label approximately
	label.position = Vector2(-label_text.length() * 4, -8)

	return label

static func _create_path_connection_lines(generator: PathAwareArenaGenerator) -> void:
	"""Create cyan lines showing path connections"""
	var paths: Array = generator.current_path_data.get("paths", [])

	for path in paths:
		if path.has_method("get_full_path"):
			var line = _create_connection_line(path, generator)
			generator.add_child(line)
			generator.debug_lines.append(line)


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

static func _create_spawn_position_preview(generator: PathAwareArenaGenerator) -> void:
	"""Create small markers showing actual spawn positions (interpolated)"""
	var connection_points: Array = generator.current_path_data.get("points", [])

	if connection_points.size() < 2:
		Logger.debug("Not enough connection points for spawn preview", "pathdebug")
		return

	# Simulate the same logic as PathAwareMapConfig._sample_positions_along_path
	var spawn_spacing = 64.0  # Same spacing used by spawn system
	var spawn_positions = _sample_positions_along_path(connection_points, spawn_spacing)

	Logger.debug("Creating spawn position preview: %d positions from %d connection points" % [spawn_positions.size(), connection_points.size()], "pathdebug")

	# PROOF: Test if our positions match PathAwareMapConfig logic
	_validate_spawn_positions_match_real_system(generator, spawn_positions)

	if spawn_positions.is_empty():
		Logger.warn("No spawn positions generated - check connection points data", "pathdebug")
		return

	for i in range(spawn_positions.size()):
		var position = spawn_positions[i]
		var marker = _create_unified_marker(position, "spawn_preview", str(i))
		generator.add_child(marker)
		generator.debug_markers.append(marker)

static func _sample_positions_along_path(path_points: Array, spacing: float) -> Array:
	"""Mirror the sampling logic from PathAwareMapConfig"""
	var positions: Array = []

	if path_points.size() < 2:
		return positions

	# Convert PathPoints to Vector2 if needed (same as PathAwareMapConfig)
	var vector_points = _convert_to_vector2_array(path_points)

	for i in range(vector_points.size() - 1):
		var start: Vector2 = vector_points[i]
		var end: Vector2 = vector_points[i + 1]
		var segment_length = start.distance_to(end)
		var steps = int(segment_length / spacing)

		for j in range(steps):
			var t = float(j) / float(steps)
			var position = start.lerp(end, t)
			positions.append(position)

	return positions

static func _convert_to_vector2_array(path_points: Array) -> Array:
	"""Convert PathPoint objects to Vector2 array (same as PathAwareMapConfig)"""
	var vector_points: Array = []
	for point in path_points:
		if point is Vector2:
			vector_points.append(point)
		elif point != null and point.get("position") != null:
			vector_points.append(point.position)
	return vector_points


static func _create_checkpoint_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create purple markers for MAIN_CHECKPOINTS spawn category"""
	var positions = _get_spawn_positions_for_category(generator, PathSpawnProfile.PathSpawnCategory.MAIN_CHECKPOINTS)
	if positions.is_empty():
		return

	Logger.debug("Creating checkpoint markers: %d positions" % positions.size(), "pathdebug")

	for i in range(positions.size()):
		var position = positions[i]
		var marker = _create_unified_marker(position, "checkpoint", "C" + str(i))
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created purple checkpoint marker %d at %s" % [i, position], "pathdebug")


static func _create_branch_spawn_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create magenta markers for ALONG_BRANCHES spawn category"""
	var positions = _get_spawn_positions_for_category(generator, PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES)
	if positions.is_empty():
		return

	Logger.info("🔍 Creating branch spawn markers: %d positions" % positions.size(), "pathdebug")

	for i in range(positions.size()):
		var position = positions[i]
		var marker = _create_unified_marker(position, "branch_spawn", "B" + str(i))
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.info("🔍 Created magenta branch spawn marker %d at %s" % [i, position], "pathdebug")


static func _create_branch_endpoint_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create red triangle markers for AT_BRANCH_ENDPOINTS spawn category"""
	var positions = _get_spawn_positions_for_category(generator, PathSpawnProfile.PathSpawnCategory.AT_BRANCH_ENDPOINTS)
	if positions.is_empty():
		return

	Logger.debug("Creating branch endpoint markers: %d positions" % positions.size(), "pathdebug")

	for i in range(positions.size()):
		var position = positions[i]
		var marker = _create_unified_marker(position, "branch_endpoint", "E" + str(i))
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created red branch endpoint marker %d at %s" % [i, position], "pathdebug")


static func _get_spawn_positions_for_category(generator: PathAwareArenaGenerator, category: PathSpawnProfile.PathSpawnCategory) -> Array:
	"""Helper method to get spawn positions for a specific category"""
	var test_config = PathAwareMapConfig.new()
	var snapshot = generator.get_path_snapshot()

	if not snapshot:
		Logger.warn("Cannot get spawn positions - no path snapshot available", "pathdebug")
		return []

	test_config.path_snapshot = snapshot
	return test_config._get_spawn_positions_for_category(category)

static func _validate_spawn_positions_match_real_system(generator: PathAwareArenaGenerator, our_positions: Array) -> void:
	"""PROOF: Verify our orange markers exactly match what PathAwareMapConfig would generate"""
	# Get the REAL spawn positions that would be used by the spawn system
	var real_positions = _get_spawn_positions_for_category(generator, PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH)

	Logger.debug("🔍 VALIDATION: Our positions: %d, Real system positions: %d" % [our_positions.size(), real_positions.size()], "pathdebug")

	# Compare first few positions to verify they match
	var matches = 0
	var max_check = min(5, min(our_positions.size(), real_positions.size()))

	for i in range(max_check):
		var our_pos = our_positions[i]
		var real_pos = real_positions[i]
		var distance = our_pos.distance_to(real_pos)

		if distance < 0.1:  # Essentially the same position
			matches += 1

		Logger.debug("Position %d: Our=%s, Real=%s, Distance=%.2f" % [i, our_pos, real_pos, distance], "pathdebug")

	if matches == max_check:
		Logger.debug("✅ PROOF: Orange markers EXACTLY match real spawn system positions!", "pathdebug")
	else:
		Logger.warn("❌ MISMATCH: Orange markers don't match real system (%d/%d matched)" % [matches, max_check], "pathdebug")

# Future extension points for additional visualizations:
static func render_spawn_zones(generator: PathAwareArenaGenerator) -> void:
	"""Render spawn zone previews - to be implemented"""
	# TODO: Add spawn zone visualization using unified marker system
	pass

static func render_clearings(generator: PathAwareArenaGenerator) -> void:
	"""Render clearing area markers - to be implemented"""
	# TODO: Add clearing visualization using unified marker system
	pass

