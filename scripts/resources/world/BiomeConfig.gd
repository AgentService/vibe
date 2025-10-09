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

# Themed decoration system
@export var decoration_themes: Array[DecorationThemeConfig] = []

# Tile pattern system for walkable area placement
@export var tile_patterns: Array[TilePatternConfig] = []

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
	"""Get a random decoration tile coordinate (legacy method)"""
	if decoration_tiles.is_empty():
		return Vector2i(4, 0)
	return decoration_tiles[rng.randi() % decoration_tiles.size()]

func get_weighted_decoration_theme(rng: RandomNumberGenerator) -> DecorationThemeConfig:
	"""Get a decoration theme based on weighted probability"""
	if decoration_themes.is_empty():
		return null

	# Calculate total weight
	var total_weight := 0.0
	for theme in decoration_themes:
		total_weight += theme.get_effective_spawn_weight()

	if total_weight <= 0.0:
		return decoration_themes[0]

	# Select theme based on weight
	var random_value := rng.randf() * total_weight
	var current_weight := 0.0

	for theme in decoration_themes:
		current_weight += theme.get_effective_spawn_weight()
		if random_value <= current_weight:
			return theme

	return decoration_themes[0]

func get_themed_decoration_tile(rng: RandomNumberGenerator, position: Vector2i, arena_center: Vector2i, arena_bounds: Rect2i, existing_decorations: Dictionary = {}) -> Dictionary:
	"""Get a themed decoration with clustering and environmental preferences
	Returns: {tile: Vector2i, theme_name: String, success: bool}"""

	var result := {"tile": Vector2i(0, 0), "theme_name": "", "success": false}

	if decoration_themes.is_empty():
		# Fallback to legacy system
		result.tile = get_random_decoration_tile(rng)
		result.theme_name = "legacy"
		result.success = true
		return result

	var selected_theme := get_weighted_decoration_theme(rng)
	if not selected_theme:
		return result

	# Check environmental preferences
	var env_modifier := selected_theme.get_environmental_preference_modifier(position, arena_center, arena_bounds)

	# Apply environmental modifier to spawn chance
	if rng.randf() > env_modifier * 0.5:  # Base 50% chance modified by environment
		return result

	# Check clustering behavior
	var theme_positions_raw = existing_decorations.get(selected_theme.theme_name, [])
	var theme_positions: Array[Vector2i] = []
	theme_positions.assign(theme_positions_raw)
	if selected_theme.enable_clustering and not theme_positions.is_empty():
		if not selected_theme.should_cluster_near(theme_positions, position, rng):
			# Try a different theme if clustering fails
			selected_theme = get_weighted_decoration_theme(rng)
			if not selected_theme:
				return result

	result.tile = selected_theme.get_random_tile(rng)
	result.theme_name = selected_theme.theme_name
	result.success = true
	return result

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

func get_random_tile_pattern(rng: RandomNumberGenerator) -> TilePatternConfig:
	"""Get a random tile pattern based on weights"""
	if tile_patterns.is_empty():
		return null

	# Filter valid patterns
	var valid_patterns: Array[TilePatternConfig] = []
	for pattern in tile_patterns:
		if pattern.is_valid():
			valid_patterns.append(pattern)

	if valid_patterns.is_empty():
		return null

	# Weighted selection
	var total_weight = 0.0
	for pattern in valid_patterns:
		total_weight += pattern.pattern_weight

	if total_weight <= 0.0:
		return valid_patterns[rng.randi() % valid_patterns.size()]

	var random_value = rng.randf() * total_weight
	var current_weight = 0.0

	for pattern in valid_patterns:
		current_weight += pattern.pattern_weight
		if random_value <= current_weight:
			return pattern

	return valid_patterns[-1]  # Fallback to last pattern

func is_valid() -> bool:
	"""Validate that this biome configuration has minimum required data"""
	return not biome_name.is_empty() and \
	       not floor_tiles.is_empty() and \
	       not boundary_tiles.is_empty()