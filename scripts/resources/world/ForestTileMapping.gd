class_name ForestTileMapping
extends Resource

## Defines tile positions and types for forest arena generation
## Maps coordinates in the 48x48 forest tileset to functional tile types

# Floor tiles (grass variations) - coordinates in tileset
@export var floor_tiles: Array[Vector2i] = [
	Vector2i(0, 0),  # Light grass
	Vector2i(1, 0),  # Medium grass
	Vector2i(2, 0),  # Dark grass
	Vector2i(3, 0),  # Variant grass
]

# Tree border tiles (large trees for arena walls)
@export var border_tree_tiles: Array[Vector2i] = [
	Vector2i(0, 1),  # Large tree 1
	Vector2i(1, 1),  # Large tree 2
	Vector2i(2, 1),  # Large tree 3
]

# Small decorative elements (bushes, small trees)
@export var decoration_tiles: Array[Vector2i] = [
	Vector2i(4, 0),  # Small bush
	Vector2i(0, 2),  # Small tree
	Vector2i(1, 2),  # Another small tree
]

# Special tiles (stumps, logs, etc)
@export var special_tiles: Array[Vector2i] = [
	Vector2i(3, 1),  # Tree stump
	Vector2i(4, 1),  # Log
]

func get_random_floor_tile() -> Vector2i:
	if floor_tiles.is_empty():
		return Vector2i(0, 0)
	return floor_tiles[randi() % floor_tiles.size()]

func get_random_border_tree() -> Vector2i:
	if border_tree_tiles.is_empty():
		return Vector2i(0, 1)
	return border_tree_tiles[randi() % border_tree_tiles.size()]

func get_random_decoration() -> Vector2i:
	if decoration_tiles.is_empty():
		return Vector2i(4, 0)
	return decoration_tiles[randi() % decoration_tiles.size()]