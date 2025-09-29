extends RefCounted
class_name ArenaTileManager

## Dedicated tile management system for PathAwareArenaGenerator
## Extracted from PathAwareArenaGenerator to reduce complexity and improve maintainability

# Layer name constants
const BASE_LAYER_NAME = "BaseGreen"        # Renamed from "Base" - base layer
const GROUND_LAYER_NAME = "Green"          # Renamed from "Ground2" - first extension layer
const GROUND2_LAYER_NAME = "DarkGreen"     # Second extension layer - deeper forest
const TREES_LAYER_NAME = "Trees2"          # In YSort_Objects - needs depth sorting
const SPAWNABLE_LAYER_NAME = "SpawnableAreas"  # Hidden layer for spawn validation

## Generate all tile layers for the arena
func generate_all_tiles(generator: PathAwareArenaGenerator, path_data: Dictionary, tree_data: Array[Vector2]) -> void:
	"""Main entry point - generate all tile layers in correct order"""
	Logger.debug("ArenaTileManager: Starting tile generation", "pathgen")

	# Phase 1: Generate arena base layer
	_generate_arena_base(generator, tree_data)
	Logger.debug("Arena base generation completed", "pathgen")

	# Phase 2: Generate ground tiles
	_generate_ground_tiles(generator)
	Logger.debug("Ground tiles generation completed", "pathgen")

	# Phase 3: Generate boundary trees
	_generate_boundary_trees(generator, tree_data)
	Logger.debug("Boundary trees generation completed", "pathgen")

	Logger.debug("ArenaTileManager: All tile generation completed", "pathgen")

## Generate base ground layer covering full tree generation area plus extension
func _generate_arena_base(generator: PathAwareArenaGenerator, tree_data: Array[Vector2]) -> void:
	var base_layer = _find_layer_node(generator, BASE_LAYER_NAME)
	if not base_layer or not base_layer is TileMapLayer:
		Logger.warn("No %s TileMapLayer found in scene, skipping arena base generation" % BASE_LAYER_NAME, "pathgen")
		return

	# Clear existing base tiles first
	base_layer.clear()

	# Arena base tile configuration
	var base_source_id = 0
	var base_atlas_coords = Vector2i(3, 0)  # Base ground tile (3x3)
	var tile_size = 48  # Forest tileset uses 48x48 tiles
	var base_tiles_placed = 0

	# Calculate bounding box from actual tree positions
	var coverage_bounds = _calculate_tree_coverage_bounds(tree_data, generator.arena_base_radius)

	# Align to tile grid
	var start_x = int(coverage_bounds.position.x / tile_size) * tile_size
	var start_y = int(coverage_bounds.position.y / tile_size) * tile_size
	var end_x = int((coverage_bounds.position.x + coverage_bounds.size.x) / tile_size) * tile_size
	var end_y = int((coverage_bounds.position.y + coverage_bounds.size.y) / tile_size) * tile_size

	# Fill rectangular area with base tiles covering all trees and beyond
	for x in range(start_x, end_x + tile_size, tile_size):
		for y in range(start_y, end_y + tile_size, tile_size):
			var tile_pos = Vector2i(int(x / tile_size), int(y / tile_size))
			base_layer.set_cell(tile_pos, base_source_id, base_atlas_coords)
			base_tiles_placed += 1

	Logger.info("Generated %d arena base tiles covering tree area + %dpx extension" % [
		base_tiles_placed,
		int(generator.arena_base_radius)
	], "pathgen")

## Simplified ground tile generation - just clear layers, trees will handle their own ground tiles
func _generate_ground_tiles(generator: PathAwareArenaGenerator) -> void:
	Logger.debug("_generate_ground_tiles() called - simplified approach", "pathgen")

	var green_layer = _find_layer_node(generator, GROUND_LAYER_NAME)
	var dark_layer = _find_layer_node(generator, GROUND2_LAYER_NAME)

	# Clear existing tiles first
	if green_layer and green_layer is TileMapLayer:
		green_layer.clear()
	if dark_layer and dark_layer is TileMapLayer:
		dark_layer.clear()

	Logger.info("Ground tile layers cleared - trees will place their own green ground tiles", "pathgen")

## Generate trees using TreeBoundaryGenerator data that responds to path layout
func _generate_boundary_trees(generator: PathAwareArenaGenerator, tree_data: Array[Vector2]) -> void:
	var tree_layer = _find_layer_node(generator, TREES_LAYER_NAME)
	var green_layer = _find_layer_node(generator, GROUND_LAYER_NAME)  # Use Green layer for tree ground placement

	if not tree_layer or not tree_layer is TileMapLayer:
		Logger.warn("No %s TileMapLayer found in scene, skipping tree generation" % TREES_LAYER_NAME, "treegen")
		return

	# Clear existing tiles first
	tree_layer.clear()
	Logger.debug("Using existing Trees TileMapLayer for tile placement", "treegen")

	# Get tree positions from TreeBoundaryGenerator (these already avoid path corridors)
	if tree_data.is_empty():
		Logger.warn("No boundary tree positions available from tree generator", "treegen")
		return

	# Tree tile configuration using forest tileset
	var tree_source_id = 0
	var tree_ground_atlas_coords = Vector2i(0, 12)  # Ground beneath trees - use Green layer tileset (0,12)
	var tile_size = 48  # Forest tileset uses 48x48 tiles
	var ground_tiles_placed = 0

	for world_pos in tree_data:
		# Convert world position to tile position
		var tile_pos = Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

		# Skip if tile or nearby tiles already have trees (prevents branch overlap density)
		var has_nearby_tree = false
		var check_radius = 1  # Check 3x3 area around position
		for dx in range(-check_radius, check_radius + 1):
			for dy in range(-check_radius, check_radius + 1):
				var check_pos = tile_pos + Vector2i(dx, dy)
				if tree_layer.get_cell_source_id(check_pos) != -1:
					has_nearby_tree = true
					break
			if has_nearby_tree:
				break

		if has_nearby_tree:
			continue

		# Get random tree variant from TreeBoundaryConfiguration for visual diversity
		var selected_tree_variant = generator.tree_config.get_random_tree_tile()  # Zero-allocation RNG
		var tree_alternative_id = generator.tree_config.get_tree_alternative_tile()

		# Place tree tile with selected variant using alternative tile 1
		tree_layer.set_cell(tile_pos, tree_source_id, selected_tree_variant, tree_alternative_id)

		# Place simple green ground tile beneath tree (simplified approach)
		if green_layer and green_layer is TileMapLayer:
			# Always place green tiles (0,12) under trees in Green layer
			var ground_tile_pos = tile_pos  # Same position as tree
			green_layer.set_cell(ground_tile_pos, tree_source_id, Vector2i(0, 12))
			ground_tiles_placed += 1

	Logger.info("Placed %d boundary trees (using alternative tile 1 for variants: 0,28 & 9,28) and %d green ground tiles" % [tree_data.size(), ground_tiles_placed], "treegen")

## Helper method to find TileMapLayer nodes
func _find_layer_node(generator: PathAwareArenaGenerator, layer_name: String) -> TileMapLayer:
	Logger.debug("_find_layer_node called with: '%s'" % layer_name, "pathgen")

	# BaseGreen, Green, and Dark Green layers are outside YSort_Objects (don't need sorting)
	if layer_name == BASE_LAYER_NAME or layer_name == GROUND_LAYER_NAME or layer_name == GROUND2_LAYER_NAME:
		Logger.debug("Layer '%s' matches direct access condition" % layer_name, "pathgen")
		var layer_node = generator.get_node_or_null(layer_name)
		Logger.debug("get_node_or_null('%s') returned: %s" % [layer_name, "found" if layer_node else "null"], "pathgen")

		if layer_node and layer_node is TileMapLayer:
			Logger.debug("Layer '%s' found and is TileMapLayer" % layer_name, "pathgen")
			return layer_node as TileMapLayer
		else:
			Logger.debug("Layer '%s' failed type check - node: %s, is TileMapLayer: %s" % [
				layer_name, "found" if layer_node else "null", layer_node is TileMapLayer if layer_node else "N/A"
			], "pathgen")
	else:
		# Trees2 layer is in YSort_Objects (needs depth sorting)
		var ysort_container = generator.get_node_or_null("YSort_Objects")
		if ysort_container:
			var nested_node = ysort_container.get_node_or_null(layer_name)
			if nested_node and nested_node is TileMapLayer:
				return nested_node as TileMapLayer

	return null

## Calculate bounding rectangle that covers all generated tree positions
func _calculate_tree_coverage_bounds(tree_data: Array[Vector2], fallback_radius: float) -> Rect2:
	if tree_data.is_empty():
		var half_radius = fallback_radius
		return Rect2(-half_radius, -half_radius, half_radius * 2, half_radius * 2)

	# Find min/max positions from tree data
	var min_pos = tree_data[0]
	var max_pos = tree_data[0]

	for tree_pos in tree_data:
		min_pos.x = min(min_pos.x, tree_pos.x)
		min_pos.y = min(min_pos.y, tree_pos.y)
		max_pos.x = max(max_pos.x, tree_pos.x)
		max_pos.y = max(max_pos.y, tree_pos.y)

	# Extend tree coverage by fallback_radius in all directions
	var extension = fallback_radius
	var coverage_bounds = Rect2(min_pos, max_pos - min_pos)
	coverage_bounds = coverage_bounds.grow(extension)

	return coverage_bounds