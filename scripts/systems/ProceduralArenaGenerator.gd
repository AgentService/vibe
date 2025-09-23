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

# Layer references (general-purpose layer system)
@onready var ground_layer: TileMapLayer = _get_layer_node("Ground")
@onready var boundaries_layer: TileMapLayer = _get_layer_node("Boundaries")
@onready var decorations_layer: TileMapLayer = _get_layer_node("Decorations")
@onready var interactive_layer: TileMapLayer = _get_layer_node("Interactive")
@onready var spawn_layer: TileMapLayer = _get_layer_node("Spawn")

# Spawn point reference
@onready var player_spawn: Marker2D = _get_spawn_point("PlayerSpawnPoint")

# Tree collision system
var tree_collision_container: Node2D

func set_arena_reference(arena: Node2D) -> void:
	"""Set arena reference for component mode - allows finding nodes relative to arena"""
	arena_reference = arena

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

	Logger.warn("TileMapLayer not found: %s" % layer_name, "procedural")
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

	Logger.warn("Spawn point not found: %s" % spawn_name, "procedural")
	return null

# Generation state
var _placed_objects: Array[Vector2] = []
var _placed_trees: Array[Vector2i] = []


func _ready() -> void:
	# Set up proper z-ordering for all layers
	_setup_layer_z_ordering()

	# Setup tree collision container
	_setup_tree_collision_system()

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
	if boundaries_layer:
		boundaries_layer.z_index = 1
		# Enable Y-sorting for trees so players can walk behind them
		boundaries_layer.y_sort_enabled = true
	if decorations_layer:
		decorations_layer.z_index = 2
	if interactive_layer:
		interactive_layer.z_index = 5

func _setup_tree_collision_system() -> void:
	"""Setup collision container for tree bases"""
	# Create collision container if it doesn't exist
	if not tree_collision_container:
		tree_collision_container = Node2D.new()
		tree_collision_container.name = "TreeCollision"
		add_child(tree_collision_container)

func _create_tree_collision(position: Vector2i, collision_radius: float = 16.0) -> void:
	"""Create collision area for a tree base at given position"""
	if not tree_collision_container or not boundaries_layer:
		return

	# Convert tile position to world position
	var world_pos = boundaries_layer.map_to_local(position)

	# Create collision body
	var tree_body = StaticBody2D.new()
	tree_body.name = "TreeCollision_%d_%d" % [position.x, position.y]
	tree_body.position = world_pos

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = collision_radius
	collision_shape.shape = circle_shape

	# Add to tree body
	tree_body.add_child(collision_shape)

	# Add to collision container
	tree_collision_container.add_child(tree_body)


func _clear_tree_collisions() -> void:
	"""Clear all tree collision areas"""
	if tree_collision_container:
		for child in tree_collision_container.get_children():
			child.queue_free()
		_safe_log("🗑️ Cleared tree collisions", "generation", "debug")

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
	if boundaries_layer:
		boundaries_layer.clear()
	if decorations_layer:
		decorations_layer.clear()
	if interactive_layer:
		interactive_layer.clear()

	# Clear tree collisions
	_clear_tree_collisions()

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
	"""Place a boundary element (tree or wall) with collision"""
	# Place tree tile with Y-sorting enabled for proper z-ordering
	var boundary_tile = biome_config.get_random_boundary_tile(rng)

	if boundaries_layer:
		boundaries_layer.set_cell(pos, 0, boundary_tile)

	# Create collision area for tree base (smaller radius for trunk only)
	_create_tree_collision(pos, 16.0)

	_placed_trees.append(pos)

func _generate_object_bases(rng: RandomNumberGenerator) -> void:
	"""Generate tree bases and other foundation objects"""
	# This will be enhanced when we implement tree z-ordering
	_safe_log("🪵 Generating object bases", "generation", "debug")

func _generate_decorations(rng: RandomNumberGenerator) -> void:
	"""Generate decorative elements within the arena"""
	_safe_log("🎨 Generating decorations", "generation", "debug")

	if not decorations_layer:
		return

	var arena_bounds = generation_params.get_arena_bounds()
	var margin = 2  # Keep decorations away from edges

	# Add decorations sparsely throughout the arena
	for x in range(arena_bounds.position.x + margin, arena_bounds.end.x - margin):
		for y in range(arena_bounds.position.y + margin, arena_bounds.end.y - margin):
			if rng.randf() < generation_params.decoration_density:
				var pos = Vector2i(x, y)
				var decoration_tile = biome_config.get_random_decoration_tile(rng)
				decorations_layer.set_cell(pos, 0, decoration_tile)

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

func regenerate_with_biome(new_biome: BiomeConfig) -> void:
	"""Regenerate the arena with a different biome"""
	biome_config = new_biome
	generate_arena()

# Debug function to test generation
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
		_safe_log("🔄 Regenerating arena (debug)", "generation")
		regenerate_with_seed(randi())
		get_viewport().set_input_as_handled()
