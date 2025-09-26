@tool
class_name ProceduralArenaGenerator
extends Node2D

## General-purpose procedural arena generator supporting multiple biomes
## Replaces ForestArenaGenerator with tileset-agnostic approach

signal generation_complete()

# Tool mode safe logging helper
func _safe_log(message: String, category: String = "", level: String = "info") -> void:
	if Engine.is_editor_hint():
		# In editor tool mode, use print for debugging
		print("[%s:%s] %s" % [level.to_upper(), category, message])
	else:
		# In game mode, use Logger
		match level:
			"debug":
				Logger.debug(message, category)
			"info":
				Logger.info(message, category)
			"warn":
				Logger.warn(message, category)
			"error":
				Logger.error(message, category)

# Configuration exports
@export var biome_config: BiomeConfig
@export var generation_params: GenerationParams

# Arena reference for component mode
var arena_reference: Node2D

# Layer references (populated after arena reference is set)
var ground_layer: TileMapLayer
var boundaries_layer: TileMapLayer
var decorations_layer: TileMapLayer
var ground_decorations_layer: TileMapLayer  # New layer for non-Y-sorted ground decorations
var interactive_layer: TileMapLayer
var spawn_layer: TileMapLayer

# Spawn point reference
var player_spawn: Marker2D

# Tree Y-sorting container for proper depth rendering
var tree_objects_container: Node2D

func set_arena_reference(arena: Node2D) -> void:
	"""Set arena reference for component mode - allows finding nodes relative to arena"""
	arena_reference = arena

	# Now that we have the arena reference, populate the layer references
	_populate_layer_references()

func _populate_layer_references() -> void:
	"""Populate layer and spawn point references after arena reference is set"""
	ground_layer = _get_layer_node("Ground")
	boundaries_layer = _get_layer_node("Boundaries")
	decorations_layer = _get_layer_node("Decorations")
	ground_decorations_layer = _get_layer_node("GroundDecoration")
	interactive_layer = _get_layer_node("Interactive")
	spawn_layer = _get_layer_node("Spawn")
	player_spawn = _get_spawn_point("PlayerSpawnPoint")

	_safe_log("Layer reference setup complete: Ground=%s, Boundaries=%s" % [
		ground_layer != null, boundaries_layer != null
	], "procedural")

func _get_layer_node(layer_name: String) -> TileMapLayer:
	"""Get a TileMapLayer node, checking both direct child and arena reference paths"""
	# Try direct child first (for legacy scene script usage)
	var direct_node = get_node_or_null(layer_name)
	if direct_node and direct_node is TileMapLayer:
		return direct_node

	# Try arena reference (for component usage)
	if arena_reference:
		var arena_node = arena_reference.get_node_or_null(layer_name)
		if arena_node and arena_node is TileMapLayer:
			return arena_node

		# Try YSort_Objects container in arena for Y-sorted layers
		var ysort_container = arena_reference.get_node_or_null("YSort_Objects")
		if ysort_container:
			var ysort_layer = ysort_container.get_node_or_null(layer_name)
			if ysort_layer and ysort_layer is TileMapLayer:
				return ysort_layer

	# Try parent node (for tool mode / editor plugin usage)
	var parent_node = get_parent()
	if parent_node:
		var parent_layer = parent_node.get_node_or_null(layer_name)
		if parent_layer and parent_layer is TileMapLayer:
			return parent_layer

		# Try YSort_Objects container in parent for Y-sorted layers
		var parent_ysort_container = parent_node.get_node_or_null("YSort_Objects")
		if parent_ysort_container:
			var parent_ysort_layer = parent_ysort_container.get_node_or_null(layer_name)
			if parent_ysort_layer and parent_ysort_layer is TileMapLayer:
				return parent_ysort_layer

	_safe_log("TileMapLayer not found: %s" % layer_name, "procedural", "warn")
	return null

func _get_spawn_point(spawn_name: String) -> Marker2D:
	"""Get a Marker2D spawn point, checking both direct child and arena reference paths"""
	# Try direct child first (for legacy scene script usage)
	var direct_node = get_node_or_null(spawn_name)
	if direct_node and direct_node is Marker2D:
		return direct_node

	# Try arena reference (for component usage)
	if arena_reference:
		var arena_node = arena_reference.get_node_or_null(spawn_name)
		if arena_node and arena_node is Marker2D:
			return arena_node

	# Try parent node (for tool mode / editor plugin usage)
	var parent_node = get_parent()
	if parent_node:
		var parent_spawn = parent_node.get_node_or_null(spawn_name)
		if parent_spawn and parent_spawn is Marker2D:
			return parent_spawn

	_safe_log("Spawn point not found: %s" % spawn_name, "procedural", "warn")
	return null

# Generation state
var _placed_objects: Array[Vector2] = []
var _placed_trees: Array[Vector2i] = []


func _ready() -> void:
	# Set up proper z-ordering for all layers
	_setup_layer_z_ordering()

	# Tree collision handled by tileset physics layers - no manual collision system needed

	# Only auto-generate when running the game, not in editor
	if Engine.is_editor_hint():
		return

	# Validate configuration
	if not _validate_configuration():
		return

	# Generate on ready
	call_deferred("generate_arena")

func _setup_layer_z_ordering() -> void:
	"""Configure z-index for proper depth sorting"""
	if ground_layer:
		ground_layer.z_index = 0
	if spawn_layer:
		spawn_layer.z_index = 0  # Same level as ground, for enemy spawning
	if ground_decorations_layer:
		ground_decorations_layer.z_index = 0  # Same as ground layer for non-Y-sorted ground decorations
	if boundaries_layer:
		boundaries_layer.z_index = 1
		# Enable Y-sorting for trees so players can walk behind them
		boundaries_layer.y_sort_enabled = true
	if decorations_layer:
		decorations_layer.z_index = 0  # Same as ground layer to appear behind boundaries
	if interactive_layer:
		interactive_layer.z_index = 5

# Tree collision system removed - now handled by tileset physics layers


func _create_y_sorted_tree(position: Vector2i) -> void:
	"""Create a Y-sorted tree object for proper depth rendering with separate trunk and canopy"""
	if not tree_objects_container or not boundaries_layer:
		return

	# Convert tile position to world position
	var world_pos = boundaries_layer.map_to_local(position)

	# Create tree object container
	var tree_object = Node2D.new()
	tree_object.name = "Tree_%d_%d" % [position.x, position.y]
	# CRITICAL: Position the Node2D at the TRUNK BASE for natural Y-sorting
	# Y-sorting compares Node2D positions - trunk base gives most natural depth effect
	# Player appears behind tree when player.position.y > tree_object.position.y (south of trunk)
	var tile_size = boundaries_layer.tile_set.tile_size.y if boundaries_layer.tile_set else 32
	tree_object.position = Vector2(world_pos.x, world_pos.y + tile_size * 0.4)  # Trunk base area

	# Try to extract trunk and canopy from tileset if possible
	var tileset_resource = boundaries_layer.tile_set
	var tree_parts = _extract_tree_parts_from_tileset(tileset_resource)

	if tree_parts.has("trunk") and tree_parts.has("canopy"):
		# Use extracted textures from tileset
		_create_tree_parts_from_textures(tree_object, tree_parts.trunk, tree_parts.canopy)
	else:
		# Fallback: Use the original tile as a single sprite but with proper Y-sorting
		_create_tree_from_tile(tree_object, position)

	tree_objects_container.add_child(tree_object)

func _extract_tree_parts_from_tileset(tileset: TileSet) -> Dictionary:
	"""Extract trunk and canopy textures from tileset (you'll need to implement based on your tileset structure)"""
	var tree_parts = {}

	# This is a placeholder - you'll need to implement based on how your forest tileset is structured
	# For now, we'll return empty to use the fallback approach
	return tree_parts

func _create_tree_parts_from_textures(tree_object: Node2D, trunk_texture: Texture2D, canopy_texture: Texture2D) -> void:
	"""Create separate trunk and canopy sprites for optimal Y-sorting"""

	# Create trunk sprite (this gets Y-sorted with the player)
	var trunk_sprite = Sprite2D.new()
	trunk_sprite.name = "Trunk"
	trunk_sprite.texture = trunk_texture
	trunk_sprite.position = Vector2(0, 0)  # Centered on tree object (trunk base)
	tree_object.add_child(trunk_sprite)

	# Create canopy sprite (always renders above player and trunk)
	var canopy_sprite = Sprite2D.new()
	canopy_sprite.name = "Canopy"
	canopy_sprite.texture = canopy_texture
	canopy_sprite.z_index = 1  # Always above other sprites
	canopy_sprite.position = Vector2(0, -44)  # Above the trunk (adjusted for new positioning)
	tree_object.add_child(canopy_sprite)

func _create_tree_from_tile(tree_object: Node2D, tile_position: Vector2i) -> void:
	"""Create tree positioned for optimal Y-sorting with player"""

	# Get the tile texture from the boundaries layer
	var tile_data = boundaries_layer.get_cell_tile_data(tile_position)
	if not tile_data:
		return

	# Create single tree sprite
	var tree_sprite = Sprite2D.new()
	tree_sprite.name = "TreeSprite"
	# Position sprite so that trunk base aligns with tree_object position
	# Since tree_object is now at trunk base, offset sprite up to show full tree
	var tile_size = boundaries_layer.tile_set.tile_size.y if boundaries_layer.tile_set else 32
	tree_sprite.position = Vector2(0, -tile_size * 0.4)  # Offset up to center tree on trunk base

	# Try to get texture from the tile
	var tileset = boundaries_layer.tile_set
	if tileset and tileset.get_source_count() > 0:
		var source = tileset.get_source(0)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			var atlas_coords = boundaries_layer.get_cell_atlas_coords(tile_position)
			if atlas_coords != Vector2i(-1, -1):
				tree_sprite.texture = atlas_source.texture
				tree_sprite.region_enabled = true
				tree_sprite.region_rect = atlas_source.get_tile_texture_region(atlas_coords)

	tree_object.add_child(tree_sprite)

	_safe_log("Created Y-sorted tree at: %s" % tile_position, "generation", "debug")

# Tree collision clearing removed - handled by tileset physics layers

func _validate_configuration() -> bool:
	"""Validate that we have valid configuration"""
	if not biome_config or not biome_config.is_valid():
		_safe_log("ProceduralArenaGenerator: Invalid or missing biome_config", "generation", "error")
		return false

	if not generation_params or not generation_params.is_valid():
		_safe_log("ProceduralArenaGenerator: Invalid or missing generation_params", "generation", "error")
		return false

	return true

func generate_arena() -> void:
	"""Generate the arena with the configured biome and parameters"""
	if not _validate_configuration():
		return

	# Ensure layer references are populated (important for tool mode)
	if not ground_layer or not boundaries_layer:
		_populate_layer_references()

	# Increment seed for natural variation
	generation_params.increment_seed()

	_safe_log("🌍 Starting procedural arena generation", "generation")
	_safe_log("  Biome: %s, Seed: %d, Size: %s" % [
		biome_config.biome_name,
		generation_params.generation_seed,
		generation_params.arena_size
	], "generation")

	# Set up RNG for reproducible results
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_params.generation_seed

	# Clear existing content and state
	clear_arena()

	# Core generation phases
	_generate_floor_layer(rng)
	_generate_spawn_layer(rng)  # Generate spawn areas right after ground
	_generate_walkable_floor_layer(rng)  # Walkable areas for player movement
	_generate_boundary_layer(rng)
	_fill_boundary_edge_gaps(rng)  # Fill gaps in boundary edges to prevent escape routes
	_generate_object_bases(rng)
	_generate_decorations(rng)
	_generate_interactive_objects(rng)

	# Final setup
	_set_player_spawn()

	_safe_log("✅ Procedural arena generation completed!", "generation")
	_safe_log("  Generated: Ground, %d trees, %d decorations, %d interactive objects" % [
		_placed_trees.size(),
		_count_layer_tiles(decorations_layer),
		_count_layer_tiles(interactive_layer)
	], "generation")

	generation_complete.emit()

func clear_arena() -> void:
	"""Clear all tiles and reset generation state"""
	# Clear all layers
	if ground_layer:
		ground_layer.clear()
	if spawn_layer:
		spawn_layer.clear()
	if ground_decorations_layer:
		ground_decorations_layer.clear()
	if boundaries_layer:
		boundaries_layer.clear()
	if decorations_layer:
		decorations_layer.clear()
	if interactive_layer:
		interactive_layer.clear()

	# Tree collisions handled by tileset physics layers - no manual clearing needed

	# Reset state
	_placed_objects.clear()
	_placed_trees.clear()

func _generate_floor_layer(rng: RandomNumberGenerator) -> void:
	"""Generate floor tiles using biome configuration"""
	_safe_log("🌱 Generating floor layer", "generation", "debug")

	if not ground_layer:
		_safe_log("Ground layer not found", "generation", "warn")
		return

	if not biome_config:
		_safe_log("BiomeConfig is null!", "generation", "error")
		return

	_safe_log("BiomeConfig floor_tiles: %s" % str(biome_config.floor_tiles), "generation", "debug")

	# Calculate extended area for camera boundary
	# Camera extension increases the total boundary tree area
	var total_size = generation_params.get_total_arena_size()
	var camera_extension = generation_params.camera_boundary_extension
	var extended_half_width = (total_size.x / 2) + camera_extension
	var extended_half_height = (total_size.y / 2) + camera_extension

	# Fill extended area with aesthetic ground tiles for camera view
	# Camera extension expands tree boundary area for seamless camera movement
	# Use +1 to include the edge tiles (range excludes end value)
	for x in range(-extended_half_width, extended_half_width + 1):
		for y in range(-extended_half_height, extended_half_height + 1):
			var tile_pos := Vector2i(x, y)
			var floor_tile = biome_config.get_random_floor_tile(rng)
			ground_layer.set_cell(tile_pos, 0, floor_tile)

func _generate_boundary_layer(rng: RandomNumberGenerator) -> void:
	"""Generate boundary elements - organic or rectangular based on settings"""

	if generation_params.enable_organic_boundaries:
		_generate_organic_boundary_layer(rng)
	else:
		_generate_rectangular_boundary_layer(rng)

func _generate_organic_boundary_layer(rng: RandomNumberGenerator) -> void:
	"""Generate advanced organic boundary elements with configurable natural variation"""
	_safe_log("🌲 Generating advanced organic boundary layer", "generation", "debug")

	var arena_bounds = generation_params.get_arena_bounds()
	var center_x = 0
	var center_y = 0
	var base_radius_x = arena_bounds.size.x / 2.0
	var base_radius_y = arena_bounds.size.y / 2.0

	# Camera extension expands the boundary (tree) area
	var total_boundary_width = generation_params.boundary_width + generation_params.camera_boundary_extension

	# Create advanced multi-layered noise system for natural variation
	var primary_noise = _create_primary_boundary_noise()
	var pocket_noise = _create_pocket_noise()
	var erosion_noise = _create_erosion_noise() if generation_params.enable_erosion_effect else null

	# Generate organic boundary using advanced distance field with multiple noise layers
	for border_layer in range(total_boundary_width):
		var layer_radius_x = base_radius_x + border_layer
		var layer_radius_y = base_radius_y + border_layer

		# Sample points around the perimeter with advanced organic variation
		_generate_advanced_organic_perimeter_layer(center_x, center_y, layer_radius_x, layer_radius_y,
													primary_noise, pocket_noise, erosion_noise, border_layer, rng)

func _generate_rectangular_boundary_layer(rng: RandomNumberGenerator) -> void:
	"""Generate traditional rectangular boundary elements"""
	_safe_log("🌲 Generating rectangular boundary layer", "generation", "debug")

	var arena_bounds = generation_params.get_arena_bounds()
	var half_width = arena_bounds.size.x / 2
	var half_height = arena_bounds.size.y / 2

	# Camera extension expands the boundary (tree) area
	var total_boundary_width = generation_params.boundary_width + generation_params.camera_boundary_extension

	# Generate boundary elements with spacing - traditional rectangular approach
	for border_layer in range(total_boundary_width):
		var layer_half_width = half_width + border_layer
		var layer_half_height = half_height + border_layer

		var potential_positions: Array[Vector2i] = []

		# Collect boundary positions
		for x in range(-layer_half_width, layer_half_width + 1):
			potential_positions.append(Vector2i(x, -layer_half_height))  # Top
			potential_positions.append(Vector2i(x, layer_half_height))   # Bottom
		for y in range(-layer_half_height + 1, layer_half_height):
			potential_positions.append(Vector2i(-layer_half_width, y))   # Left
			potential_positions.append(Vector2i(layer_half_width, y))    # Right

		# Place boundary elements with layer-based density gradient
		for pos in potential_positions:
			if _should_place_boundary_element_with_density(pos, border_layer, total_boundary_width, rng):
				_place_boundary_element(pos, rng)

func _create_primary_boundary_noise() -> FastNoiseLite:
	"""Create simplified primary noise for organic boundary variation"""
	var noise = FastNoiseLite.new()
	noise.seed = generation_params.generation_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = max(0.001, generation_params.boundary_noise_frequency)  # Prevent zero frequency
	# Simplified - fewer octaves for more reliable boundaries
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = generation_params.organic_noise_octaves
	noise.fractal_lacunarity = max(1.0, generation_params.organic_noise_lacunarity)  # Prevent < 1.0
	noise.fractal_gain = generation_params.organic_noise_gain
	return noise

func _create_pocket_noise() -> FastNoiseLite:
	"""Create noise for pocket generation (inward/outward bulges)"""
	var noise = FastNoiseLite.new()
	noise.seed = generation_params.generation_seed + 1000  # Different seed for variation
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = generation_params.pocket_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 3
	return noise

func _create_erosion_noise() -> FastNoiseLite:
	"""Create noise for erosion effects (weathered natural boundaries)"""
	var noise = FastNoiseLite.new()
	noise.seed = generation_params.generation_seed + 2000  # Different seed for variation
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02  # Very low frequency for large erosion patterns
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return noise

func _generate_advanced_organic_perimeter_layer(center_x: float, center_y: float, radius_x: float, radius_y: float,
											   primary_noise: FastNoiseLite, pocket_noise: FastNoiseLite, erosion_noise: FastNoiseLite,
											   border_layer: int, rng: RandomNumberGenerator) -> void:
	"""Generate highly organic perimeter with pockets, curves, and natural variation"""

	# Configurable organic variation
	var base_amplitude = generation_params.boundary_noise_amplitude * generation_params.organic_amplitude_multiplier
	var variation_range = generation_params.boundary_variation_range
	var layer_progress = float(border_layer) / float(max(1, generation_params.boundary_width))
	var noise_amplitude = lerp(variation_range.x, variation_range.y, layer_progress)
	var noise_scale = generation_params.organic_curvature_scale

	# Sample points around elliptical perimeter with adaptive resolution
	var circumference = PI * (radius_x + radius_y)  # Approximate ellipse circumference
	var angle_step = TAU / max(80, circumference * 0.8)  # Higher resolution for smoother curves
	var angle = rng.randf() * TAU  # Random starting angle for variation

	var perimeter_points: Array[Vector2i] = []

	var points_generated = 0
	var max_points = int(circumference * 2)  # Prevent infinite loops

	while points_generated < max_points:
		# Base elliptical position
		var base_x = center_x + radius_x * cos(angle)
		var base_y = center_y + radius_y * sin(angle)

		# Sample primary noise for general organic variation
		var primary_x = primary_noise.get_noise_2d(base_x * noise_scale, base_y * noise_scale)
		var primary_y = primary_noise.get_noise_2d((base_x + 1000) * noise_scale, (base_y + 1000) * noise_scale)

		# Sample pocket noise for inward/outward bulges
		var pocket_influence = pocket_noise.get_noise_2d(base_x * 0.1, base_y * 0.1)
		var pocket_variation = pocket_influence * generation_params.pocket_depth

		# Sample erosion noise for weathered natural appearance
		var erosion_variation = 0.0
		if erosion_noise:
			var erosion_sample = erosion_noise.get_noise_2d(base_x * 0.05, base_y * 0.05)
			erosion_variation = erosion_sample * generation_params.erosion_strength

		# Combine all noise layers for complex organic shape
		var total_variation_x = (primary_x * noise_amplitude) + pocket_variation + erosion_variation
		var total_variation_y = (primary_y * noise_amplitude) + (pocket_variation * 0.7) + (erosion_variation * 0.5)

		# Apply variations to create highly organic shape
		var organic_x = base_x + total_variation_x
		var organic_y = base_y + total_variation_y

		# Convert to tile coordinates
		var tile_pos = Vector2i(round(organic_x), round(organic_y))

		# Avoid duplicate positions
		if not perimeter_points.has(tile_pos):
			perimeter_points.append(tile_pos)

		angle += angle_step
		if angle >= TAU + (TAU * 0.1):  # Allow slight overlap for completeness
			break
		points_generated += 1

	# Place boundary elements at organic perimeter points with density variation
	var total_boundary_width = generation_params.boundary_width + generation_params.camera_boundary_extension
	for pos in perimeter_points:
		if _should_place_organic_boundary_element_with_density(pos, primary_noise, border_layer, total_boundary_width, rng):
			_place_boundary_element(pos, rng)

			# Add simplified organic fill for natural thickness
			if border_layer < 2:  # Reduced from 3 to 2 for less complexity
				_add_simplified_organic_fill(pos, primary_noise, rng)

func _should_place_organic_boundary_element(pos: Vector2i, noise: FastNoiseLite, rng: RandomNumberGenerator) -> bool:
	"""Determine if an organic boundary element should be placed with density variation"""
	# Standard placement chance check
	var placement_chance = generation_params.get_effective_tree_placement_chance(biome_config)

	# Apply density variation using noise for organic gaps
	var density_noise = noise.get_noise_2d(pos.x * 0.15, pos.y * 0.15)
	var density_modifier = 1.0 + (density_noise * generation_params.boundary_density_variation)
	var adjusted_chance = placement_chance * density_modifier

	if rng.randf() >= adjusted_chance:
		return false

	# Check spacing against existing trees
	var min_spacing = generation_params.get_effective_tree_spacing_min(biome_config)
	var max_spacing = generation_params.get_effective_tree_spacing_max(biome_config)

	for existing_tree in _placed_trees:
		var distance = pos.distance_to(existing_tree)
		var required_spacing = rng.randi_range(min_spacing, max_spacing)
		if distance < required_spacing:
			return false

	return true

func _fill_boundary_edge_gaps(rng: RandomNumberGenerator) -> void:
	"""Post-process to fill gaps in boundary edges with organic distance-based placement"""
	if generation_params.boundary_edge_fill_chance <= 0.0:
		return

	var arena_bounds = generation_params.get_arena_bounds()
	var center = Vector2(0, 0)  # Arena center

	# Calculate organic fill area - much larger and more natural
	var max_fill_radius = max(arena_bounds.size.x, arena_bounds.size.y) / 2 + generation_params.camera_boundary_extension
	var min_arena_radius = max(arena_bounds.size.x, arena_bounds.size.y) / 2 - generation_params.boundary_width

	# Use configurable sampling with adjustable spacing for gap-free coverage
	var sample_spacing = generation_params.fill_sample_spacing
	var coverage_radius = generation_params.fill_coverage_radius
	var fill_positions: Array[Vector2i] = []

	# Generate configurable sample pattern with adjustable coverage
	for radius in range(int(min_arena_radius), int(max_fill_radius), sample_spacing):
		var circumference = 2 * PI * radius
		var angle_step = (2 * PI) / max(8, circumference * generation_params.fill_angular_density)
		var angle_offset = rng.randf() * PI  # Random rotation per radius

		var angle = angle_offset
		while angle < 2 * PI + angle_offset:
			var sample_x = center.x + radius * cos(angle)
			var sample_y = center.y + radius * sin(angle)
			var sample_pos = Vector2i(int(sample_x), int(sample_y))

			# Add configurable coverage around each position
			var coverage_int = int(ceil(coverage_radius))  # Convert to integer for grid iteration
			for offset_x in range(-coverage_int, coverage_int + 1):
				for offset_y in range(-coverage_int, coverage_int + 1):
					# Check if position is within the fractional radius
					var distance = sqrt(offset_x * offset_x + offset_y * offset_y)
					if distance <= coverage_radius:
						var coverage_pos = Vector2i(sample_pos.x + offset_x, sample_pos.y + offset_y)
						fill_positions.append(coverage_pos)

			var angle_variation = generation_params.fill_noise_variation * angle_step
			angle += angle_step + rng.randf_range(-angle_variation, angle_variation)

	# Apply organic fill with gradual density increase
	for pos in fill_positions:
		if not boundaries_layer or boundaries_layer.get_cell_source_id(pos) != -1:  # If no boundaries_layer or tree already exists
			var distance_from_center = pos.distance_to(Vector2.ZERO)
			var organic_fill_chance = _calculate_organic_fill_chance(distance_from_center, min_arena_radius, max_fill_radius, rng)

			if rng.randf() < organic_fill_chance:
				_place_boundary_element(pos, rng)

func _get_distance_from_nearest_corner(pos: Vector2i, arena_bounds: Rect2i) -> float:
	"""Calculate distance from position to nearest arena corner for natural distribution"""
	var half_w = arena_bounds.size.x / 2
	var half_h = arena_bounds.size.y / 2
	var corners = [
		Vector2i(-half_w, -half_h), Vector2i(half_w, -half_h),
		Vector2i(-half_w, half_h), Vector2i(half_w, half_h)
	]

	var min_distance = 999.0
	for corner in corners:
		var distance = pos.distance_to(corner)
		min_distance = min(min_distance, distance)

	return min_distance

func _calculate_organic_fill_chance(distance_from_center: float, min_radius: float, max_radius: float, rng: RandomNumberGenerator) -> float:
	"""Calculate ultra-strong fill chance to eliminate all gaps"""
	var base_chance = generation_params.boundary_edge_fill_chance

	# Calculate normalized distance (0.0 at min_radius, 1.0 at max_radius)
	var radius_range = max_radius - min_radius
	var normalized_distance = 0.0
	if radius_range > 0:
		normalized_distance = clamp((distance_from_center - min_radius) / radius_range, 0.0, 1.0)

	# Configurable density - use parameters for gap-free coverage
	var distance_modifier = lerp(3.0, generation_params.fill_maximum_multiplier, normalized_distance)

	# Configurable noise variation
	var noise_variation = generation_params.fill_noise_variation
	var noise_modifier = (1.0 - noise_variation) + (rng.randf() * noise_variation * 2.0)

	# Inner boundary gets strong coverage too - no weak spots
	if distance_from_center < min_radius + 2:
		distance_modifier = max(distance_modifier, generation_params.fill_maximum_multiplier * 0.5)

	# Force configurable minimum chance
	var final_chance = max(base_chance, base_chance * distance_modifier * noise_modifier)

	# Use configurable minimum placement chance
	return clamp(final_chance, generation_params.fill_minimum_chance, 1.0)

func _should_place_organic_boundary_element_with_density(pos: Vector2i, noise: FastNoiseLite, layer: int, total_layers: int, rng: RandomNumberGenerator) -> bool:
	"""Determine if an organic boundary element should be placed with density variation and camera extension gradient"""
	# Standard placement chance check
	var placement_chance = generation_params.get_effective_tree_placement_chance(biome_config)

	# Calculate density gradient - trees get denser toward outer edge
	var base_boundary_layers = generation_params.boundary_width
	var density_modifier = 1.0


	if layer >= base_boundary_layers:
		# In camera extension area - trees get MUCH denser toward outer edge
		var extension_layer = layer - base_boundary_layers
		var max_extension_layers = generation_params.camera_boundary_extension
		if max_extension_layers > 0:
			var gradient_progress = float(extension_layer) / float(max_extension_layers)
			var edge_density_multiplier = generation_params.edge_density_multiplier

			# Apply density gradient based on inversion setting
			if generation_params.invert_density_gradient:
				# Trees get denser toward outer edge (normal expectation)
				density_modifier = lerp(1.0, edge_density_multiplier, gradient_progress)
			else:
				# Trees get denser toward inner edge (inverted)
				density_modifier = lerp(edge_density_multiplier, 1.0, gradient_progress)


	# Increase placement chance based on density (like rectangular boundary logic)
	var placement_boost = density_modifier - 1.0
	placement_chance = min(1.0, placement_chance * (1.0 + placement_boost * 0.5))

	# Simplified density variation - less aggressive for reliable boundaries
	var density_noise = noise.get_noise_2d(pos.x * 0.2, pos.y * 0.2)
	var density_variation_modifier = 1.0 + (density_noise * generation_params.boundary_density_variation * 0.5)  # Reduced impact
	var adjusted_chance = placement_chance * density_variation_modifier

	if rng.randf() >= adjusted_chance:
		return false

	# Check spacing against existing trees with density modification
	var min_spacing = generation_params.get_effective_tree_spacing_min(biome_config) * (1.0 / density_modifier)
	var max_spacing = generation_params.get_effective_tree_spacing_max(biome_config) * (1.0 / density_modifier)


	for existing_tree in _placed_trees:
		var distance = pos.distance_to(existing_tree)
		var required_spacing = rng.randf_range(min_spacing, max_spacing)
		if distance < required_spacing:
			return false

	return true

func _add_simplified_organic_fill(center_pos: Vector2i, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	"""Add simplified organic fill around boundary positions for reliable thickness"""
	var fill_radius = 1.2
	var base_fill_chance = 0.8  # Higher chance for more reliable boundaries

	# Simple 3x3 area around position
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue  # Skip center position (already placed)

			var test_pos = center_pos + Vector2i(x_offset, y_offset)
			var distance = Vector2(x_offset, y_offset).length()

			if distance <= fill_radius:
				# Simple noise-based chance without complex calculations
				var noise_value = noise.get_noise_2d(test_pos.x * 0.3, test_pos.y * 0.3)
				var adjusted_chance = base_fill_chance + (noise_value * 0.2)

				if rng.randf() < clamp(adjusted_chance, 0.3, 0.95):
					# Only place if no tree already exists there
					var already_has_tree = false
					for existing_tree in _placed_trees:
						if existing_tree == test_pos:
							already_has_tree = true
							break

					if not already_has_tree:
						_place_boundary_element(test_pos, rng)

func _add_advanced_organic_fill_around_position(center_pos: Vector2i, primary_noise: FastNoiseLite,
												pocket_noise: FastNoiseLite, layer: int, rng: RandomNumberGenerator) -> void:
	"""Add advanced organic fill around boundary positions for natural thickness"""
	var fill_radius = 2.0 + (layer * 0.3)  # Larger fill radius for outer layers
	var base_fill_chance = 0.6

	# Larger sampling area for more organic fill patterns
	var sample_range = int(ceil(fill_radius)) + 1
	for x_offset in range(-sample_range, sample_range + 1):
		for y_offset in range(-sample_range, sample_range + 1):
			var test_pos = center_pos + Vector2i(x_offset, y_offset)
			var distance = Vector2(x_offset, y_offset).length()

			if distance <= fill_radius:
				# Use multiple noise layers for complex fill patterns
				var primary_noise_value = primary_noise.get_noise_2d(test_pos.x * 8.0, test_pos.y * 8.0)
				var pocket_noise_value = pocket_noise.get_noise_2d(test_pos.x * 0.2, test_pos.y * 0.2)

				# Combine noise influences for natural variation
				var noise_influence = (primary_noise_value * 0.7) + (pocket_noise_value * 0.3)
				var distance_falloff = 1.0 - (distance / fill_radius)  # Closer to center = higher chance
				var adjusted_chance = base_fill_chance * distance_falloff + (noise_influence * 0.4)

				if rng.randf() < clamp(adjusted_chance, 0.0, 0.9):
					# Only place if it doesn't conflict with existing trees
					if _should_place_organic_boundary_element(test_pos, primary_noise, rng):
						_place_boundary_element(test_pos, rng)

func _add_organic_fill_around_position(center_pos: Vector2i, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	"""Legacy organic fill function for compatibility"""
	var fill_radius = 1.5
	var fill_chance = 0.7

	for x_offset in range(-2, 3):
		for y_offset in range(-2, 3):
			var test_pos = center_pos + Vector2i(x_offset, y_offset)
			var distance = Vector2(x_offset, y_offset).length()

			if distance <= fill_radius:
				# Use noise to determine if we fill this position
				var noise_value = noise.get_noise_2d(test_pos.x * 10.0, test_pos.y * 10.0)
				var adjusted_chance = fill_chance + (noise_value * 0.3)

				if rng.randf() < adjusted_chance:
					_place_boundary_element(test_pos, rng)

func _should_place_boundary_element(pos: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Determine if a boundary element should be placed"""
	var placement_chance = generation_params.get_effective_tree_placement_chance(biome_config)
	if rng.randf() >= placement_chance:
		return false

	# Check spacing against existing trees
	var min_spacing = generation_params.get_effective_tree_spacing_min(biome_config)
	var max_spacing = generation_params.get_effective_tree_spacing_max(biome_config)

	for existing_tree in _placed_trees:
		var distance = pos.distance_to(existing_tree)
		var required_spacing = rng.randi_range(min_spacing, max_spacing)
		if distance < required_spacing:
			return false

	return true

func _should_place_boundary_element_with_density(pos: Vector2i, layer: int, total_layers: int, rng: RandomNumberGenerator) -> bool:
	"""Determine if a boundary element should be placed with camera extension density gradient"""
	var placement_chance = generation_params.get_effective_tree_placement_chance(biome_config)

	# Calculate density gradient - trees get denser toward outer edge
	var base_boundary_layers = generation_params.boundary_width
	var density_modifier = 1.0

	if layer >= base_boundary_layers:
		# In camera extension area - trees get MUCH denser toward outer edge
		var extension_layer = layer - base_boundary_layers
		var max_extension_layers = generation_params.camera_boundary_extension
		if max_extension_layers > 0:
			var gradient_progress = float(extension_layer) / float(max_extension_layers)
			var edge_density_multiplier = generation_params.edge_density_multiplier

			# Apply density gradient based on inversion setting
			if generation_params.invert_density_gradient:
				# Trees get denser toward outer edge (normal expectation)
				density_modifier = lerp(1.0, edge_density_multiplier, gradient_progress)
			else:
				# Trees get denser toward inner edge (inverted)
				density_modifier = lerp(edge_density_multiplier, 1.0, gradient_progress)

			# Increase placement chance based on density
			var placement_boost = density_modifier - 1.0
			placement_chance = min(1.0, placement_chance * (1.0 + placement_boost * 0.5))

	if rng.randf() >= placement_chance:
		return false

	# Apply density modification to spacing requirements
	var min_spacing = generation_params.get_effective_tree_spacing_min(biome_config) * (1.0 / density_modifier)
	var max_spacing = generation_params.get_effective_tree_spacing_max(biome_config) * (1.0 / density_modifier)

	for existing_tree in _placed_trees:
		var distance = pos.distance_to(existing_tree)
		var required_spacing = rng.randf_range(min_spacing, max_spacing)
		if distance < required_spacing:
			return false

	return true

func _place_boundary_element(pos: Vector2i, rng: RandomNumberGenerator) -> void:
	"""Place a boundary element (tree) using single tree tile with Y-sorting"""

	if boundaries_layer:
		# Place single tree tile with Y-sorting enabled
		var tree_tile = Vector2i(9, 28)  # Single tree tile with proper Y-sort origin and texture origin
		boundaries_layer.set_cell(pos, 0, tree_tile)

		# Tree collision handled by tileset physics layer - no manual collision needed

	_placed_trees.append(pos)

func _place_large_flower_element(pos: Vector2i, rng: RandomNumberGenerator) -> void:
	"""Place a large flower (15, 0) using single tile with Y-sort origin"""

	# CRITICAL: Place in decorations_layer which is inside YSort_Objects
	if decorations_layer:
		# Place single flower tile - Y-sorting handled by tileset Y-Sort Origin
		var flower_tile = Vector2i(15, 0)  # Single 3x6 flower tile
		decorations_layer.set_cell(pos, 0, flower_tile)

		# Flower collision handled by tileset physics layer - no manual collision needed


func _generate_object_bases(rng: RandomNumberGenerator) -> void:
	"""Generate tree bases and other foundation objects"""
	# This will be enhanced when we implement tree z-ordering
	_safe_log("🪵 Generating object bases", "generation", "debug")

func _generate_decorations(rng: RandomNumberGenerator) -> void:
	"""Generate themed decorative elements with y-sorting depth control"""
	_safe_log("🎨 Generating y-sorted themed decorations", "generation", "debug")

	if not decorations_layer:
		return

	# Enable y-sorting for automatic depth sorting
	decorations_layer.y_sort_enabled = true

	var arena_bounds = generation_params.get_arena_bounds()
	var arena_center = Vector2i(0, 0)  # Arena center
	var margin = 2  # Keep decorations away from edges

	# Track decorations by theme for clustering
	var theme_decorations: Dictionary = {}
	var total_decorations_placed = 0

	# Collect all potential decoration positions first
	var decoration_positions: Array[Dictionary] = []

	for x in range(arena_bounds.position.x + margin, arena_bounds.end.x - margin):
		for y in range(arena_bounds.position.y + margin, arena_bounds.end.y - margin):
			if rng.randf() < generation_params.decoration_density:
				var pos = Vector2i(x, y)

				# Check if position conflicts with existing trees
				if _will_have_obstruction(pos, rng):
					continue

				# Use themed decoration system
				var decoration_result = biome_config.get_themed_decoration_tile(
					rng, pos, arena_center, arena_bounds, theme_decorations
				)

				if decoration_result.get("success", false):
					var tile = decoration_result.get("tile", Vector2i(0, 0))
					var theme_name = decoration_result.get("theme_name", "")

					decoration_positions.append({
						"pos": pos,
						"tile": tile,
						"theme_name": theme_name
					})

					# Track for clustering
					if not theme_decorations.has(theme_name):
						theme_decorations[theme_name] = []
					theme_decorations[theme_name].append(pos)

	# Apply cross-layer stone attraction logic
	decoration_positions = _apply_stone_cross_layer_attraction(decoration_positions, theme_decorations, rng)

	# Create connected stone floor formations in ground decorations layer (non-Y-sorted)
	_generate_stone_floor_formations_in_ground_decorations_layer(rng)

	# Place predefined tile patterns in walkable areas
	decoration_positions = _place_tile_patterns_in_walkable_areas(decoration_positions, theme_decorations, rng)

	# Sort decorations by Y position for proper y-sorting (stone floor tiles now in ground layer)
	decoration_positions.sort_custom(func(a, b):
		return a.pos.y < b.pos.y
	)

	# Split decorations by layer type and place them appropriately
	var y_sorted_decorations = []
	var ground_decorations = []

	for decoration_data in decoration_positions:
		# Get the theme to check its layer_name
		var theme_config = _get_theme_by_name(decoration_data.theme_name)
		if theme_config and theme_config.layer_name == "foreground":
			# Big Flowers and other foreground themes go to ground decorations (non-Y-sorted)
			ground_decorations.append(decoration_data)
		else:
			# Default to Y-sorted decorations layer
			y_sorted_decorations.append(decoration_data)

	# Place Y-sorted decorations in sorted order
	y_sorted_decorations.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for decoration_data in y_sorted_decorations:
		decorations_layer.set_cell(decoration_data.pos, 0, decoration_data.tile)
		total_decorations_placed += 1

	# Place ground decorations (no Y-sorting needed)
	if ground_decorations_layer:
		for decoration_data in ground_decorations:
			ground_decorations_layer.set_cell(decoration_data.pos, 0, decoration_data.tile)
			total_decorations_placed += 1

	_safe_log("🎨 Placed %d decorations (%d Y-sorted, %d ground) across %d themes" % [
		total_decorations_placed, y_sorted_decorations.size(), ground_decorations.size(), theme_decorations.size()
	], "generation", "debug")

	# Log theme distribution for debugging
	for theme_name in theme_decorations:
		var count = theme_decorations[theme_name].size()
		_safe_log("  Theme '%s': %d decorations" % [theme_name, count], "generation", "debug")

func _generate_interactive_objects(rng: RandomNumberGenerator) -> void:
	"""Generate interactive objects like chests and shrines"""
	_safe_log("💎 Generating interactive objects", "generation", "debug")

	# Will be implemented in the next phase
	pass

func _generate_walkable_floor_layer(rng: RandomNumberGenerator) -> void:
	"""Generate special floor tiles for walkable areas (player movement)"""
	# Always generate walkable floor - Ground layer is essential

	_safe_log("👟 Generating walkable floor areas", "generation", "debug")

	if not ground_layer:
		return

	# Get actual arena bounds (without camera extension)
	var arena_bounds = generation_params.get_arena_bounds()
	var margin = 1  # Keep walkable area slightly inside arena bounds

	# Only place walkable tiles in the actual playable arena area
	for x in range(arena_bounds.position.x + margin, arena_bounds.end.x - margin):
		for y in range(arena_bounds.position.y + margin, arena_bounds.end.y - margin):
			var tile_pos = Vector2i(x, y)

			# Check if this position will have a tree or boundary element
			if not _will_have_obstruction(tile_pos, rng):
				var walkable_tile = biome_config.get_random_walkable_floor_tile(rng)
				ground_layer.set_cell(tile_pos, 0, walkable_tile)

func _generate_spawn_layer(rng: RandomNumberGenerator) -> void:
	"""Generate spawn layer for enemy placement"""
	if not generation_params.enable_spawn_layer or not spawn_layer:
		return

	_safe_log("👾 Generating spawn layer", "generation", "debug")

	# Get arena bounds and apply spawn border spacing
	var arena_bounds = generation_params.get_arena_bounds()
	var spawn_spacing = generation_params.spawn_border_spacing

	# Create spawn area with spacing from boundaries
	for x in range(arena_bounds.position.x + spawn_spacing, arena_bounds.end.x - spawn_spacing):
		for y in range(arena_bounds.position.y + spawn_spacing, arena_bounds.end.y - spawn_spacing):
			var tile_pos = Vector2i(x, y)

			# Only place spawn tiles in open areas (not where trees will be)
			if not _will_have_obstruction(tile_pos, rng):
				var spawn_tile = biome_config.get_spawn_area_tile(rng)
				spawn_layer.set_cell(tile_pos, 0, spawn_tile)

func _will_have_obstruction(pos: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Check if a position will have a tree or other obstruction"""

	if generation_params.enable_organic_boundaries:
		return _will_have_organic_obstruction(pos, rng)
	else:
		return _will_have_rectangular_obstruction(pos, rng)

func _will_have_organic_obstruction(pos: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Check obstruction using organic boundary shape"""
	var arena_bounds = generation_params.get_arena_bounds()
	var center_x = 0
	var center_y = 0
	var base_radius_x = arena_bounds.size.x / 2.0
	var base_radius_y = arena_bounds.size.y / 2.0

	# Calculate distance from center using elliptical distance
	var dx = float(pos.x - center_x) / base_radius_x
	var dy = float(pos.y - center_y) / base_radius_y
	var elliptical_distance = sqrt(dx * dx + dy * dy)

	# Create noise for organic shape checking (same parameters as boundary generation)
	var boundary_noise = FastNoiseLite.new()
	boundary_noise.seed = generation_params.generation_seed
	boundary_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	boundary_noise.frequency = generation_params.boundary_noise_frequency
	boundary_noise.fractal_octaves = 3

	# Sample noise at this position to match organic boundary
	var noise_scale = 20.0
	var noise_x = boundary_noise.get_noise_2d(pos.x * noise_scale, pos.y * noise_scale)
	var noise_y = boundary_noise.get_noise_2d((pos.x + 100) * noise_scale, (pos.y + 100) * noise_scale)

	# Calculate organic distance threshold
	var base_threshold = 1.0 - (generation_params.spawn_border_spacing / base_radius_x)
	var noise_variation = (noise_x + noise_y) * 0.5 * 0.05  # Small variation for spawn area
	var organic_threshold = base_threshold + noise_variation

	# Position is obstructed if it's outside the organic spawn area
	return elliptical_distance > organic_threshold

func _will_have_rectangular_obstruction(pos: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Check obstruction using rectangular boundary shape"""
	var arena_bounds = generation_params.get_arena_bounds()
	var boundary_width = generation_params.boundary_width

	# Check if position is in boundary area (traditional rectangular check)
	if pos.x <= arena_bounds.position.x + boundary_width or \
	   pos.x >= arena_bounds.end.x - boundary_width or \
	   pos.y <= arena_bounds.position.y + boundary_width or \
	   pos.y >= arena_bounds.end.y - boundary_width:
		return true

	return false


func _set_player_spawn() -> void:
	"""Set the player spawn point at the center of the arena"""
	if player_spawn:
		player_spawn.position = Vector2.ZERO
		_safe_log("📍 Player spawn set to center", "generation", "debug")

func _count_layer_tiles(layer: TileMapLayer) -> int:
	"""Count tiles in a layer for statistics"""
	if not layer:
		return 0
	return layer.get_used_cells().size()

func get_arena_bounds() -> Rect2i:
	"""Get the bounds of the generated arena"""
	if not generation_params:
		_safe_log("ProceduralArenaGenerator: Cannot get bounds - generation_params is null", "generation", "error")
		return Rect2i(0, 0, 40, 30)  # Default fallback

	return generation_params.get_arena_bounds()

func regenerate_with_seed(new_seed: int) -> void:
	"""Regenerate the arena with a new seed"""
	if not generation_params:
		_safe_log("ProceduralArenaGenerator: Cannot regenerate - generation_params is null", "generation", "error")
		return

	generation_params.generation_seed = new_seed
	generate_arena()

func _apply_stone_cross_layer_attraction(decoration_positions: Array[Dictionary], theme_decorations: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""Apply cross-layer stone attraction to create natural stone groupings (OPTIMIZED)

	PERFORMANCE OPTIMIZATIONS:
	- Limited stone processing to avoid excessive iterations
	- Reduced attempts per stone position
	- Early exit for large stone counts
	"""

	# Identify stone themes by their characteristics
	var stone_theme_names = _identify_stone_themes(theme_decorations)
	if stone_theme_names.size() < 2:
		return decoration_positions  # Need at least 2 stone themes for attraction

	var enhanced_positions = decoration_positions.duplicate()
	var stone_attraction_radius = 6  # Reduced from 8 for performance
	var attraction_chance = 0.3  # Reduced from 0.4 for performance

	# Get all stone positions across all stone themes
	var all_stone_positions: Array[Vector2i] = []
	for theme_name in stone_theme_names:
		var positions = theme_decorations.get(theme_name, [])
		for pos in positions:
			all_stone_positions.append(pos)

	# OPTIMIZATION: Early exit if too many stones
	if all_stone_positions.size() > 50:
		Logger.warn("⚠️ Too many stone positions (%d) - skipping cross-layer attraction for performance" % all_stone_positions.size(), "generation")
		return enhanced_positions

	# OPTIMIZATION: Reduced attempts per stone from 3 to 2
	for stone_pos in all_stone_positions:
		# Try to place attraction stones around this position
		for attempt in range(2):  # Reduced from 3 attempts
			if rng.randf() > attraction_chance:
				continue

			# Find a nearby position for cross-layer stone attraction
			var angle = rng.randf() * TAU  # Random angle
			var distance = rng.randf_range(2, stone_attraction_radius)
			var offset = Vector2(cos(angle), sin(angle)) * distance
			var attraction_pos = Vector2i(stone_pos + Vector2i(offset))

			# Check if position is available (not too close to existing decorations)
			if _is_position_available_for_stone_attraction(attraction_pos, enhanced_positions):
				# Select a stone theme different from nearby stones for layering effect
				var target_theme = _select_complementary_stone_theme(stone_pos, theme_decorations, rng)
				if target_theme and target_theme.decoration_tiles.size() > 0:
					var stone_tile = target_theme.get_random_tile(rng)

					enhanced_positions.append({
						"pos": attraction_pos,
						"tile": stone_tile,
						"theme_name": target_theme.theme_name
					})

					# Update theme decorations tracking
					if not theme_decorations.has(target_theme.theme_name):
						theme_decorations[target_theme.theme_name] = []
					theme_decorations[target_theme.theme_name].append(attraction_pos)

	Logger.info("🪨 Applied stone cross-layer attraction: %d enhanced positions (optimized)" % enhanced_positions.size(), "generation")
	return enhanced_positions

func _identify_stone_themes(theme_decorations: Dictionary) -> Array[String]:
	"""Identify themes that contain stone elements based on theme names and characteristics"""
	var stone_theme_names: Array[String] = []

	for theme_name in theme_decorations.keys():
		# Identify stone-related themes by name patterns
		var theme_name_lower = theme_name.to_lower()
		if "stone" in theme_name_lower or "rock" in theme_name_lower or "ground decoration" in theme_name_lower:
			stone_theme_names.append(theme_name)

	return stone_theme_names

func _is_position_available_for_stone_attraction(pos: Vector2i, existing_positions: Array[Dictionary]) -> bool:
	"""Check if a position is available for stone attraction (minimum spacing)"""
	var min_spacing = 2

	for existing in existing_positions:
		var existing_pos = existing.get("pos", Vector2i.ZERO)
		if pos.distance_to(existing_pos) < min_spacing:
			return false

	return true

func _select_complementary_stone_theme(reference_pos: Vector2i, theme_decorations: Dictionary, rng: RandomNumberGenerator) -> DecorationThemeConfig:
	"""Select a stone theme that complements nearby stones for layering effect"""
	if not biome_config or biome_config.decoration_themes.is_empty():
		return null

	# Find stone themes
	var stone_themes: Array[DecorationThemeConfig] = []
	for theme in biome_config.decoration_themes:
		var theme_name_lower = theme.theme_name.to_lower()
		if "stone" in theme_name_lower or "rock" in theme_name_lower or "ground decoration" in theme_name_lower:
			stone_themes.append(theme)

	if stone_themes.is_empty():
		return null

	# Prefer themes with different z_layers for visual layering
	# Look for what stone themes are already near this position
	var nearby_themes: Array[String] = []
	var check_radius = 6

	for theme_name in theme_decorations.keys():
		var positions = theme_decorations.get(theme_name, [])
		for pos in positions:
			if reference_pos.distance_to(pos) <= check_radius:
				nearby_themes.append(theme_name)
				break

	# Select a stone theme that's not already dominant nearby
	var available_themes: Array[DecorationThemeConfig] = []
	for theme in stone_themes:
		if not theme.theme_name in nearby_themes:
			available_themes.append(theme)

	# If all nearby themes are present, use any stone theme
	if available_themes.is_empty():
		available_themes = stone_themes

	return available_themes[rng.randi() % available_themes.size()]

func _get_theme_by_name(theme_name: String) -> DecorationThemeConfig:
	"""Get a decoration theme configuration by its name"""
	if not biome_config or biome_config.decoration_themes.is_empty():
		return null

	for theme in biome_config.decoration_themes:
		if theme.theme_name == theme_name:
			return theme

	return null

func _generate_stone_floor_formations_in_ground_decorations_layer(rng: RandomNumberGenerator) -> void:
	"""Generate stone floor formations in the ground decorations layer (non-Y-sorted)"""

	if not ground_decorations_layer:
		return

	var stone_floor_tiles = [Vector2i(30, 0), Vector2i(30, 3)]

	# Street generation parameters
	var num_streets = rng.randi_range(3, 6)  # Generate 3-6 street segments
	var streets_created = 0
	var total_street_tiles = 0

	# Get arena bounds for placement
	var arena_bounds = _get_arena_bounds()
	var min_spacing = 80  # Minimum distance between street segments

	# Track placed street segments to avoid overlap
	var placed_segments: Array[Rect2i] = []

	for i in range(num_streets):
		# Random street dimensions
		var street_width = rng.randi_range(2, 5)
		var street_length = rng.randi_range(2, 5)

		# Find valid position for this street segment
		var street_pos = _find_valid_street_position(
			arena_bounds, street_width, street_length,
			min_spacing, placed_segments, [], rng
		)

		if street_pos != Vector2i.ZERO:
			# Generate street tiles directly in ground layer
			for x in range(street_width):
				for y in range(street_length):
					var tile_pos = street_pos + Vector2i(x, y)
					var selected_tile = stone_floor_tiles[rng.randi() % stone_floor_tiles.size()]
					ground_decorations_layer.set_cell(tile_pos, 0, selected_tile)
					total_street_tiles += 1

			# Track this street segment
			var segment_rect = Rect2i(street_pos, Vector2i(street_width, street_length))
			placed_segments.append(segment_rect)
			streets_created += 1

	Logger.info("🏘️ Created %d stone floor street segments with %d tiles in ground decorations layer" % [streets_created, total_street_tiles], "generation")

func _get_arena_bounds() -> Rect2i:
	"""Get arena bounds for street placement"""
	if not generation_params:
		return Rect2i(-200, -150, 400, 300)  # Default fallback
	return generation_params.get_arena_bounds()

func _find_valid_street_position(arena_bounds: Rect2i, width: int, height: int, min_spacing: int, placed_segments: Array[Rect2i], existing_positions: Array[Dictionary], rng: RandomNumberGenerator) -> Vector2i:
	"""Find a valid position for a street segment that doesn't overlap with existing elements"""
	var max_attempts = 50
	var margin = 20  # Keep streets away from arena edges

	for attempt in range(max_attempts):
		# Random position within arena bounds (with margin)
		var x = rng.randi_range(arena_bounds.position.x + margin, arena_bounds.end.x - margin - width)
		var y = rng.randi_range(arena_bounds.position.y + margin, arena_bounds.end.y - margin - height)
		var test_pos = Vector2i(x, y)
		var test_rect = Rect2i(test_pos, Vector2i(width, height))

		# Check against existing street segments
		var valid = true
		for existing_segment in placed_segments:
			# Check if rectangles intersect or are too close
			var expanded_existing = Rect2i(
				existing_segment.position - Vector2i(min_spacing/2, min_spacing/2),
				existing_segment.size + Vector2i(min_spacing, min_spacing)
			)
			if expanded_existing.intersects(test_rect):
				valid = false
				break

		if not valid:
			continue

		# Check against existing decorations
		for decoration_data in existing_positions:
			var decoration_pos = decoration_data.get("pos", Vector2i.ZERO)
			if test_rect.has_point(decoration_pos):
				valid = false
				break

		if valid:
			return test_pos

	return Vector2i.MAX  # No valid position found

func _generate_street_segment(start_pos: Vector2i, width: int, height: int, stone_tiles: Array, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""Generate a rectangular street segment with specified dimensions"""
	var street_tiles: Array[Dictionary] = []

	# Fill the rectangle with stone floor tiles
	for x in range(width):
		for y in range(height):
			var tile_pos = start_pos + Vector2i(x, y)
			var stone_tile = stone_tiles[rng.randi() % stone_tiles.size()]

			street_tiles.append({
				"pos": tile_pos,
				"tile": stone_tile,
				"theme_name": "Ground Decoration"
			})

	return street_tiles

func _generate_simple_stone_line(start: Vector2i, end: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	"""Generate simplified stone line (OPTIMIZED version of _generate_stone_path_between_points)

	Creates a direct path with minimal randomness for better performance.
	"""
	var path: Array[Vector2i] = []
	var current = start
	var max_steps = 15  # Limit path length for performance
	var steps = 0

	while current.distance_to(end) > 1 and steps < max_steps:
		var direction = Vector2(end - current).normalized()

		# Simple step direction (cardinal only for performance)
		var next_step: Vector2i
		if abs(direction.x) > abs(direction.y):
			next_step = Vector2i(1 if direction.x > 0 else -1, 0)
		else:
			next_step = Vector2i(0, 1 if direction.y > 0 else -1)

		current += next_step
		if current != end:
			path.append(current)

		steps += 1

	return path

func _generate_stone_path_between_points(start: Vector2i, end: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	"""Generate connecting stone path between two points using simple line algorithm"""
	var path: Array[Vector2i] = []
	var current = start

	# Simple step-by-step path generation
	while current.distance_to(end) > 1:
		var direction = Vector2(end - current).normalized()

		# Choose step direction (prefer cardinal directions for geometric look)
		var next_step: Vector2i
		if abs(direction.x) > abs(direction.y):
			next_step = Vector2i(1 if direction.x > 0 else -1, 0)
		else:
			next_step = Vector2i(0, 1 if direction.y > 0 else -1)

		current += next_step

		# Add some randomness for natural variation (25% chance of diagonal step)
		if rng.randf() < 0.25 and current != end:
			var diagonal_offset = Vector2i(
				1 if rng.randf() < 0.5 else -1,
				1 if rng.randf() < 0.5 else -1
			)
			# Only add diagonal if it doesn't overshoot the target
			var diagonal_pos = current + diagonal_offset
			if diagonal_pos.distance_to(end) < current.distance_to(end):
				current = diagonal_pos

		path.append(current)

		# Safety limit to prevent infinite loops
		if path.size() > 10:
			break

	return path

func _is_position_available_for_stone_connection(pos: Vector2i, existing_positions: Array[Dictionary]) -> bool:
	"""Check if position is available for stone floor connections"""
	for existing in existing_positions:
		var existing_pos = existing.get("pos", Vector2i.ZERO)
		if pos == existing_pos:
			return false  # Position already occupied

	return true

func regenerate_with_biome(new_biome: BiomeConfig) -> void:
	"""Regenerate the arena with a different biome"""
	biome_config = new_biome
	generate_arena()


func _place_tile_patterns_in_walkable_areas(decoration_positions: Array[Dictionary], theme_decorations: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""Place predefined tile patterns at random locations in walkable areas, supporting grouped patterns"""
	if not biome_config or biome_config.tile_patterns.is_empty():
		return decoration_positions

	var enhanced_positions = decoration_positions.duplicate()
	var arena_bounds = _get_arena_bounds()
	var patterns_placed = 0
	var total_pattern_tiles = 0

	# Track pattern and group instance counts
	var pattern_counts: Dictionary = {}
	var group_counts: Dictionary = {}

	# Get walkable area bounds (inner arena area without boundary)
	var walkable_margin = generation_params.boundary_width + 2  # Extra margin for safety
	var walkable_bounds = Rect2i(
		arena_bounds.position.x + walkable_margin,
		arena_bounds.position.y + walkable_margin,
		arena_bounds.size.x - (walkable_margin * 2),
		arena_bounds.size.y - (walkable_margin * 2)
	)

	# Organize patterns by groups
	var pattern_groups: Dictionary = {}
	var individual_patterns: Array[TilePatternConfig] = []

	for pattern in biome_config.tile_patterns:
		if not pattern.is_valid():
			continue

		if pattern.is_grouped():
			if not pattern_groups.has(pattern.pattern_group):
				pattern_groups[pattern.pattern_group] = []
			pattern_groups[pattern.pattern_group].append(pattern)
		else:
			individual_patterns.append(pattern)

	# Place pattern groups first
	for group_name in pattern_groups.keys():
		var group_patterns: Array = pattern_groups[group_name]
		var group_leader: TilePatternConfig = null

		# Find the group leader
		for pattern in group_patterns:
			if pattern.should_control_group_placement():
				group_leader = pattern
				break

		# If no leader specified, use first pattern as leader
		if not group_leader and not group_patterns.is_empty():
			group_leader = group_patterns[0]

		if not group_leader:
			continue

		# Check group placement chance
		if rng.randf() > group_leader.group_placement_chance:
			continue

		# Check group instance limit
		var current_group_count = group_counts.get(group_name, 0)
		if current_group_count >= group_leader.max_group_instances_per_arena:
			continue

		# Try to place the entire group at one location
		if _place_pattern_group(group_patterns, enhanced_positions, theme_decorations, walkable_bounds, rng):
			group_counts[group_name] = current_group_count + 1
			patterns_placed += group_patterns.size()

			# Count tiles and update pattern counts
			for pattern in group_patterns:
				total_pattern_tiles += pattern.pattern_tiles.size()
				pattern_counts[pattern.pattern_name] = pattern_counts.get(pattern.pattern_name, 0) + 1

	# Place individual patterns
	for pattern in individual_patterns:
		# Check if we should attempt to place this pattern
		if rng.randf() > pattern.placement_chance:
			continue

		# Check instance limit
		var current_count = pattern_counts.get(pattern.pattern_name, 0)
		if current_count >= pattern.max_instances_per_arena:
			continue

		# Try multiple placement attempts for this pattern
		var max_attempts = 10
		for attempt in range(max_attempts):
			# Find random position in walkable area
			var pattern_bounds = pattern.get_pattern_bounds()
			var test_x = rng.randi_range(
				walkable_bounds.position.x - pattern_bounds.position.x,
				walkable_bounds.end.x - pattern_bounds.end.x
			)
			var test_y = rng.randi_range(
				walkable_bounds.position.y - pattern_bounds.position.y,
				walkable_bounds.end.y - pattern_bounds.end.y
			)
			var test_pos = Vector2i(test_x, test_y)

			# Check if this position is valid
			if _is_valid_pattern_position(test_pos, pattern, enhanced_positions, rng):
				# Place the pattern
				var pattern_tiles = _generate_pattern_tiles(test_pos, pattern, rng)
				for tile_data in pattern_tiles:
					enhanced_positions.append(tile_data)
					total_pattern_tiles += 1

					# Update theme tracking (use pattern name as theme)
					if not theme_decorations.has(pattern.pattern_name):
						theme_decorations[pattern.pattern_name] = []
					theme_decorations[pattern.pattern_name].append(tile_data.pos)

				patterns_placed += 1
				pattern_counts[pattern.pattern_name] = current_count + 1
				break  # Successfully placed, try next pattern

	Logger.info("🎨 Placed %d tile patterns (%d groups) with %d total tiles" % [patterns_placed, group_counts.size(), total_pattern_tiles], "generation")
	return enhanced_positions

func _place_pattern_group(group_patterns: Array, enhanced_positions: Array[Dictionary], theme_decorations: Dictionary, walkable_bounds: Rect2i, rng: RandomNumberGenerator) -> bool:
	"""Place all patterns in a group at the same location"""
	if group_patterns.is_empty():
		return false

	# Calculate combined bounds of all patterns in the group
	var combined_bounds = Rect2i()
	var first_pattern = true

	for pattern in group_patterns:
		var pattern_bounds = pattern.get_pattern_bounds()
		if first_pattern:
			combined_bounds = pattern_bounds
			first_pattern = false
		else:
			combined_bounds = combined_bounds.expand(pattern_bounds.position)
			combined_bounds = combined_bounds.expand(pattern_bounds.position + pattern_bounds.size)

	# Try multiple placement attempts for the group
	var max_attempts = 15  # More attempts for groups since they're harder to place
	for attempt in range(max_attempts):
		# Find random position that can fit the combined bounds
		var test_x = rng.randi_range(
			walkable_bounds.position.x - combined_bounds.position.x,
			walkable_bounds.end.x - combined_bounds.end.x
		)
		var test_y = rng.randi_range(
			walkable_bounds.position.y - combined_bounds.position.y,
			walkable_bounds.end.y - combined_bounds.end.y
		)
		var group_center_pos = Vector2i(test_x, test_y)

		# Check if ALL patterns in the group can be placed at this position
		var all_valid = true
		for pattern in group_patterns:
			if not _is_valid_pattern_position(group_center_pos, pattern, enhanced_positions, rng):
				all_valid = false
				break

		if all_valid:
			# Place all patterns in the group at the same center position
			for pattern in group_patterns:
				var pattern_tiles = _generate_pattern_tiles(group_center_pos, pattern, rng)
				for tile_data in pattern_tiles:
					enhanced_positions.append(tile_data)

					# Update theme tracking (use pattern name as theme)
					if not theme_decorations.has(pattern.pattern_name):
						theme_decorations[pattern.pattern_name] = []
					theme_decorations[pattern.pattern_name].append(tile_data.pos)

			_safe_log("✨ Successfully placed pattern group '%s' with %d patterns at %s" % [
				group_patterns[0].pattern_group, group_patterns.size(), group_center_pos
			], "patterns")
			return true

	_safe_log("⚠️ Failed to place pattern group '%s' after %d attempts" % [
		group_patterns[0].pattern_group, max_attempts
	], "patterns", "warn")
	return false

func _is_valid_pattern_position(center_pos: Vector2i, pattern: TilePatternConfig, existing_positions: Array[Dictionary], rng: RandomNumberGenerator) -> bool:
	"""Check if a pattern can be placed at the given position without conflicts"""
	# Check against existing decorations
	for tile_info in pattern.pattern_tiles:
		var tile_pos = center_pos + tile_info.get("relative_pos", Vector2i.ZERO)

		# Check for obstruction (trees, boundaries)
		if _will_have_obstruction(tile_pos, rng):
			return false

		# Check against existing decorations
		for existing in existing_positions:
			var existing_pos = existing.get("pos", Vector2i.ZERO)
			if tile_pos.distance_to(existing_pos) < 2:  # Minimum spacing
				return false

	# Check spacing from other patterns of the same type
	for existing in existing_positions:
		if existing.get("theme_name", "") == pattern.pattern_name:
			var existing_pos = existing.get("pos", Vector2i.ZERO)
			if center_pos.distance_to(existing_pos) < pattern.min_spacing_from_others:
				return false

	return true

func _generate_pattern_tiles(center_pos: Vector2i, pattern: TilePatternConfig, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""Generate all tiles for a pattern at the given center position"""
	var pattern_tiles: Array[Dictionary] = []

	for tile_info in pattern.pattern_tiles:
		var relative_pos = tile_info.get("relative_pos", Vector2i.ZERO)
		var tile_coord = tile_info.get("tile", Vector2i(0, 0))
		var actual_pos = center_pos + relative_pos

		pattern_tiles.append({
			"pos": actual_pos,
			"tile": tile_coord,
			"theme_name": pattern.pattern_name
		})

	return pattern_tiles

# Debug function to test generation
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
		_safe_log("🔄 Regenerating arena (debug)", "generation")
		regenerate_with_seed(randi())
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_1:
		_safe_log("🔧 DEBUG: Key 1 pressed", "debug")
		test_pattern_placement_interactive()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_2:
		_safe_log("🔧 DEBUG: Key 2 pressed - calling create_test_pattern_at_mouse()", "debug")
		create_test_pattern_at_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_3:
		_safe_log("🔧 DEBUG: Key 3 pressed", "debug")
		clear_test_patterns()
		get_viewport().set_input_as_handled()

## Pattern Testing System Functions

func test_pattern_placement_interactive() -> void:
	"""Interactive pattern placement testing - tests patterns and groups at mouse position"""
	if not biome_config or biome_config.tile_patterns.is_empty():
		_safe_log("❌ No tile patterns configured in biome for testing", "patterns", "warn")
		return

	var mouse_pos = get_global_mouse_position()
	var tile_pos = ground_layer.local_to_map(mouse_pos) if ground_layer else Vector2i.ZERO

	_safe_log("🎯 Testing pattern placement at mouse position: %s (tile: %s)" % [mouse_pos, tile_pos], "patterns")

	# Organize patterns by groups
	var pattern_groups: Dictionary = {}
	var individual_patterns: Array[TilePatternConfig] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = generation_params.seed if generation_params else randi()

	for pattern in biome_config.tile_patterns:
		if not pattern.is_valid():
			continue

		if pattern.is_grouped():
			if not pattern_groups.has(pattern.pattern_group):
				pattern_groups[pattern.pattern_group] = []
			pattern_groups[pattern.pattern_group].append(pattern)
		else:
			individual_patterns.append(pattern)

	# Test pattern groups
	var test_results: Dictionary = {}
	for group_name in pattern_groups.keys():
		var group_patterns: Array = pattern_groups[group_name]
		var result = test_pattern_group_placement(group_patterns, tile_pos, rng)
		test_results["GROUP: " + group_name] = result

	# Test individual patterns
	for pattern in individual_patterns:
		var result = test_single_pattern_placement(pattern, tile_pos, rng)
		test_results[pattern.pattern_name] = result

	# Report results
	_report_pattern_test_results(test_results, tile_pos)

func test_single_pattern_placement(pattern: TilePatternConfig, center_pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	"""Test placing a single pattern at a specific position"""
	var result = {
		"pattern_name": pattern.pattern_name,
		"center_pos": center_pos,
		"can_place": false,
		"conflicts": [],
		"tiles_placed": 0,
		"pattern_bounds": pattern.get_pattern_bounds(),
		"placement_chance_passed": rng.randf() <= pattern.placement_chance
	}

	# Check placement chance first
	if not result.placement_chance_passed:
		result.conflicts.append("Failed placement chance roll (%.1f%% chance)" % (pattern.placement_chance * 100))
		return result

	# Check if position is valid (simplified validation for testing)
	var existing_positions: Array[Dictionary] = []  # Empty for testing
	var is_valid = true

	# Check each tile in the pattern
	for tile_info in pattern.pattern_tiles:
		var tile_pos = center_pos + tile_info.get("relative_pos", Vector2i.ZERO)
		var tile_coord = tile_info.get("tile", Vector2i.ZERO)

		# Check arena bounds
		var arena_bounds = _get_arena_bounds()
		if not arena_bounds.has_point(tile_pos):
			result.conflicts.append("Tile %s outside arena bounds" % tile_pos)
			is_valid = false
			continue

		# Check for obstructions (simplified)
		if _will_have_obstruction(tile_pos, rng):
			result.conflicts.append("Obstruction at tile %s" % tile_pos)
			is_valid = false
			continue

		# If valid, count it
		if is_valid:
			result.tiles_placed += 1

	result.can_place = is_valid and result.conflicts.is_empty()
	return result

func test_pattern_group_placement(group_patterns: Array, center_pos: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	"""Test placing a group of patterns at a specific position"""
	if group_patterns.is_empty():
		return {"can_place": false, "conflicts": ["Empty group"]}

	var group_leader: TilePatternConfig = null
	for pattern in group_patterns:
		if pattern.should_control_group_placement():
			group_leader = pattern
			break

	if not group_leader:
		group_leader = group_patterns[0]

	var result = {
		"pattern_name": "GROUP: " + group_leader.pattern_group,
		"center_pos": center_pos,
		"can_place": false,
		"conflicts": [],
		"tiles_placed": 0,
		"patterns_in_group": group_patterns.size(),
		"placement_chance_passed": rng.randf() <= group_leader.group_placement_chance
	}

	# Check placement chance first
	if not result.placement_chance_passed:
		result.conflicts.append("Failed group placement chance roll (%.1f%% chance)" % (group_leader.group_placement_chance * 100))
		return result

	# Test each pattern in the group at the same position
	var existing_positions: Array[Dictionary] = []  # Empty for testing
	var all_valid = true
	var total_tiles = 0

	for pattern in group_patterns:
		for tile_info in pattern.pattern_tiles:
			var tile_pos = center_pos + tile_info.get("relative_pos", Vector2i.ZERO)

			# Check arena bounds
			var arena_bounds = _get_arena_bounds()
			if not arena_bounds.has_point(tile_pos):
				result.conflicts.append("Pattern %s: Tile %s outside arena bounds" % [pattern.pattern_name, tile_pos])
				all_valid = false
				continue

			# Check for obstructions (simplified)
			if _will_have_obstruction(tile_pos, rng):
				result.conflicts.append("Pattern %s: Obstruction at tile %s" % [pattern.pattern_name, tile_pos])
				all_valid = false
				continue

			total_tiles += 1

	result.can_place = all_valid and result.conflicts.is_empty()
	result.tiles_placed = total_tiles
	return result

func _report_pattern_test_results(results: Dictionary, center_pos: Vector2i) -> void:
	"""Report pattern placement test results"""
	_safe_log("📊 Pattern Placement Test Results at %s:" % center_pos, "patterns")

	var total_patterns = results.size()
	var placeable_patterns = 0

	for pattern_name in results.keys():
		var result = results[pattern_name]
		var status_icon = "✅" if result.can_place else "❌"
		var chance_icon = "🎲" if result.placement_chance_passed else "⏭️"

		if pattern_name.begins_with("GROUP:"):
			# Special formatting for groups
			var group_size = result.get("patterns_in_group", 1)
			_safe_log("  %s %s %s: %d patterns, %d total tiles" % [
				status_icon, chance_icon, pattern_name, group_size, result.tiles_placed
			], "patterns")
		else:
			_safe_log("  %s %s %s: %d tiles" % [
				status_icon, chance_icon, pattern_name, result.tiles_placed
			], "patterns")

		if result.can_place:
			placeable_patterns += 1
		elif not result.conflicts.is_empty():
			for conflict in result.conflicts:
				_safe_log("    - %s" % conflict, "patterns")

	_safe_log("📈 Summary: %d/%d patterns can be placed at this location" % [placeable_patterns, total_patterns], "patterns")

func create_test_pattern_at_mouse() -> void:
	"""Create and place patterns using Godot's tileset patterns at mouse position"""
	_safe_log("🔧 DEBUG: Key 2 pressed - create_test_pattern_at_mouse() called", "debug")

	var mouse_pos = get_global_mouse_position()
	_safe_log("🔧 DEBUG: Mouse position: %s" % mouse_pos, "debug")

	var tile_pos = ground_layer.local_to_map(mouse_pos) if ground_layer else Vector2i.ZERO
	_safe_log("🔧 DEBUG: Tile position: %s" % tile_pos, "debug")
	_safe_log("🔧 DEBUG: Ground layer exists: %s" % (ground_layer != null), "debug")

	# Only try to access your actual tileset patterns - no generated patterns
	place_tileset_pattern_at_mouse()

func place_tileset_pattern_at_mouse() -> void:
	"""Debug and place actual patterns from TileMap Patterns tab"""
	_safe_log("🔧 DEBUG: place_tileset_pattern_at_mouse() called", "debug")

	if not decorations_layer:
		_safe_log("❌ DEBUG: decorations_layer is null", "debug", "error")
		return

	_safe_log("✅ DEBUG: decorations_layer found: %s" % decorations_layer.name, "debug")

	var mouse_pos = get_global_mouse_position()
	var tile_pos = decorations_layer.local_to_map(mouse_pos)
	_safe_log("🔧 DEBUG: Mouse %s -> Tile %s" % [mouse_pos, tile_pos], "debug")

	var tileset = decorations_layer.tile_set
	if not tileset:
		_safe_log("❌ DEBUG: No tileset attached to decorations layer", "debug", "error")
		return

	_safe_log("✅ DEBUG: Found tileset with %d sources" % tileset.get_source_count(), "debug")

	# For now, let's place a simple test tile to verify the system works
	_safe_log("🧪 DEBUG: Testing basic tile placement at %s" % tile_pos, "debug")

	# Use TileSet.get_pattern() to access your actual patterns!
	_safe_log("🎨 DEBUG: Accessing YOUR patterns using TileSet.get_pattern()", "debug")

	var patterns_placed = 0

	# Try to get pattern 0
	if tileset.has_method("get_pattern"):
		_safe_log("✅ DEBUG: TileSet has get_pattern() method", "debug")

		# Try to get pattern 0 and place in decorations layer (Y-sorted)
		var pattern_0 = tileset.get_pattern(0)
		if pattern_0 and pattern_0 is TileMapPattern:
			if decorations_layer:
				_safe_log("🎨 DEBUG: Found your pattern 0! Placing in decorations layer at %s" % tile_pos, "debug")
				decorations_layer.set_pattern(tile_pos, pattern_0)
				patterns_placed += 1
				_safe_log("✅ DEBUG: Your pattern 0 placed successfully in decorations layer!", "debug")
			else:
				_safe_log("❌ DEBUG: decorations_layer is null - cannot place pattern 0", "debug")
		else:
			_safe_log("❌ DEBUG: Pattern 0 is null or not a TileMapPattern", "debug")

		# Try to get pattern 1 and place in ground decorations layer (non-Y-sorted)
		var pattern_1 = tileset.get_pattern(1)
		if pattern_1 and pattern_1 is TileMapPattern:
			if ground_decorations_layer:
				_safe_log("🎨 DEBUG: Found your pattern 1! Placing in ground decorations layer at %s" % tile_pos, "debug")
				ground_decorations_layer.set_pattern(tile_pos, pattern_1)  # Same position but different layer
				patterns_placed += 1
				_safe_log("✅ DEBUG: Your pattern 1 placed successfully in ground decorations layer!", "debug")
			else:
				_safe_log("❌ DEBUG: ground_decorations_layer is null - cannot place pattern 1", "debug")
		else:
			_safe_log("❌ DEBUG: Pattern 1 is null or not a TileMapPattern", "debug")

		_safe_log("🎯 DEBUG: Placed %d of your patterns at %s" % [patterns_placed, tile_pos], "debug")
	else:
		_safe_log("❌ DEBUG: TileSet doesn't have get_pattern() method", "debug", "error")

	_safe_log("💡 DEBUG: This confirms the tile placement system works", "debug")
	_safe_log("👀 DEBUG: Look for a cross pattern of 5 tiles near mouse position %s" % mouse_pos, "debug")
	_safe_log("📍 DEBUG: World coordinates: %s, Tile coordinates: %s" % [mouse_pos, tile_pos], "debug")
	_safe_log("🎯 DEBUG: Next step: Access your actual patterns from the Patterns tab", "debug")

func clear_test_patterns() -> void:
	"""Clear all manually placed test patterns"""
	if decorations_layer:
		_safe_log("🧹 Clearing test patterns from decorations layer", "patterns")
		decorations_layer.clear()
	else:
		_safe_log("❌ No decorations layer to clear", "patterns", "error")

func get_pattern_testing_help() -> String:
	"""Get help text for pattern testing commands"""
	return """
🎯 Pattern Testing Controls:
- F6: Regenerate entire arena with new seed
- 1: Test pattern placement at mouse position (analysis only)
- 2: Place random test pattern at mouse position (visual)
- 3: Clear all test patterns

📋 Testing Workflow:
1. Move mouse to desired location
2. Press 1 to analyze placement feasibility
3. Press 2 to actually place a pattern
4. Use 3 to clear and try again

💡 Note: Will use tileset patterns (indices 0 & 1) from TileMap Patterns tab
🎯 Key 2 places both patterns together at same location (your setup!)
"""
