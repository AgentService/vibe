@tool
class_name GenerationParams
extends Resource

## Configurable parameters for procedural arena generation
## Separate from biome-specific settings for reusability

# Arena dimensions
@export var arena_size: Vector2i = Vector2i(50, 50)
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
@export var tree_spacing_min: int = 1
@export var tree_spacing_max: int = 1

# Zone-based object placement
@export var enable_zone_placement: bool = true
@export var treasure_zones: int = 3  # Number of treasure placement zones
@export var decoration_zones: int = 4  # Number of decoration zones

# Performance settings
@export var max_objects_per_zone: int = 5
@export var max_total_objects: int = 20

# Walkable area and spawn settings
@export var enable_walkable_floor: bool = true  # Use special tiles for walkable areas
@export var camera_boundary_extension: int = 25  # Extra tiles beyond arena for camera view (max 50)
@export var enable_spawn_layer: bool = true  # Generate spawn layer for enemies
@export var spawn_border_spacing: int = 5  # Distance from boundaries for spawn area

# Camera extension density gradient
@export var edge_density_multiplier: float = 40.0  # How much denser trees get at outer edge (1.0 = no change, 10.0 = very dense)
@export var invert_density_gradient: bool = true  # If true, trees get denser toward edges; if false, denser toward center

# Organic boundary fine-tuning
@export var organic_noise_octaves: int = 2  # Number of noise layers (0-8)
@export var organic_noise_lacunarity: float = 1.5  # Frequency multiplier between octaves (0.0+)
@export var organic_noise_gain: float = 0.3  # Amplitude reduction for higher octaves (0.0-1.0)
@export var organic_amplitude_multiplier: float = 0.5  # Overall amplitude reduction (0.0-2.0)
@export var organic_curvature_scale: float = 8.0  # Fixed curvature scale (0.0+ for sharp edges, higher for smoother)

# Organic boundary settings
@export var enable_organic_boundaries: bool = true  # Enable cloud-like natural boundaries
@export var boundary_noise_frequency: float = 0.05  # Lower = smoother curves (0.0 = no noise)
@export var boundary_noise_amplitude: float = 3.0  # Noise variation strength
@export var boundary_edge_fill_chance: float = 0.9  # Chance to fill boundary edge gaps (0.0-1.0) to prevent escape routes

# Ultra-strong gap-free system parameters
@export_group("Ultra-Strong Gap Fill")
@export var fill_sample_spacing: int = 1  # Tile spacing between samples (1 = ultra-dense, up to 20)
@export var fill_coverage_radius: float = 1.0  # Radius of coverage around each sample (0.0-3.0, 1.0 = 3x3 grid)
@export var fill_angular_density: float = 0.2  # Angular density multiplier (0.1-1.0, higher = more points)
@export var fill_minimum_chance: float = 0.8  # Minimum placement chance (0.0-1.0, 0.8 = 80% minimum)
@export var fill_maximum_multiplier: float = 8.0  # Maximum density multiplier at edges (1.0-20.0)
@export var fill_noise_variation: float = 0.1  # Random variation (0.0-0.5, 0.1 = 10% variation, very consistent)

# Advanced organic boundary configuration
@export_group("Organic Boundary Advanced")
@export var boundary_variation_range: Vector2 = Vector2(1.0, 8.0)  # Min/max variation from base boundary
@export var pocket_frequency: float = 0.03  # Creates inward pockets and outward bulges
@export var pocket_depth: float = 6.0  # How deep/high pockets can extend
@export var curvature_strength: float = 2.5  # Smoothness vs sharpness of curves
@export var layered_noise_octaves: int = 4  # Number of noise layers for complexity
@export var noise_lacunarity: float = 2.0  # Frequency multiplier for noise octaves
@export var noise_gain: float = 0.5  # Amplitude reduction for higher octaves
@export var enable_erosion_effect: bool = true  # Creates more natural weathered boundaries
@export var erosion_strength: float = 1.5  # How much erosion affects boundary
@export var boundary_density_variation: float = 0.3  # Random gaps in boundary for organic feel

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