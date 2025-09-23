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

# Layer references (general-purpose layer system)
@onready var ground_layer: TileMapLayer = $Ground
@onready var boundaries_layer: TileMapLayer = $Boundaries
@onready var decorations_layer: TileMapLayer = get_node_or_null("Decorations")
@onready var interactive_layer: TileMapLayer = get_node_or_null("Interactive")
@onready var spawn_layer: TileMapLayer = get_node_or_null("Spawn")

# Spawn point reference
@onready var player_spawn: Marker2D = $PlayerSpawnPoint

# Generation state
var _placed_objects: Array[Vector2] = []
var _placed_trees: Array[Vector2i] = []


func _ready() -> void:
	# Set up proper z-ordering for all layers
	_setup_layer_z_ordering()

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
	if decorations_layer:
		decorations_layer.z_index = 2
	if interactive_layer:
		interactive_layer.z_index = 5

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
	"""Generate boundary elements using biome configuration"""
	_safe_log("🌲 Generating boundary layer", "generation", "debug")

	var arena_bounds = generation_params.get_arena_bounds()
	var half_width = arena_bounds.size.x / 2
	var half_height = arena_bounds.size.y / 2

	# Camera extension expands the boundary (tree) area
	var total_boundary_width = generation_params.boundary_width + generation_params.camera_boundary_extension

	# Generate boundary elements with spacing - now includes camera extension
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

		# Place boundary elements with spacing
		for pos in potential_positions:
			if _should_place_boundary_element(pos, rng):
				_place_boundary_element(pos, rng)

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

func _place_boundary_element(pos: Vector2i, rng: RandomNumberGenerator) -> void:
	"""Place a boundary element (tree or wall)"""
	# For now, place simple boundary tile - will be enhanced with tree objects
	var boundary_tile = biome_config.get_random_boundary_tile(rng)

	if boundaries_layer:
		boundaries_layer.set_cell(pos, 0, boundary_tile)

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
	# This is a simplified check - in a full implementation, this would
	# check against the planned tree positions from _generate_boundary_layer
	var arena_bounds = generation_params.get_arena_bounds()
	var boundary_width = generation_params.boundary_width

	# Check if position is in boundary area
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
