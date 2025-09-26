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

@export_group("Visual Debug")
@export var show_debug_markers: bool = true
@export var show_path_connections: bool = true
@export var marker_size: float = 8.0
@export var line_width: float = 2.0

# Layer name constants
const GROUND_LAYER_NAME = "Ground2"
const TREES_LAYER_NAME = "Trees2"

# Visual debug nodes
var debug_markers: Array[Node2D] = []
var debug_lines: Array[Line2D] = []

# System components
var path_generator: DungeonPathGenerator
var tree_generator: TreeBoundaryGenerator

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

	# Create tree boundary generator system
	tree_generator = TreeBoundaryGenerator.new()
	tree_generator.tree_config = tree_config
	add_child(tree_generator)

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

	current_tree_data = tree_generator.generate_tree_boundaries(current_path_data, generation_seed)

	# Phase 3: Create visual debug markers
	if show_debug_markers:
		_create_debug_markers()

	if show_path_connections:
		_create_debug_connections()

	# Phase 4: Generate tiles (ground and trees)
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
	var ground_layer = get_node_or_null(GROUND_LAYER_NAME)
	if ground_layer and ground_layer is TileMapLayer:
		ground_layer.clear()

	var tree_layer = get_node_or_null(TREES_LAYER_NAME)
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
	"""Generate ground tiles for walkable corridor areas using DungeonPathGenerator data"""
	var ground_layer = get_node_or_null(GROUND_LAYER_NAME)
	if not ground_layer or not ground_layer is TileMapLayer:
		Logger.warn("No %s TileMapLayer found in scene, skipping ground tile generation" % GROUND_LAYER_NAME, "pathgen")
		return

	# Clear existing tiles first
	ground_layer.clear()
	Logger.debug("Using existing Ground TileMapLayer for tile placement", "pathgen")

	# Get ground positions from DungeonPathGenerator
	var ground_positions = path_generator.get_ground_positions()
	if ground_positions.is_empty():
		Logger.warn("No corridor ground positions available from path generator", "pathgen")
		return

	# Ground tile configuration using forest tileset
	var ground_source_id = 0
	var ground_atlas_coords = Vector2i(3, 0)  # First tile for ground/grass
	var tile_size = 48  # Forest tileset uses 48x48 tiles

	# Place ground tiles only in path corridors
	for world_pos in ground_positions:
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))
		ground_layer.set_cell(tile_pos, ground_source_id, ground_atlas_coords)

	Logger.info("Generated %d corridor ground tiles with forest tileset" % ground_positions.size(), "pathgen")

func _generate_boundary_trees():
	"""Generate trees using TreeBoundaryGenerator data that responds to path layout"""
	var tree_layer = get_node_or_null(TREES_LAYER_NAME)
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
	var tree_atlas_coords = Vector2i(0, 28)  # Second tile for trees
	var tile_size = 48  # Forest tileset uses 48x48 tiles

	for world_pos in current_tree_data:
		# Convert world position to tile position
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

		# Place tree tile
		tree_layer.set_cell(tile_pos, tree_source_id, tree_atlas_coords)

	Logger.info("Placed %d boundary trees with forest tileset" % current_tree_data.size(), "treegen")

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
