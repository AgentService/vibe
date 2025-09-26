@tool
class_name SimpleBoundaryConfig
extends Resource

## Simplified boundary generation configuration
## Replaces the complex organic/rectangular boundary system with intuitive controls

@export_group("Boundary Shape")
## Basic shape type - circle can be extended into cylinder
@export_enum("Circle", "Rectangle") var base_shape: String = "Circle"

## Length multiplier - 1=circle, 2-5=increasingly long cylinder
## For circle: 1=circle, 2=oval, 3-5=increasingly elongated cylinder
## For rectangle: 1=square, 2+=increasingly elongated rectangle
@export_range(1.0, 5.0, 0.1) var shape_length: float = 1.0

## Arena base radius (for circle) or half-width (for rectangle) in tiles
@export_range(10, 100, 1) var arena_base_size: int = 25

@export_group("Tree Configuration")
## Tree tile variants to use - now supports alternative trees with bigger collision
@export var tree_tile_variants: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]

## Fixed distance between trees in pixels (no random variation for reliability)
@export_range(16, 128, 8) var tree_spacing_pixels: int = 48

## Number of tree rows outside the arena (for escape-proof boundaries)
@export_range(1, 6, 1) var tree_row_count: int = 3

## Tree placement density (0.9+ recommended for gap-free boundaries)
@export_range(0.1, 1.0, 0.05) var tree_density: float = 0.95

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

## Calculate arena bounds based on shape configuration
func get_arena_bounds() -> Rect2i:
	match base_shape:
		"Circle":
			# For circle, create square bounds that fit the circle
			var effective_radius = arena_base_size
			var size = Vector2i(effective_radius * 2, effective_radius * 2)
			return Rect2i(-effective_radius, -effective_radius, size.x, size.y)
		"Rectangle":
			# For rectangle, use shape_length to extend width
			var half_width = int(arena_base_size * shape_length)
			var half_height = arena_base_size
			return Rect2i(-half_width, -half_height, half_width * 2, half_height * 2)
		_:
			return Rect2i(-arena_base_size, -arena_base_size, arena_base_size * 2, arena_base_size * 2)

## Get total boundary area including tree rows
func get_total_boundary_bounds() -> Rect2i:
	var arena_bounds = get_arena_bounds()
	var tree_row_expansion = tree_row_count * (tree_spacing_pixels / 16)  # Convert pixels to tiles

	return Rect2i(
		arena_bounds.position.x - tree_row_expansion,
		arena_bounds.position.y - tree_row_expansion,
		arena_bounds.size.x + (tree_row_expansion * 2),
		arena_bounds.size.y + (tree_row_expansion * 2)
	)

## Check if a position is inside the arena boundary (for walkable area)
func is_inside_arena(position: Vector2i) -> bool:
	match base_shape:
		"Circle":
			return _is_inside_circle(position)
		"Rectangle":
			return _is_inside_rectangle(position)
		_:
			return false

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
		return Vector2i(0, 1)  # Default tree

	return tree_tile_variants[rng.randi() % tree_tile_variants.size()]

## Generate path checkpoint positions around perimeter
func generate_path_checkpoints() -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []

	if not enable_path_generation:
		return checkpoints

	match base_shape:
		"Circle":
			checkpoints = _generate_circular_checkpoints()
		"Rectangle":
			checkpoints = _generate_rectangular_checkpoints()

	return checkpoints

## Private helper functions

func _is_inside_circle(position: Vector2i) -> bool:
	var distance_from_center = Vector2(position).length()
	return distance_from_center <= arena_base_size

func _is_inside_rectangle(position: Vector2i) -> bool:
	var arena_bounds = get_arena_bounds()
	return arena_bounds.has_point(position)

func _is_in_tree_boundary_layer(position: Vector2i, row_layer: int) -> bool:
	var distance_from_arena = _get_distance_from_arena_edge(position)
	var layer_min_distance = row_layer * (tree_spacing_pixels / 16.0)
	var layer_max_distance = (row_layer + 1) * (tree_spacing_pixels / 16.0)

	return distance_from_arena >= layer_min_distance and distance_from_arena < layer_max_distance

func _get_distance_from_arena_edge(position: Vector2i) -> float:
	match base_shape:
		"Circle":
			return max(0.0, Vector2(position).length() - arena_base_size)
		"Rectangle":
			var arena_bounds = get_arena_bounds()
			if arena_bounds.has_point(position):
				return 0.0

			# Calculate distance to nearest edge
			var dx = max(0, max(arena_bounds.position.x - position.x, position.x - arena_bounds.end.x))
			var dy = max(0, max(arena_bounds.position.y - position.y, position.y - arena_bounds.end.y))
			return sqrt(dx * dx + dy * dy)
		_:
			return 0.0

func _meets_spacing_requirements(position: Vector2i) -> bool:
	# Use grid-based spacing for consistency
	var grid_spacing = tree_spacing_pixels / 16  # Convert to tile units

	# Check if position aligns with spacing grid
	return (position.x % grid_spacing == 0) and (position.y % grid_spacing == 0)

func _generate_circular_checkpoints() -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []
	var radius = arena_base_size + (tree_row_count * tree_spacing_pixels / 16)

	for i in range(path_checkpoint_count):
		var angle = (i * 2.0 * PI) / path_checkpoint_count
		var x = int(radius * cos(angle))
		var y = int(radius * sin(angle))
		checkpoints.append(Vector2i(x, y))

	return checkpoints

func _generate_rectangular_checkpoints() -> Array[Vector2i]:
	var checkpoints: Array[Vector2i] = []
	var bounds = get_total_boundary_bounds()

	# Generate checkpoints around rectangle perimeter
	var perimeter_length = 2 * (bounds.size.x + bounds.size.y)
	var segment_length = perimeter_length / path_checkpoint_count

	# This is a simplified version - could be enhanced for more even distribution
	for i in range(path_checkpoint_count):
		var progress = float(i) / path_checkpoint_count
		var checkpoint = _get_rectangular_perimeter_point(bounds, progress)
		checkpoints.append(checkpoint)

	return checkpoints

func _get_rectangular_perimeter_point(bounds: Rect2i, progress: float) -> Vector2i:
	# Traverse rectangle perimeter clockwise
	var perimeter = 2 * (bounds.size.x + bounds.size.y)
	var distance = progress * perimeter

	if distance < bounds.size.x:
		# Top edge
		return Vector2i(bounds.position.x + int(distance), bounds.position.y)
	elif distance < bounds.size.x + bounds.size.y:
		# Right edge
		return Vector2i(bounds.end.x, bounds.position.y + int(distance - bounds.size.x))
	elif distance < 2 * bounds.size.x + bounds.size.y:
		# Bottom edge
		return Vector2i(bounds.end.x - int(distance - bounds.size.x - bounds.size.y), bounds.end.y)
	else:
		# Left edge
		return Vector2i(bounds.position.x, bounds.end.y - int(distance - 2 * bounds.size.x - bounds.size.y))
