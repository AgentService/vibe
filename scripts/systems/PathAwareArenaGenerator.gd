@tool
extends Node2D
class_name PathAwareArenaGenerator

## Dedicated arena generator for testing path-aware boundary generation
## Completely separate from existing ProceduralArenaGenerator

@export_group("Configuration")
@export var path_config: PathConfiguration
@export var tree_config: TreeBoundaryConfiguration
@export var generation_seed: int = 54321
@export var auto_generate_on_ready: bool = false
@export var arena_base_radius: float = 600.0

@export_group("Visual Debug")
@export var show_debug_markers: bool = true
@export var show_path_connections: bool = true
@export var marker_size: float = 118.0
@export var line_width: float = 5.0

# Layer name constants
const BASE_LAYER_NAME = "BaseGreen"        # Renamed from "Base" - base layer
const GROUND_LAYER_NAME = "Green"          # Renamed from "Ground2" - first extension layer
const GROUND2_LAYER_NAME = "DarkGreen"     # Second extension layer - deeper forest
const TREES_LAYER_NAME = "Trees2"          # In YSort_Objects - needs depth sorting

# Visual debug nodes
var debug_markers: Array[Node2D] = []
var debug_lines: Array[Line2D] = []

# System components
var path_generator: DungeonPathGenerator
var tree_generator: Node

# Generated data
var current_path_data: Dictionary = {}
var current_tree_data: Array[Vector2] = []
var rng: RandomNumberGenerator

func _ready():
	# Initialize system components
	_initialize_systems()

	if auto_generate_on_ready:
		generate_path_aware_arena()

## Initialize the two-system architecture
func _initialize_systems():
	# Ensure we have valid configurations first
	if not path_config:
		Logger.info("Creating default PathConfiguration", "pathgen")
		path_config = PathConfiguration.new()

	if not tree_config:
		Logger.info("Creating default TreeBoundaryConfiguration", "treegen")
		tree_config = TreeBoundaryConfiguration.new()

	# Create path generator system
	path_generator = DungeonPathGenerator.new()
	path_generator.path_config = path_config
	add_child(path_generator)

	# Create tree boundary generator system (using script resource to avoid class registration issues)
	var tree_script = load("res://scripts/systems/TreeBoundaryGenerator.gd")
	var tree_node = Node.new()
	tree_node.set_script(tree_script)
	tree_node.tree_config = tree_config
	add_child(tree_node)
	tree_generator = tree_node

	Logger.debug("Initialized DungeonPathGenerator and TreeBoundaryGenerator systems", "pathgen")

func generate_path_aware_arena():
	Logger.info("🛤️ Starting path-aware arena generation...", "pathgen")

	# Clear previous generation
	clear_arena()

	# Ensure systems are initialized
	if not path_generator or not tree_generator:
		Logger.warn("Systems not initialized, calling _initialize_systems()", "pathgen")
		_initialize_systems()

	# Initialize RNG
	rng = RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Validate configurations
	if not _validate_configurations():
		Logger.warn("Invalid configurations, aborting generation", "pathgen")
		return

	# Phase 1: Generate paths using DungeonPathGenerator
	if not path_generator:
		Logger.error("DungeonPathGenerator is null, cannot generate paths", "pathgen")
		return

	current_path_data = path_generator.generate_dungeon_paths(generation_seed)
	if current_path_data.is_empty():
		Logger.warn("No path data generated, aborting arena generation", "pathgen")
		return

	# Phase 2: Generate tree boundaries using TreeBoundaryGenerator (Path Drives → Boundary Responds)
	if not tree_generator:
		Logger.error("TreeBoundaryGenerator is null, cannot generate trees", "treegen")
		return

	# Trees should avoid the complete visual area (path corridors only) for natural boundaries
	# path_extension_width parameter removed - no extension data needed
	current_tree_data = tree_generator.generate_tree_boundaries(current_path_data, generation_seed, {})

	# Phase 3: Create visual debug markers
	Logger.debug("Debug settings: show_debug_markers=%s, show_path_connections=%s" % [show_debug_markers, show_path_connections], "pathdebug")

	if show_debug_markers:
		Logger.debug("Creating debug markers...", "pathdebug")
		_create_debug_markers()
		_create_main_path_markers()
	else:
		Logger.debug("Debug markers disabled, skipping creation", "pathdebug")

	if show_path_connections:
		Logger.debug("Creating debug connections...", "pathdebug")
		_create_debug_connections()
	else:
		Logger.debug("Debug connections disabled, skipping creation", "pathdebug")

	# Phase 4: Generate tiles (arena base, ground corridors, and trees)
	_generate_arena_base()
	_generate_ground_tiles()
	_generate_boundary_trees()

	Logger.info("🛤️ Path-aware arena generation completed!", "pathgen")
	Logger.info("  - Points generated: %d" % current_path_data.get("points", []).size(), "pathgen")
	Logger.info("  - Paths generated: %d" % current_path_data.get("paths", []).size(), "pathgen")
	Logger.info("  - Trees generated: %d" % current_tree_data.size(), "pathgen")

func clear_arena():
	"""Clear all generated content"""
	# Clear debug markers
	for marker in debug_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	debug_markers.clear()

	# Clear debug lines
	for line in debug_lines:
		if is_instance_valid(line):
			line.queue_free()
	debug_lines.clear()

	# Clear tile map layers
	var base_layer = _find_layer_node(BASE_LAYER_NAME)
	if base_layer and base_layer is TileMapLayer:
		base_layer.clear()

	var ground_layer = _find_layer_node(GROUND_LAYER_NAME)
	if ground_layer and ground_layer is TileMapLayer:
		ground_layer.clear()

	var ground2_layer = _find_layer_node(GROUND2_LAYER_NAME)
	if ground2_layer and ground2_layer is TileMapLayer:
		ground2_layer.clear()

	var tree_layer = _find_layer_node(TREES_LAYER_NAME)
	if tree_layer and tree_layer is TileMapLayer:
		tree_layer.clear()

## Validate that both configurations are properly assigned
func _validate_configurations() -> bool:
	var is_valid = true

	if not path_config:
		Logger.warn("No PathConfiguration assigned, creating default", "pathgen")
		path_config = PathConfiguration.new()
		# Only set if path_generator exists
		if path_generator:
			path_generator.path_config = path_config

	if not tree_config:
		Logger.warn("No TreeBoundaryConfiguration assigned, creating default", "treegen")
		tree_config = TreeBoundaryConfiguration.new()
		# Only set if tree_generator exists
		if tree_generator:
			tree_generator.tree_config = tree_config

	if not path_config or not path_config.enable_path_generation:
		Logger.warn("Path generation disabled in configuration", "pathgen")
		is_valid = false

	return is_valid

func _create_debug_markers():
	"""Create visual markers - just the START marker for now"""
	var points: Array = current_path_data.get("points", [])
	Logger.debug("_create_debug_markers called with %d points" % points.size(), "pathdebug")

	# Only create the START marker (first point)
	if points.size() > 0:
		var point = points[0]
		var marker = _create_start_point_marker(point.position)
		Logger.debug("Created START marker at position %s" % point.position, "pathdebug")
		add_child(marker)
		debug_markers.append(marker)

	Logger.debug("Finished creating START marker", "pathdebug")

func _create_main_path_markers():
	"""Create numbered markers for each point along the main path chain"""
	var paths: Array = current_path_data.get("paths", [])
	var connection_points: Array = current_path_data.get("points", [])
	Logger.debug("Creating main path markers - paths: %d, connection points: %d, chain_length: %d" % [paths.size(), connection_points.size(), path_config.chain_length if path_config else 0], "pathdebug")

	# Use connection points instead of path points - these represent the main chain
	# Skip the first point (index 0) since we already have START marker there
	for i in range(1, connection_points.size()):
		var point = connection_points[i]
		var marker = _create_main_path_point_marker(point.position, i)
		add_child(marker)
		debug_markers.append(marker)
		Logger.debug("Created main path marker %d at position %s" % [i, point.position], "pathdebug")


func _create_main_path_point_marker(position: Vector2, point_index: int) -> Node2D:
	"""Create a blue numbered marker for main path points"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "MainPathPoint_" + str(point_index)

	# Create blue circle using ColorRect
	var circle = ColorRect.new()
	circle.name = "PathCircle"
	circle.color = Color.BLUE
	var size = 24  # Smaller than START marker
	circle.size = Vector2(size, size)
	circle.position = Vector2(-size/2, -size/2)  # Center it
	marker.add_child(circle)

	# Create white border
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	var border_size = size + 3
	border.size = Vector2(border_size, border_size)
	border.position = Vector2(-border_size/2, -border_size/2)  # Center it
	marker.add_child(border)
	marker.move_child(border, 0)  # Put border behind circle

	# Create text label for point number
	var label = Label.new()
	label.name = "PathLabel"
	label.text = str(point_index)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-5, -8)  # Center text roughly
	marker.add_child(label)

	return marker

## Create a special start point marker (larger and different color)
func _create_start_point_marker(position: Vector2) -> Node2D:
	"""Create a special visual marker for the start point using simple ColorRect approach"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "StartPointMarker"

	# Create yellow circle using ColorRect (simple and visible)
	var circle = ColorRect.new()
	circle.name = "StartCircle"
	circle.color = Color.YELLOW
	circle.size = Vector2(40, 40)  # 40x40 pixel circle
	circle.position = Vector2(-20, -20)  # Center it
	marker.add_child(circle)

	# Create border using another ColorRect
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color.WHITE
	border.size = Vector2(44, 44)  # Slightly larger for border effect
	border.position = Vector2(-22, -22)  # Center it
	marker.add_child(border)
	marker.move_child(border, 0)  # Put border behind circle

	# Create text label
	var label = Label.new()
	label.name = "StartLabel"
	label.text = "START"
	label.add_theme_color_override("font_color", Color.BLACK)
	label.position = Vector2(-15, -5)  # Center text roughly
	marker.add_child(label)

	return marker

## Helper method to find TileMapLayer nodes
func _find_layer_node(layer_name: String) -> TileMapLayer:
	Logger.debug("_find_layer_node called with: '%s'" % layer_name, "pathgen")

	# BaseGreen, Green, and Dark Green layers are outside YSort_Objects (don't need sorting)
	if layer_name == BASE_LAYER_NAME or layer_name == GROUND_LAYER_NAME or layer_name == GROUND2_LAYER_NAME:
		Logger.debug("Layer '%s' matches direct access condition" % layer_name, "pathgen")
		var layer_node = get_node_or_null(layer_name)
		Logger.debug("get_node_or_null('%s') returned: %s" % [layer_name, "found" if layer_node else "null"], "pathgen")

		if layer_node and layer_node is TileMapLayer:
			Logger.debug("Layer '%s' found and is TileMapLayer" % layer_name, "pathgen")
			return layer_node as TileMapLayer
		else:
			Logger.debug("Layer '%s' failed type check - node: %s, is TileMapLayer: %s" % [
				layer_name, "found" if layer_node else "null", layer_node is TileMapLayer if layer_node else "N/A"
			], "pathgen")
	else:
		# Trees2 layer is in YSort_Objects (needs depth sorting)
		var ysort_container = get_node_or_null("YSort_Objects")
		if ysort_container:
			var nested_node = ysort_container.get_node_or_null(layer_name)
			if nested_node and nested_node is TileMapLayer:
				return nested_node as TileMapLayer

	return null

## Calculate bounding rectangle that covers all generated tree positions
func _calculate_tree_coverage_bounds() -> Rect2:
	if current_tree_data.is_empty():
		return Rect2()  # No trees, return empty rect

	# Find min/max positions from tree data
	var min_pos = current_tree_data[0]
	var max_pos = current_tree_data[0]

	for tree_pos in current_tree_data:
		min_pos.x = min(min_pos.x, tree_pos.x)
		min_pos.y = min(min_pos.y, tree_pos.y)
		max_pos.x = max(max_pos.x, tree_pos.x)
		max_pos.y = max(max_pos.y, tree_pos.y)

	# Create bounding rectangle
	var size = max_pos - min_pos
	return Rect2(min_pos, size)

func _generate_arena_base():
	"""Generate base ground layer covering full tree generation area plus extension"""
	var base_layer = _find_layer_node(BASE_LAYER_NAME)
	if not base_layer or not base_layer is TileMapLayer:
		Logger.warn("No %s TileMapLayer found in scene, skipping arena base generation" % BASE_LAYER_NAME, "pathgen")
		return

	# Arena base tile configuration
	var base_source_id = 0
	var base_atlas_coords = Vector2i(3, 0)  # Base ground tile (3x3)
	var tile_size = 48  # Forest tileset uses 48x48 tiles
	var base_tiles_placed = 0

	# Calculate bounding box from actual tree positions
	var coverage_bounds = _calculate_tree_coverage_bounds()

	# If no trees or invalid bounds, fall back to arena_base_radius
	if coverage_bounds == Rect2():
		var half_radius = arena_base_radius
		coverage_bounds = Rect2(-half_radius, -half_radius, half_radius * 2, half_radius * 2)
	else:
		# Extend tree coverage by arena_base_radius in all directions
		var extension = arena_base_radius
		coverage_bounds = coverage_bounds.grow(extension)

	# Align to tile grid
	var start_x = int(coverage_bounds.position.x / tile_size) * tile_size
	var start_y = int(coverage_bounds.position.y / tile_size) * tile_size
	var end_x = int((coverage_bounds.position.x + coverage_bounds.size.x) / tile_size) * tile_size
	var end_y = int((coverage_bounds.position.y + coverage_bounds.size.y) / tile_size) * tile_size

	# Fill rectangular area with base tiles covering all trees and beyond
	for x in range(start_x, end_x + tile_size, tile_size):
		for y in range(start_y, end_y + tile_size, tile_size):
			var tile_pos = Vector2i(int(x / tile_size), int(y / tile_size))
			base_layer.set_cell(tile_pos, base_source_id, base_atlas_coords)
			base_tiles_placed += 1

	Logger.info("Generated %d arena base tiles covering tree area + %dpx extension" % [
		base_tiles_placed,
		int(arena_base_radius)
	], "pathgen")

func _create_debug_connections():
	"""Create visual lines showing path connections"""
	var paths: Array = current_path_data.get("paths", [])

	for path in paths:
		if path.has_method("get_full_path"):
			var line = _create_connection_line(path)
			add_child(line)
			debug_lines.append(line)

func _create_connection_line(path) -> Line2D:
	"""Create a visual line for a path connection"""
	var line = Line2D.new()
	line.name = "PathConnection"
	line.width = line_width
	line.default_color = Color.CYAN
	line.antialiased = true

	# Add points for the full path
	var path_points = path.get_full_path()
	for point in path_points:
		line.add_point(point)

	return line

func _generate_ground_tiles():
	"""Simplified ground tile generation - just clear layers, trees will handle their own ground tiles"""
	Logger.debug("_generate_ground_tiles() called - simplified approach", "pathgen")

	var green_layer = _find_layer_node(GROUND_LAYER_NAME)
	var dark_layer = _find_layer_node(GROUND2_LAYER_NAME)

	# Clear existing tiles first
	if green_layer and green_layer is TileMapLayer:
		green_layer.clear()
	if dark_layer and dark_layer is TileMapLayer:
		dark_layer.clear()

	Logger.info("Ground tile layers cleared - trees will place their own green ground tiles", "pathgen")

func _generate_boundary_trees():
	"""Generate trees using TreeBoundaryGenerator data that responds to path layout"""
	var tree_layer = _find_layer_node(TREES_LAYER_NAME)
	var green_layer = _find_layer_node(GROUND_LAYER_NAME)  # Use Green layer for tree ground placement

	if not tree_layer or not tree_layer is TileMapLayer:
		Logger.warn("No %s TileMapLayer found in scene, skipping tree generation" % TREES_LAYER_NAME, "treegen")
		return

	# Clear existing tiles first
	tree_layer.clear()
	Logger.debug("Using existing Trees TileMapLayer for tile placement", "treegen")

	# Get tree positions from TreeBoundaryGenerator (these already avoid path corridors)
	if current_tree_data.is_empty():
		Logger.warn("No boundary tree positions available from tree generator", "treegen")
		return

	# Tree tile configuration using forest tileset
	var tree_source_id = 0
	var tree_ground_atlas_coords = Vector2i(0, 12)  # Ground beneath trees - use Green layer tileset (0,12)
	var tile_size = 48  # Forest tileset uses 48x48 tiles
	var ground_tiles_placed = 0

	for world_pos in current_tree_data:
		# Convert world position to tile position
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

		# Skip if tile or nearby tiles already have trees (prevents branch overlap density)
		var has_nearby_tree = false
		var check_radius = 1  # Check 3x3 area around position
		for dx in range(-check_radius, check_radius + 1):
			for dy in range(-check_radius, check_radius + 1):
				var check_pos = tile_pos + Vector2i(dx, dy)
				if tree_layer.get_cell_source_id(check_pos) != -1:
					has_nearby_tree = true
					break
			if has_nearby_tree:
				break

		if has_nearby_tree:
			continue

		# Get random tree variant from TreeBoundaryConfiguration for visual diversity
		var selected_tree_variant = tree_config.get_random_tree_tile()  # Zero-allocation RNG
		var tree_alternative_id = tree_config.get_tree_alternative_tile()

		# Place tree tile with selected variant using alternative tile 1
		tree_layer.set_cell(tile_pos, tree_source_id, selected_tree_variant, tree_alternative_id)

		# Place simple green ground tile beneath tree (simplified approach)
		if green_layer and green_layer is TileMapLayer:
			# Always place green tiles (0,12) under trees in Green layer
			var ground_tile_pos = tile_pos  # Same position as tree
			green_layer.set_cell(ground_tile_pos, tree_source_id, Vector2i(0, 12))
			ground_tiles_placed += 1

	Logger.info("Placed %d boundary trees (using alternative tile 1 for variants: 0,28 & 9,28) and %d green ground tiles" % [current_tree_data.size(), ground_tiles_placed], "treegen")

# Editor tool functionality
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not path_config:
		warnings.append("PathConfiguration is required for path generation")

	if not tree_config:
		warnings.append("TreeBoundaryConfiguration is required for tree boundary generation")

	return warnings

# Manual generation trigger for testing
func generate_with_new_seed():
	generation_seed += 1
	generate_path_aware_arena()

# Get generated data for external use
func get_path_points() -> Array:
	return current_path_data.get("points", [])

func get_path_connections() -> Array:
	return current_path_data.get("paths", [])

func get_boundary_tree_positions() -> Array[Vector2]:
	return current_tree_data

## Create a comprehensive path snapshot for spawning systems
func get_path_snapshot() -> PathAwarePathSnapshot:
	var snapshot = PathAwarePathSnapshot.new()

	# Core path data
	snapshot.main_path_points = current_path_data.get("points", [])
	snapshot.branch_data = _extract_branch_info()
	snapshot.connection_points = current_path_data.get("connections", [])

	# Derived spatial analysis
	snapshot.path_corridors = _calculate_corridors()
	snapshot.clearings = _detect_clearings()
	snapshot.boundary_zones = _analyze_boundaries()
	snapshot.endpoint_positions = _identify_endpoints()
	snapshot.checkpoint_positions = _generate_checkpoints()

	# Metadata
	snapshot.total_arena_bounds = _calculate_arena_bounds()
	snapshot.generation_seed = generation_seed
	snapshot.generation_timestamp = Time.get_ticks_msec()

	Logger.debug("Created path snapshot: %s" % snapshot.get_debug_summary(), "pathgen")
	return snapshot

## Extract branch information from current path data
func _extract_branch_info() -> Array[PathAwarePathSnapshot.PathBranchInfo]:
	var branches: Array[PathAwarePathSnapshot.PathBranchInfo] = []
	var paths: Array = current_path_data.get("paths", [])

	for i in range(paths.size()):
		var path = paths[i]
		var branch = PathAwarePathSnapshot.PathBranchInfo.new(i)

		if path.has_method("get_full_path"):
			branch.points = path.get_full_path()
			branch.calculate_length()

		# Determine branch type based on path structure
		if i == 0:
			branch.branch_type = "main"
		else:
			branch.branch_type = "secondary"

		# Set parent connection point (first point of the branch)
		if not branch.points.is_empty():
			branch.parent_connection_point = branch.points[0]

		branches.append(branch)

	return branches

## Calculate path corridors with width information
func _calculate_corridors() -> Array[PathAwarePathSnapshot.PathCorridor]:
	var corridors: Array[PathAwarePathSnapshot.PathCorridor] = []
	var paths: Array = current_path_data.get("paths", [])

	for i in range(paths.size()):
		var path = paths[i]
		var corridor = PathAwarePathSnapshot.PathCorridor.new()

		if path.has_method("get_full_path"):
			corridor.center_line = path.get_full_path()
			corridor.width = 64.0  # Default corridor width
			corridor.corridor_type = "main" if i == 0 else "branch"
			corridor.calculate_bounds()
			corridors.append(corridor)

	return corridors

## Detect clearing areas between paths and boundaries
func _detect_clearings() -> Array[PathAwarePathSnapshot.PathClearing]:
	var clearings: Array[PathAwarePathSnapshot.PathClearing] = []
	var paths: Array = current_path_data.get("paths", [])

	# Simple clearing detection: create clearings at path intersections and endpoints
	var all_points: Array = current_path_data.get("points", [])

	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue

		# Check if this point is an intersection or endpoint
		var connections = _count_connections_at_point(position)

		if connections >= 2:  # Intersection
			var clearing = PathAwarePathSnapshot.PathClearing.new(position, 80.0)
			clearing.clearing_type = "intersection"
			clearing.spawn_priority = 1.5
			clearings.append(clearing)
		elif connections == 1:  # Endpoint
			var clearing = PathAwarePathSnapshot.PathClearing.new(position, 60.0)
			clearing.clearing_type = "endpoint"
			clearing.spawn_priority = 2.0
			clearings.append(clearing)

	# Add natural clearings between paths
	_add_natural_clearings(clearings, all_points)

	Logger.debug("Detected %d clearings" % clearings.size(), "pathgen")
	return clearings

## Add natural clearings in open areas
func _add_natural_clearings(clearings: Array[PathAwarePathSnapshot.PathClearing], path_points: Array) -> void:
	# Create a grid to find open areas
	var grid_size = 100
	var bounds = _calculate_arena_bounds()

	for x in range(int(bounds.position.x), int(bounds.position.x + bounds.size.x), grid_size):
		for y in range(int(bounds.position.y), int(bounds.position.y + bounds.size.y), grid_size):
			var test_point = Vector2(x, y)

			# Check if this point is far enough from paths and trees
			if _is_suitable_for_clearing(test_point):
				var clearing = PathAwarePathSnapshot.PathClearing.new(test_point, 50.0)
				clearing.clearing_type = "natural"
				clearing.spawn_priority = 1.0
				clearings.append(clearing)

## Check if a point is suitable for a natural clearing
func _is_suitable_for_clearing(point: Vector2) -> bool:
	var min_distance_to_path = 80.0
	var min_distance_to_tree = 60.0

	# Check distance to paths
	var nearest_path_distance = _get_distance_to_nearest_path_point(point)
	if nearest_path_distance < min_distance_to_path:
		return false

	# Check distance to trees
	for tree_pos in current_tree_data:
		if point.distance_to(tree_pos) < min_distance_to_tree:
			return false

	return true

## Get distance to nearest path point
func _get_distance_to_nearest_path_point(point: Vector2) -> float:
	var min_distance = float('inf')
	var all_points: Array = current_path_data.get("points", [])

	for path_point in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not path_point is Vector2:
			continue

		var distance = point.distance_to(path_point)
		if distance < min_distance:
			min_distance = distance

	return min_distance if min_distance != float('inf') else 1000.0

## Count how many path connections exist at a specific point
func _count_connections_at_point(point: Vector2, tolerance: float = 20.0) -> int:
	var connection_count = 0
	var paths: Array = current_path_data.get("paths", [])

	for path in paths:
		if path.has_method("get_full_path"):
			var path_points = path.get_full_path()
			for path_point in path_points:
				if point.distance_to(path_point) <= tolerance:
					connection_count += 1
					break  # Only count each path once

	return connection_count

## Analyze boundary zones from tree data
func _analyze_boundaries() -> Array[PathAwarePathSnapshot.PathBoundaryZone]:
	var boundaries: Array[PathAwarePathSnapshot.PathBoundaryZone] = []

	for tree_pos in current_tree_data:
		var boundary = PathAwarePathSnapshot.PathBoundaryZone.new(tree_pos, 32.0)
		boundary.zone_type = "tree"
		boundary.avoidance_priority = 1.0
		boundaries.append(boundary)

	Logger.debug("Analyzed %d boundary zones" % boundaries.size(), "pathgen")
	return boundaries

## Identify endpoint positions for boss spawns
func _identify_endpoints() -> Array[Vector2]:
	var endpoints: Array[Vector2] = []
	var all_points: Array = current_path_data.get("points", [])

	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue

		# A point is an endpoint if it has exactly one connection
		if _count_connections_at_point(position) == 1:
			endpoints.append(position)

	Logger.debug("Identified %d endpoints" % endpoints.size(), "pathgen")
	return endpoints

## Generate checkpoint positions along paths
func _generate_checkpoints() -> Array[Vector2]:
	var checkpoints: Array[Vector2] = []
	var paths: Array = current_path_data.get("paths", [])
	var checkpoint_spacing = 120.0  # Distance between checkpoints

	for path in paths:
		if path.has_method("get_full_path"):
			var path_points = path.get_full_path()
			var current_distance = 0.0

			for i in range(path_points.size() - 1):
				var start = path_points[i]
				var end = path_points[i + 1]
				var segment_length = start.distance_to(end)

				# Add checkpoints along this segment
				while current_distance + checkpoint_spacing < segment_length:
					current_distance += checkpoint_spacing
					var t = current_distance / segment_length
					var checkpoint = start.lerp(end, t)
					checkpoints.append(checkpoint)

				current_distance += segment_length - current_distance

	Logger.debug("Generated %d checkpoints" % checkpoints.size(), "pathgen")
	return checkpoints

## Calculate total arena bounds
func _calculate_arena_bounds() -> Rect2:
	var all_positions: Array[Vector2] = []

	# Include path points
	var all_points: Array = current_path_data.get("points", [])
	for position in all_points:
		# DungeonPathGenerator returns Array[Vector2] points
		if not position is Vector2:
			continue
		all_positions.append(position)

	# Include tree positions
	all_positions.append_array(current_tree_data)

	if all_positions.is_empty():
		return Rect2(-arena_base_radius, -arena_base_radius, arena_base_radius * 2, arena_base_radius * 2)

	# Find min/max positions
	var min_pos = all_positions[0]
	var max_pos = all_positions[0]

	for pos in all_positions:
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	# Add padding
	var padding = 100.0
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)

	var bounds = Rect2(min_pos, max_pos - min_pos)
	Logger.debug("Calculated arena bounds: %s" % bounds, "pathgen")
	return bounds

## Calculate the length of a path given its points
func _calculate_path_length(points: Array[Vector2]) -> float:
	if points.size() < 2:
		return 0.0

	var length = 0.0
	for i in range(points.size() - 1):
		length += points[i].distance_to(points[i + 1])

	return length

## Get comprehensive debug information from both systems
func get_system_debug_info() -> Dictionary:
	var debug_info = {
		"path_system": {},
		"tree_system": {},
		"orchestration": {
			"generation_seed": generation_seed,
			"path_data_size": current_path_data.size(),
			"tree_data_size": current_tree_data.size()
		}
	}

	if path_generator:
		debug_info.path_system = path_generator.get_debug_info()

	if tree_generator:
		debug_info.tree_system = tree_generator.get_debug_info()

	return debug_info
