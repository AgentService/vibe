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
@export var marker_size: float = 8.0
@export var line_width: float = 2.0

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
	if show_debug_markers:
		_create_debug_markers()

	if show_path_connections:
		_create_debug_connections()

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
	"""Create visual markers for connection points"""
	var points: Array = current_path_data.get("points", [])

	for i in range(points.size()):
		var point = points[i]
		var marker = _create_point_marker(point.position, i)
		add_child(marker)
		debug_markers.append(marker)

func _create_point_marker(position: Vector2, point_id: int) -> Node2D:
	"""Create a visual marker for a connection point"""
	var marker = Node2D.new()
	marker.position = position
	marker.name = "PointMarker_" + str(point_id)

	# Create circle visual
	var circle = Node2D.new()
	circle.name = "Circle"
	marker.add_child(circle)

	# Draw method for the circle
	var draw_script = GDScript.new()
	draw_script.source_code = """
extends Node2D

var radius: float = %f
var color: Color = Color.RED
var point_id: int = %d

func _draw():
	# Draw filled circle
	draw_circle(Vector2.ZERO, radius, color)
	# Draw border
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)

	# Draw point ID text
	var font = ThemeDB.fallback_font
	var text = str(point_id)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(-text_size.x * 0.5, text_size.y * 0.25), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
""" % [marker_size, point_id]

	circle.set_script(draw_script)
	circle.call("set", "radius", marker_size)
	circle.call("set", "color", Color.RED)
	circle.call("set", "point_id", point_id)

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
		var selected_tree_variant = tree_config.get_random_tree_tile(rng)
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
