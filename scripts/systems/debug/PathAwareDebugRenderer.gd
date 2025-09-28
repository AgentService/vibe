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
		_create_spawn_position_preview(generator)
		_create_checkpoint_markers(generator)
		_create_branch_spawn_markers(generator)
		_create_branch_endpoint_markers(generator)
		_create_around_path_markers(generator)

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
		var marker = _create_spawn_position_marker(position, i)
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

static func _create_spawn_position_marker(position: Vector2, index: int) -> Node2D:
	"""Create a small orange marker for actual spawn positions"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "SpawnPosition_" + str(index)

	# Create small orange circle (more visible than green)
	var circle = ColorRect.new()
	circle.name = "SpawnCircle"
	circle.color = Color.ORANGE
	var size = 12  # Make them bigger and more visible
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)
	marker.add_child(circle)

	# Create black border for better contrast
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.BLACK
	var border_size = size + 2
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)
	marker.add_child(border)
	marker.move_child(border, 0)

	return marker

static func _create_checkpoint_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create purple markers for MAIN_CHECKPOINTS spawn category"""
	# Create a temporary PathAwareMapConfig to get the checkpoint positions
	var test_config = PathAwareMapConfig.new()
	var snapshot = generator.get_path_snapshot()

	if not snapshot:
		Logger.warn("Cannot create checkpoint markers - no path snapshot available", "pathdebug")
		return

	test_config.path_snapshot = snapshot

	# Get the checkpoint positions that the spawn system would use
	var checkpoint_positions = test_config._get_spawn_positions_for_category(PathSpawnProfile.PathSpawnCategory.MAIN_CHECKPOINTS)

	Logger.debug("Creating checkpoint markers: %d positions" % checkpoint_positions.size(), "pathdebug")

	for i in range(checkpoint_positions.size()):
		var position = checkpoint_positions[i]
		var marker = _create_checkpoint_marker(position, i)
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created purple checkpoint marker %d at %s" % [i, position], "pathdebug")

static func _create_checkpoint_marker(position: Vector2, index: int) -> Node2D:
	"""Create a purple marker for MAIN_CHECKPOINTS category"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "MainCheckpoint_" + str(index)

	# Create purple diamond (larger and distinct shape)
	var diamond = ColorRect.new()
	diamond.name = "CheckpointDiamond"
	diamond.color = Color.PURPLE
	var size = 18
	diamond.size = Vector2(size, size)
	diamond.position = Vector2(-size/2, -size/2)
	diamond.rotation = deg_to_rad(45)  # Rotate to make it diamond-shaped
	marker.add_child(diamond)

	# Create white border
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	var border_size = size + 4
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)
	border.rotation = deg_to_rad(45)
	marker.add_child(border)
	marker.move_child(border, 0)

	# Create text label
	var label = Label.new()
	label.name = "CheckpointLabel"
	label.text = "C" + str(index)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-8, -10)
	marker.add_child(label)

	return marker

static func _create_branch_spawn_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create magenta markers for ALONG_BRANCHES spawn category"""
	# Create a temporary PathAwareMapConfig to get the branch positions
	var test_config = PathAwareMapConfig.new()
	var snapshot = generator.get_path_snapshot()

	if not snapshot:
		Logger.warn("Cannot create branch markers - no path snapshot available", "pathdebug")
		return

	test_config.path_snapshot = snapshot

	# Get the branch positions that the spawn system would use
	var branch_positions = test_config._get_spawn_positions_for_category(PathSpawnProfile.PathSpawnCategory.ALONG_BRANCHES)

	Logger.info("🔍 Creating branch spawn markers: %d positions" % branch_positions.size(), "pathdebug")

	for i in range(branch_positions.size()):
		var position = branch_positions[i]
		var marker = _create_branch_spawn_marker(position, i)
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.info("🔍 Created magenta branch spawn marker %d at %s" % [i, position], "pathdebug")

static func _create_branch_spawn_marker(position: Vector2, index: int) -> Node2D:
	"""Create a magenta square marker for ALONG_BRANCHES category"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "BranchSpawn_" + str(index)

	# Create magenta square (square shape to distinguish from circles/diamonds)
	var square = ColorRect.new()
	square.name = "BranchSquare"
	square.color = Color.MAGENTA
	var size = 14
	square.size = Vector2(size, size)
	square.position = Vector2(-size/2, -size/2)
	marker.add_child(square)

	# Create black border for better contrast
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.BLACK
	var border_size = size + 2
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)
	marker.add_child(border)
	marker.move_child(border, 0)

	# Create text label (B for Branch)
	var label = Label.new()
	label.name = "BranchLabel"
	label.text = "B" + str(index)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-8, -8)
	marker.add_child(label)

	return marker

static func _create_branch_endpoint_markers(generator: PathAwareArenaGenerator) -> void:
	"""Create red triangle markers for AT_BRANCH_ENDPOINTS spawn category"""
	# Create a temporary PathAwareMapConfig to get the branch endpoint positions
	var test_config = PathAwareMapConfig.new()
	var snapshot = generator.get_path_snapshot()

	if not snapshot:
		Logger.warn("Cannot create branch endpoint markers - no path snapshot available", "pathdebug")
		return

	test_config.path_snapshot = snapshot

	# Get the branch endpoint positions that the spawn system would use
	var branch_endpoint_positions = test_config._get_spawn_positions_for_category(PathSpawnProfile.PathSpawnCategory.AT_BRANCH_ENDPOINTS)

	Logger.debug("Creating branch endpoint markers: %d positions" % branch_endpoint_positions.size(), "pathdebug")

	for i in range(branch_endpoint_positions.size()):
		var position = branch_endpoint_positions[i]
		var marker = _create_branch_endpoint_marker(position, i)
		generator.add_child(marker)
		generator.debug_markers.append(marker)
		Logger.debug("Created red branch endpoint marker %d at %s" % [i, position], "pathdebug")

static func _create_branch_endpoint_marker(position: Vector2, index: int) -> Node2D:
	"""Create a red triangular marker for AT_BRANCH_ENDPOINTS category"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "BranchEndpoint_" + str(index)

	# Create red triangle using rotated ColorRect (triangle pointing up)
	var triangle = ColorRect.new()
	triangle.name = "BranchTriangle"
	triangle.color = Color.RED
	var size = 16
	triangle.size = Vector2(size, size)
	triangle.position = Vector2(-size/2, -size/2)
	triangle.rotation = deg_to_rad(45)  # Rotate to make it triangular appearance
	marker.add_child(triangle)

	# Create white border for better contrast
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	var border_size = size + 3
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)
	border.rotation = deg_to_rad(45)
	marker.add_child(border)
	marker.move_child(border, 0)

	# Create text label (E for Endpoint)
	var label = Label.new()
	label.name = "EndpointLabel"
	label.text = "E" + str(index)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-8, -8)
	marker.add_child(label)

	return marker

static func _validate_spawn_positions_match_real_system(generator: PathAwareArenaGenerator, our_positions: Array) -> void:
	"""PROOF: Verify our orange markers exactly match what PathAwareMapConfig would generate"""

	# Create a temporary PathAwareMapConfig and populate it like the real system does
	var test_config = PathAwareMapConfig.new()
	var snapshot = generator.get_path_snapshot()

	if not snapshot:
		Logger.warn("Cannot validate - no path snapshot available", "pathdebug")
		return

	test_config.path_snapshot = snapshot

	# Get the REAL spawn positions that would be used by the spawn system
	var real_positions = test_config._get_spawn_positions_for_category(PathSpawnProfile.PathSpawnCategory.ALONG_MAIN_PATH)

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

static func _create_around_path_markers(generator: PathAwareArenaGenerator) -> void:
	"""DISABLED: Create green circle markers for AROUND_PATHS spawn category"""
	Logger.debug("_create_around_path_markers called - DISABLED (logic removed)", "pathdebug")
	# Function disabled - AROUND_PATHS logic removed

static func _create_around_path_marker(position: Vector2, index: int) -> Node2D:
	"""DISABLED: Create a cyan circle marker for AROUND_PATHS category"""
	# Function disabled - AROUND_PATHS logic removed
	return Node2D.new()  # Return empty node for API compatibility