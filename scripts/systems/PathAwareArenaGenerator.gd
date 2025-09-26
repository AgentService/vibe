@tool
extends Node2D
class_name PathAwareArenaGenerator

## Dedicated arena generator for testing path-aware boundary generation
## Completely separate from existing ProceduralArenaGenerator

@export_group("Configuration")
@export var path_config: PathAwareBoundaryConfig
@export var generation_seed: int = 54321
@export var auto_generate_on_ready: bool = false

@export_group("Visual Debug")
@export var show_debug_markers: bool = true
@export var show_path_connections: bool = true
@export var marker_size: float = 8.0
@export var line_width: float = 2.0

# Visual debug nodes
var debug_markers: Array[Node2D] = []
var debug_lines: Array[Line2D] = []

# Generated data
var current_boundary_data: Dictionary = {}
var rng: RandomNumberGenerator

func _ready():
	if auto_generate_on_ready:
		generate_path_aware_arena()

func generate_path_aware_arena():
	print("🛤️ Starting path-aware arena generation...")

	# Clear previous generation
	clear_arena()

	# Initialize RNG
	rng = RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Check configuration
	if not path_config:
		print("No PathAwareBoundaryConfig assigned, creating default configuration")
		path_config = PathAwareBoundaryConfig.new()
		path_config.enable_path_aware_boundaries = true

	if not path_config.enable_path_aware_boundaries:
		print("Path-aware boundaries disabled in configuration")
		return

	# Generate path-aware boundaries
	current_boundary_data = path_config.generate_path_aware_boundaries(rng)

	# Create visual debug markers
	if show_debug_markers:
		_create_debug_markers()

	if show_path_connections:
		_create_debug_connections()

	# Generate tiles (ground and trees)
	_generate_ground_tiles()
	_generate_boundary_trees()

	print("🛤️ Path-aware arena generation completed!")
	print("  - Points generated: ", current_boundary_data.get("points", []).size())
	print("  - Paths generated: ", current_boundary_data.get("paths", []).size())
	print("  - Boundary points: ", current_boundary_data.get("boundary_points", []).size())

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
	var ground_layer = get_node_or_null("Ground")
	if ground_layer and ground_layer is TileMapLayer:
		ground_layer.clear()

	var tree_layer = get_node_or_null("Trees")
	if tree_layer and tree_layer is TileMapLayer:
		tree_layer.clear()

func _create_debug_markers():
	"""Create visual markers for connection points"""
	var points: Array = current_boundary_data.get("points", [])

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
	var paths: Array = current_boundary_data.get("paths", [])

	for path in paths:
		if path is PathAwareBoundaryConfig.BoundaryPath:
			var line = _create_connection_line(path)
			add_child(line)
			debug_lines.append(line)

func _create_connection_line(path: PathAwareBoundaryConfig.BoundaryPath) -> Line2D:
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
	"""Generate ground tiles for walkable corridor areas (light green in image)"""
	var ground_layer = get_node_or_null("Ground")
	if not ground_layer or not ground_layer is TileMapLayer:
		print("Warning: No Ground TileMapLayer found, creating one")
		ground_layer = TileMapLayer.new()
		ground_layer.name = "Ground"
		add_child(ground_layer)

	# Get corridor-based ground positions
	var ground_positions = path_config.get_ground_corridor_positions(rng)
	if ground_positions.is_empty():
		print("No corridor ground positions available")
		return

	# Ground tile configuration (matching forest arena)
	var ground_source_id = 0
	var ground_atlas_coords = Vector2i(3, 0)  # Grass tile coordinates
	var tile_size = 16

	# Place ground tiles only in path corridors
	for world_pos in ground_positions:
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))
		ground_layer.set_cell(tile_pos, ground_source_id, ground_atlas_coords)

	print("Generated ", ground_positions.size(), " corridor ground tiles")

func _generate_boundary_trees():
	"""Generate trees in non-corridor areas (dark green in image)"""
	var tree_layer = get_node_or_null("Trees")
	if not tree_layer or not tree_layer is TileMapLayer:
		print("Warning: No Trees TileMapLayer found, creating one")
		tree_layer = TileMapLayer.new()
		tree_layer.name = "Trees"
		add_child(tree_layer)

	# Get corridor-based boundary tree positions
	var tree_positions = path_config.get_boundary_tree_positions(rng)
	if tree_positions.is_empty():
		print("No boundary tree positions available")
		return

	# Tree tile configuration (matching forest arena)
	var tree_source_id = 0
	var tile_size = 16

	for world_pos in tree_positions:
		# Convert world position to tile position
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

		# Get random tree tile variant
		var tree_tile = path_config.get_random_tree_tile(rng)

		# Place tree
		tree_layer.set_cell(tile_pos, tree_source_id, tree_tile)

	print("Placed ", tree_positions.size(), " corridor boundary trees")

# Editor tool functionality
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not path_config:
		warnings.append("PathAwareBoundaryConfig is required for arena generation")

	return warnings

# Manual generation trigger for testing
func generate_with_new_seed():
	generation_seed += 1
	generate_path_aware_arena()

# Get generated data for external use
func get_path_points() -> Array:
	return current_boundary_data.get("points", [])

func get_path_connections() -> Array:
	return current_boundary_data.get("paths", [])

func get_boundary_tree_positions() -> Array:
	return current_boundary_data.get("boundary_points", [])
