@tool
class_name SimpleBoundaryConfig
extends Resource

## Simplified boundary generation configuration
## Replaces the complex organic/rectangular boundary system with intuitive controls



@export_group("Boundary Shape")
## Boundary shape type
@export_enum("Circle", "Rectangle") var base_shape: String = "Circle"

## Shape length multiplier (1.0 = circle, >1.0 = elongated)
@export_range(0.5, 3.0, 0.1) var shape_length: float = 1.0

## Shape height multiplier (1.0 = circle, >1.0 = tall)
@export_range(0.5, 3.0, 0.1) var shape_height: float = 1.0

@export_group("Simple Size Configuration")
## Arena width in tiles - simple direct control
@export_range(20, 999, 5) var arena_width: int = 150

## Arena height in tiles - simple direct control
@export_range(20, 999, 5) var arena_height: int = 150

@export_group("Ground Coverage")
## Ground tiles extension beyond boundary trees (tiles)
@export_range(5, 50, 5) var ground_extension: int = 15

@export_group("Tree Configuration")
## Tree tile variants to use - now supports alternative trees with bigger collision
@export var tree_tile_variants: Array[Vector2i] = [Vector2i(0, 28), Vector2i(9, 28)]

## Horizontal spacing between trees in the same row (pixels)
@export_range(16, 128, 8) var tree_spacing_horizontal: int = 48

## Vertical spacing between tree rows (pixels) - can be different from horizontal
@export_range(16, 128, 8) var tree_spacing_vertical: int = 32

## Number of tree rows outside the arena (for escape-proof boundaries)
@export_range(1, 6, 1) var tree_row_count: int = 3

## Tree placement density (0.9+ recommended for gap-free boundaries)
@export_range(0.1, 1.0, 0.05) var tree_density: float = 0.95

@export_group("Natural Placement")
## Enable staggered net-like placement pattern (alternating row offsets)
@export var enable_staggered_placement: bool = true

## Randomness in tree placement (0=perfect grid, 1=high variation)
@export_range(0.0, 1.0, 0.1) var placement_randomness: float = 0.3

## Maximum pixel offset for random placement variation
@export_range(0, 16, 2) var max_random_offset: int = 8

@export_group("Path Generation")
## Enable path generation around boundary perimeter
@export var enable_path_generation: bool = false

## Path width in tiles (for future path-based map generation)
@export_enum("Narrow:1", "Medium:2", "Wide:3", "Extra Wide:4") var path_width: int = 2

## Number of path segments/checkpoints around perimeter
@export_range(3, 12, 1) var path_checkpoint_count: int = 6

@export_group("Debug")
## Show boundary shape preview in editor
@export var debug_show_boundary_preview: bool = false

## Calculate arena bounds based on simple size configuration
## No dependencies on GenerationParams - boundary system is single source of truth
func get_arena_bounds(generation_params: Resource = null) -> Rect2i:
	# Use our own simple size configuration
	var base_width = arena_width / 2  # Half-width
	var base_height = arena_height / 2  # Half-height

	# Apply shape multipliers
	var shaped_width = int(base_width * shape_length)
	var shaped_height = int(base_height * shape_height)

	return Rect2i(-shaped_width, -shaped_height, shaped_width * 2, shaped_height * 2)

## Get total boundary area including tree rows
func get_total_boundary_bounds(generation_params: Resource) -> Rect2i:
	var arena_bounds = get_arena_bounds(generation_params)
	var tree_row_expansion = tree_row_count * (tree_spacing_vertical / 16)  # Convert pixels to tiles

	return Rect2i(
		arena_bounds.position.x - tree_row_expansion,
		arena_bounds.position.y - tree_row_expansion,
		arena_bounds.size.x + (tree_row_expansion * 2),
		arena_bounds.size.y + (tree_row_expansion * 2)
	)


## Get simple ground bounds - simple rect that covers all trees and extends beyond
## Ultra simple approach for ground tile placement
func get_simple_ground_bounds(generation_params: Resource = null) -> Rect2i:
	# Ultra simple: start with arena bounds, apply shape multipliers, add tree rows, add ground extension
	var base_width = arena_width / 2
	var base_height = arena_height / 2

	# Use arena dimensions directly - no shape multipliers needed
	var shaped_width = base_width
	var shaped_height = base_height

	# Add tree row expansion around the shaped arena
	var tree_row_expansion = tree_row_count * (tree_spacing_vertical / 16)  # Convert pixels to tiles

	# Add ground extension beyond trees
	var total_width = shaped_width + tree_row_expansion + ground_extension
	var total_height = shaped_height + tree_row_expansion + ground_extension

	# Return simple rect covering everything
	return Rect2i(
		-total_width,
		-total_height,
		total_width * 2,
		total_height * 2
	)

## Check if a position is inside the arena boundary (for walkable area)
func is_inside_arena(position: Vector2i, generation_params: Resource = null) -> bool:
	return _is_inside_circle(position, generation_params)

## Check if position should have a tree (for boundary generation)
func should_place_tree_at(position: Vector2i, row_layer: int) -> bool:
	# Check if position is in the correct tree boundary layer
	if not _is_in_tree_boundary_layer(position, row_layer):
		return false

	# Use consistent spacing pattern to avoid gaps
	return _meets_spacing_requirements(position)

## Get random tree tile variant for variety
func get_random_tree_tile(rng: RandomNumberGenerator) -> Vector2i:
	if tree_tile_variants.is_empty():
		return Vector2i(0, 28)  # Default tree (updated coordinates)

	return tree_tile_variants[rng.randi() % tree_tile_variants.size()]

## Generate path checkpoint positions around perimeter
func generate_path_checkpoints(generation_params: Resource = null) -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []

	if not enable_path_generation:
		return checkpoints

	# Always use circular/elliptical checkpoints
	checkpoints = _generate_circular_checkpoints(generation_params)

	return checkpoints

## Private helper functions

func _is_inside_circle(position: Vector2i, generation_params: Resource = null) -> bool:
	# Get the actual arena bounds to base ellipse on
	var arena_bounds = get_arena_bounds(generation_params)
	var base_width = arena_bounds.size.x / 2
	var base_height = arena_bounds.size.y / 2

	# Use arena dimensions directly for circle/ellipse shape
	var x_radius = base_width
	var y_radius = base_height

	# Ellipse equation: (x/a)^2 + (y/b)^2 <= 1
	var normalized_x = position.x / x_radius
	var normalized_y = position.y / y_radius

	return (normalized_x * normalized_x) + (normalized_y * normalized_y) <= 1.0


func _is_in_tree_boundary_layer(position: Vector2i, row_layer: int, generation_params: Resource = null) -> bool:
	var distance_from_arena = _get_distance_from_arena_edge(position, generation_params)
	var layer_min_distance = row_layer * (tree_spacing_vertical / 16.0)
	var layer_max_distance = (row_layer + 1) * (tree_spacing_vertical / 16.0)

	return distance_from_arena >= layer_min_distance and distance_from_arena < layer_max_distance

func _get_distance_from_arena_edge(position: Vector2i, generation_params: Resource = null) -> float:
	# Circle/ellipse distance calculation only
	var arena_bounds = get_arena_bounds(generation_params)
	var base_width = arena_bounds.size.x / 2
	var base_height = arena_bounds.size.y / 2

	# Calculate distance from ellipse edge using arena dimensions
	var x_radius = base_width
	var y_radius = base_height

	# If inside the ellipse, distance is 0
	if _is_inside_circle(position, generation_params):
		return 0.0

	# For points outside ellipse, approximate distance to ellipse edge
	var normalized_x = position.x / x_radius
	var normalized_y = position.y / y_radius
	var ellipse_value = (normalized_x * normalized_x) + (normalized_y * normalized_y)

	# Approximate distance based on how far outside the ellipse the point is
	return (sqrt(ellipse_value) - 1.0) * min(x_radius, y_radius)

func _meets_spacing_requirements(position: Vector2i) -> bool:
	# Use grid-based spacing for consistency
	var grid_spacing_h = tree_spacing_horizontal / 16  # Convert to tile units
	var grid_spacing_v = tree_spacing_vertical / 16  # Convert to tile units

	# Check if position aligns with spacing grid
	return (position.x % grid_spacing_h == 0) and (position.y % grid_spacing_v == 0)

func _generate_circular_checkpoints(generation_params: Resource = null) -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []

	# Get the actual arena bounds
	var arena_bounds = get_arena_bounds(generation_params)
	var base_width = arena_bounds.size.x / 2
	var base_height = arena_bounds.size.y / 2

	# Account for arena shape plus tree rows
	var x_radius = base_width + (tree_row_count * tree_spacing_vertical / 16)
	var y_radius = base_height + (tree_row_count * tree_spacing_vertical / 16)

	for i in range(path_checkpoint_count):
		var angle = (i * 2.0 * PI) / path_checkpoint_count
		var x = int(x_radius * cos(angle))
		var y = int(y_radius * sin(angle))
		checkpoints.append(Vector2i(x, y))

	return checkpoints





## Check if position should have ground tile using simple rect approach
func should_have_ground_tile_simple(position: Vector2i, generation_params: Resource = null) -> bool:
	# Ultra simple - just check if position is within ground bounds rect
	var ground_bounds = get_simple_ground_bounds(generation_params)
	return ground_bounds.has_point(position)
