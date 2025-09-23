@tool
class_name BiomeConfig
extends Resource

## Tileset-agnostic biome configuration for procedural generation
## Maps functional tile categories to specific tileset coordinates

@export var biome_name: String = ""
@export var tileset_resource: TileSet

# Tile category mappings (coordinates in the tileset)
@export var floor_tiles: Array[Vector2i] = []
@export var boundary_tiles: Array[Vector2i] = []
@export var decoration_tiles: Array[Vector2i] = []
@export var special_tiles: Array[Vector2i] = []

# Walkable area tiles (for player movement areas, different from aesthetic ground)
@export var walkable_floor_tiles: Array[Vector2i] = []
@export var spawn_area_tiles: Array[Vector2i] = []  # For spawn layer (can be transparent)

# Tree object configurations for z-ordering
@export var tree_objects: Array[TreeObjectConfig] = []

# Interactive object configurations
@export var interactive_objects: Array[InteractiveObjectConfig] = []

# Generation parameters specific to this biome
@export var default_boundary_width: int = 3
@export var default_decoration_density: float = 0.05
@export var tree_placement_chance: float = 0.6
@export var tree_spacing_min: int = 2
@export var tree_spacing_max: int = 5

func get_random_floor_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a random floor tile coordinate"""
	if floor_tiles.is_empty():
		return Vector2i(0, 0)
	return floor_tiles[rng.randi() % floor_tiles.size()]

func get_random_boundary_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a random boundary tile coordinate"""
	if boundary_tiles.is_empty():
		return Vector2i(0, 1)
	return boundary_tiles[rng.randi() % boundary_tiles.size()]

func get_random_decoration_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a random decoration tile coordinate"""
	if decoration_tiles.is_empty():
		return Vector2i(4, 0)
	return decoration_tiles[rng.randi() % decoration_tiles.size()]

func get_random_tree_object(rng: RandomNumberGenerator) -> TreeObjectConfig:
	"""Get a random tree object configuration"""
	if tree_objects.is_empty():
		return null
	return tree_objects[rng.randi() % tree_objects.size()]

func get_random_interactive_object(rng: RandomNumberGenerator) -> InteractiveObjectConfig:
	"""Get a random interactive object configuration"""
	if interactive_objects.is_empty():
		return null
	return interactive_objects[rng.randi() % interactive_objects.size()]

func get_random_walkable_floor_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a random walkable floor tile coordinate"""
	if walkable_floor_tiles.is_empty():
		# Fallback to regular floor tiles if no walkable tiles defined
		return get_random_floor_tile(rng)
	return walkable_floor_tiles[rng.randi() % walkable_floor_tiles.size()]

func get_spawn_area_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a spawn area tile coordinate (can be transparent)"""
	if spawn_area_tiles.is_empty():
		# Use transparent tile at (0,0) if no spawn tiles defined
		return Vector2i(0, 0)
	return spawn_area_tiles[rng.randi() % spawn_area_tiles.size()]

func is_valid() -> bool:
	"""Validate that this biome configuration has minimum required data"""
	return not biome_name.is_empty() and \
	       not floor_tiles.is_empty() and \
	       not boundary_tiles.is_empty()