@tool
class_name TilePatternConfig
extends Resource

## Configuration for predefined tile patterns that can be placed in walkable areas
## Patterns are defined as relative positions with specific tile types

@export var pattern_name: String = ""
@export var pattern_weight: float = 1.0  # Higher weight = more likely to be selected

# Pattern definition as relative positions
# Each entry contains: relative position (Vector2i) and tile coordinate (Vector2i)
@export var pattern_tiles: Array[Dictionary] = []

# Pattern placement constraints
@export var min_spacing_from_others: int = 10  # Minimum distance from other patterns
@export var placement_chance: float = 0.3  # Chance to attempt placing this pattern
@export var max_instances_per_arena: int = 3  # Maximum number of this pattern per arena

# Pattern grouping configuration
@export var pattern_group: String = ""  # Group name for patterns that should be placed together
@export var group_placement_chance: float = 0.3  # Chance to place entire group (only used by group leader)
@export var max_group_instances_per_arena: int = 1  # Maximum group instances per arena (only used by group leader)
@export var is_group_leader: bool = false  # If true, this pattern controls group placement timing

# Pattern dimensions for collision detection
@export var pattern_width: int = 3
@export var pattern_height: int = 3

func is_valid() -> bool:
	"""Check if pattern configuration is valid"""
	return not pattern_name.is_empty() and not pattern_tiles.is_empty()

func is_grouped() -> bool:
	"""Check if this pattern belongs to a group"""
	return not pattern_group.is_empty()

func should_control_group_placement() -> bool:
	"""Check if this pattern should control when its group is placed"""
	return is_grouped() and is_group_leader

func get_pattern_bounds() -> Rect2i:
	"""Calculate the bounding box of this pattern"""
	if pattern_tiles.is_empty():
		return Rect2i(0, 0, pattern_width, pattern_height)

	var min_x = 999
	var max_x = -999
	var min_y = 999
	var max_y = -999

	for tile_data in pattern_tiles:
		var pos = tile_data.get("relative_pos", Vector2i.ZERO)
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func create_example_flower_circle() -> void:
	"""Create an example flower circle pattern (for editor convenience)"""
	pattern_name = "Flower Circle"
	pattern_weight = 1.0
	placement_chance = 0.4
	max_instances_per_arena = 2
	min_spacing_from_others = 15

	# Example flower circle pattern (you can customize tile coordinates)
	pattern_tiles = [
		{"relative_pos": Vector2i(0, 0), "tile": Vector2i(6, 0)},    # Center flower
		{"relative_pos": Vector2i(-1, -1), "tile": Vector2i(9, 6)},  # Small rocks around
		{"relative_pos": Vector2i(1, -1), "tile": Vector2i(9, 6)},
		{"relative_pos": Vector2i(-1, 1), "tile": Vector2i(9, 6)},
		{"relative_pos": Vector2i(1, 1), "tile": Vector2i(9, 6)},
		{"relative_pos": Vector2i(0, -2), "tile": Vector2i(12, 6)},  # Outer decorations
		{"relative_pos": Vector2i(2, 0), "tile": Vector2i(12, 6)},
		{"relative_pos": Vector2i(0, 2), "tile": Vector2i(12, 6)},
		{"relative_pos": Vector2i(-2, 0), "tile": Vector2i(12, 6)}
	]

	pattern_width = 5
	pattern_height = 5

func create_example_stone_path() -> void:
	"""Create an example stone path pattern"""
	pattern_name = "Stone Path"
	pattern_weight = 1.5
	placement_chance = 0.5
	max_instances_per_arena = 4
	min_spacing_from_others = 8

	# Straight stone path
	pattern_tiles = [
		{"relative_pos": Vector2i(0, 0), "tile": Vector2i(30, 0)},   # Stone floor
		{"relative_pos": Vector2i(0, 1), "tile": Vector2i(30, 3)},   # Stone floor variant
		{"relative_pos": Vector2i(0, 2), "tile": Vector2i(30, 0)},
		{"relative_pos": Vector2i(0, 3), "tile": Vector2i(30, 3)},
		{"relative_pos": Vector2i(-1, 1), "tile": Vector2i(9, 6)},   # Side decorations
		{"relative_pos": Vector2i(1, 2), "tile": Vector2i(9, 6)}
	]

	pattern_width = 3
	pattern_height = 4