@tool
class_name GenerationParams
extends Resource

## Configurable parameters for procedural arena generation
## Separate from biome-specific settings for reusability

# Arena dimensions
@export var arena_size: Vector2i = Vector2i(40, 30)
@export var boundary_width: int = 3

# Generation behavior
@export var generation_seed: int = 12345
@export var auto_increment_seed: bool = true  # Increment seed each generation

# Density controls
@export var decoration_density: float = 0.05  # Chance per floor tile
@export var interactive_object_density: float = 0.01  # Chance per eligible tile

# Tree placement (overrides biome defaults if set)
@export var override_tree_placement: bool = false
@export var tree_placement_chance: float = 0.6
@export var tree_spacing_min: int = 2
@export var tree_spacing_max: int = 5

# Zone-based object placement
@export var enable_zone_placement: bool = true
@export var treasure_zones: int = 3  # Number of treasure placement zones
@export var decoration_zones: int = 4  # Number of decoration zones

# Performance settings
@export var max_objects_per_zone: int = 5
@export var max_total_objects: int = 20

# Walkable area and spawn settings
@export var enable_walkable_floor: bool = true  # Use special tiles for walkable areas
@export var camera_boundary_extension: int = 5  # Extra tiles beyond arena for camera view
@export var enable_spawn_layer: bool = true  # Generate spawn layer for enemies
@export var spawn_border_spacing: int = 1  # Distance from boundaries for spawn area

# Debug settings
@export var debug_generation: bool = false
@export var debug_show_zones: bool = false

func get_effective_tree_placement_chance(biome_config: BiomeConfig) -> float:
	"""Get tree placement chance, using override if enabled"""
	if override_tree_placement:
		return tree_placement_chance
	return biome_config.tree_placement_chance

func get_effective_tree_spacing_min(biome_config: BiomeConfig) -> int:
	"""Get minimum tree spacing, using override if enabled"""
	if override_tree_placement:
		return tree_spacing_min
	return biome_config.tree_spacing_min

func get_effective_tree_spacing_max(biome_config: BiomeConfig) -> int:
	"""Get maximum tree spacing, using override if enabled"""
	if override_tree_placement:
		return tree_spacing_max
	return biome_config.tree_spacing_max

func get_arena_bounds() -> Rect2i:
	"""Get the arena bounds rectangle"""
	var half_width = arena_size.x / 2
	var half_height = arena_size.y / 2
	return Rect2i(-half_width, -half_height, arena_size.x, arena_size.y)

func get_total_arena_size() -> Vector2i:
	"""Get total arena size including boundaries"""
	return Vector2i(
		arena_size.x + (boundary_width * 2),
		arena_size.y + (boundary_width * 2)
	)

func increment_seed() -> void:
	"""Increment generation seed for variation"""
	if auto_increment_seed:
		generation_seed += 1

func is_valid() -> bool:
	"""Validate that generation parameters are reasonable"""
	return arena_size.x > 0 and arena_size.y > 0 and \
	       boundary_width >= 0 and \
	       decoration_density >= 0.0 and decoration_density <= 1.0 and \
	       interactive_object_density >= 0.0 and interactive_object_density <= 1.0