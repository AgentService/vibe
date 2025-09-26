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
	# Note: _fill_boundary_edge_gaps removed - simplified boundary system has no gaps
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
	"""Generate boundary elements - simplified or complex based on settings"""

	# Check if simplified boundaries are enabled and configured
	var use_simplified = false
	var boundary_config = null

	if "use_simplified_boundaries" in generation_params:
		use_simplified = generation_params.use_simplified_boundaries
	if "simple_boundary_config" in generation_params:
		boundary_config = generation_params.simple_boundary_config

	if use_simplified and boundary_config:
		_generate_simplified_boundary_layer_with_config(boundary_config, rng)
		return

	# All boundary generation now uses simplified system only
	_safe_log("❌ Simplified boundaries not configured - no boundary generation", "generation", "warn")


# Old rectangular boundary function removed - using simplified boundary system only

func _generate_simplified_boundary_layer_with_config(boundary_config: Resource, rng: RandomNumberGenerator) -> void:
	"""Generate simplified boundary with reliable spacing and no escape gaps"""
	_safe_log("🌲 Generating simplified boundary layer with guaranteed gap-free coverage", "generation", "debug")

	if not boundary_config:
		_safe_log("❌ No SimpleBoundaryConfig found - skipping boundary generation", "generation", "warn")
		return

	# Ensure layer references are populated - critical for boundaries_layer
	if not boundaries_layer:
		_populate_layer_references()
		if not boundaries_layer:
			_safe_log("❌ Could not initialize boundaries_layer for simplified boundary system", "generation", "error")
			return

	_safe_log("✅ Boundaries layer initialized: %s" % boundaries_layer.name, "generation", "debug")

	# Calculate tree spacing in tile units
	var tree_spacing_tiles = boundary_config.tree_spacing_pixels / 16.0
	var tree_count_placed = 0

	_safe_log("🔧 Boundary config: shape=%s, length=%.1f, spacing=%.1f tiles, rows=%d" % [
		boundary_config.base_shape, boundary_config.shape_length, tree_spacing_tiles, boundary_config.tree_row_count
	], "generation", "debug")

	# Generate trees in layers from inside to outside for consistent coverage
	for row_layer in range(boundary_config.tree_row_count):
		var layer_trees_placed = _generate_simplified_boundary_row(boundary_config, row_layer, tree_spacing_tiles, rng)
		tree_count_placed += layer_trees_placed

		_safe_log("🌲 Layer %d: Placed %d trees" % [row_layer, layer_trees_placed], "generation", "debug")

	_safe_log("✅ Simplified boundary complete: %d trees placed in %d rows" % [
		tree_count_placed, boundary_config.tree_row_count
	], "generation")

func _generate_simplified_boundary_row(boundary_config: Resource, row_layer: int, spacing_tiles: float, rng: RandomNumberGenerator) -> int:
	"""Generate one row/layer of trees around the boundary perimeter"""
	var trees_placed = 0
	var arena_bounds = boundary_config.get_arena_bounds()

	# Calculate the distance from arena edge for this row
	var row_distance = (row_layer + 1) * spacing_tiles

	match boundary_config.base_shape:
		"Circle":
			trees_placed = _generate_circular_boundary_row(boundary_config, row_layer, row_distance, spacing_tiles, rng)
		"Rectangle":
			trees_placed = _generate_rectangular_boundary_row(boundary_config, row_layer, row_distance, spacing_tiles, rng)
		_:
			_safe_log("❌ Unknown boundary shape: %s" % boundary_config.base_shape, "generation", "error")

	return trees_placed

func _generate_circular_boundary_row(boundary_config: Resource, row_layer: int, row_distance: float, spacing_tiles: float, rng: RandomNumberGenerator) -> int:
	"""Generate trees in an elliptical pattern around the arena using shape_length for tictac stretching"""
	var trees_placed = 0
	var base_radius = boundary_config.arena_base_size

	# Apply shape_length to create elliptical boundaries (tictac-like stretching)
	var x_radius = (base_radius * boundary_config.shape_length) + row_distance
	var y_radius = base_radius + row_distance

	# Calculate ellipse perimeter approximation for tree count
	# Ramanujan's approximation: π * (3(a+b) - sqrt((3a+b)(a+3b)))
	var a = x_radius
	var b = y_radius
	var perimeter_approx = PI * (3 * (a + b) - sqrt((3 * a + b) * (a + 3 * b)))
	var tree_count = max(8, int(perimeter_approx / spacing_tiles))  # Minimum 8 trees per ellipse

	for i in range(tree_count):
		var angle = (i * 2.0 * PI) / tree_count
		# Use elliptical coordinates with different x and y radii
		var x = int(x_radius * cos(angle))
		var y = int(y_radius * sin(angle))
		var tree_pos = Vector2i(x, y)

		# Use density check to maintain reliable coverage
		if rng.randf() < boundary_config.tree_density:
			_place_simplified_boundary_tree(tree_pos, boundary_config, rng)
			trees_placed += 1

	return trees_placed

func _generate_rectangular_boundary_row(boundary_config: Resource, row_layer: int, row_distance: float, spacing_tiles: float, rng: RandomNumberGenerator) -> int:
	"""Generate trees in a rectangular pattern around the arena"""
	var trees_placed = 0
	var arena_bounds = boundary_config.get_arena_bounds()

	# Expand the rectangle by row_distance
	var expanded_bounds = Rect2i(
		arena_bounds.position.x - int(row_distance),
		arena_bounds.position.y - int(row_distance),
		arena_bounds.size.x + int(row_distance * 2),
		arena_bounds.size.y + int(row_distance * 2)
	)

	# Generate trees along the perimeter with consistent spacing
	var spacing_int = max(1, int(spacing_tiles))

	# Top and bottom edges
	for x in range(expanded_bounds.position.x, expanded_bounds.end.x, spacing_int):
		var top_pos = Vector2i(x, expanded_bounds.position.y)
		var bottom_pos = Vector2i(x, expanded_bounds.end.y - 1)

		if rng.randf() < boundary_config.tree_density:
			_place_simplified_boundary_tree(top_pos, boundary_config, rng)
			trees_placed += 1

		if rng.randf() < boundary_config.tree_density:
			_place_simplified_boundary_tree(bottom_pos, boundary_config, rng)
			trees_placed += 1

	# Left and right edges (excluding corners to avoid double placement)
	for y in range(expanded_bounds.position.y + spacing_int, expanded_bounds.end.y - spacing_int, spacing_int):
		var left_pos = Vector2i(expanded_bounds.position.x, y)
		var right_pos = Vector2i(expanded_bounds.end.x - 1, y)

		if rng.randf() < boundary_config.tree_density:
			_place_simplified_boundary_tree(left_pos, boundary_config, rng)
			trees_placed += 1

		if rng.randf() < boundary_config.tree_density:
			_place_simplified_boundary_tree(right_pos, boundary_config, rng)
			trees_placed += 1

	return trees_placed

func _place_simplified_boundary_tree(pos: Vector2i, boundary_config: Resource, rng: RandomNumberGenerator) -> void:
	"""Place a tree using simplified boundary system with alternative tree tiles"""
	if not boundaries_layer:
		_safe_log("❌ No boundaries layer found for tree placement", "generation", "error")
		return

	# Get tree tile variant (supports alternative trees with bigger collision)
	var tree_tile = boundary_config.get_random_tree_tile(rng)

	# Place tree with source ID 0 (standard tileset source)
	boundaries_layer.set_cell(pos, 0, tree_tile)

	# Track placed trees for conflict detection
	_placed_trees.append(pos)

	_safe_log("🌲 Placed tree variant %s at %s" % [tree_tile, pos], "generation", "debug")


# OLD COMPLEX BOUNDARY FUNCTIONS REMOVED - See git history if needed

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
	"""Check if a position will have a tree or other obstruction - simplified boundary system"""
	# Use simplified boundary system for obstruction detection
	return _will_have_simplified_boundary_obstruction(pos, rng)

func _will_have_simplified_boundary_obstruction(pos: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Check obstruction using simplified boundary system"""
	# Get simplified boundary config if available
	var boundary_config = null
	if "simple_boundary_config" in generation_params:
		boundary_config = generation_params.simple_boundary_config
	
	if not boundary_config:
		# Fallback to basic arena bounds check
		var arena_bounds = generation_params.get_arena_bounds()
		var boundary_width = generation_params.boundary_width
		
		if pos.x <= arena_bounds.position.x + boundary_width or \
		   pos.x >= arena_bounds.end.x - boundary_width or \
		   pos.y <= arena_bounds.position.y + boundary_width or \
		   pos.y >= arena_bounds.end.y - boundary_width:
			return true
		return false
	
	# Use simplified boundary config for more accurate obstruction detection
	# Check if position is outside the arena (inside boundary area)
	return not boundary_config.is_inside_arena(pos)


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
