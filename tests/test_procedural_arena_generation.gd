extends Node2D

## Test suite for new ProceduralArenaGenerator system
## Validates that the general system works with forest biome configuration

func _ready() -> void:
	print("=== Procedural Arena Generation Test ===")

	# Auto-quit for headless mode, interactive for visual debugging
	if DisplayServer.get_name() == "headless":
		_run_automated_tests()
	else:
		print("Interactive mode - tests will run automatically")
		_run_automated_tests()

func _run_automated_tests() -> void:
	# Test 1: Validate resource loading
	_test_resource_loading()

	# Test 2: Create and test procedural arena
	_test_procedural_arena_creation()

	# Test 3: Test arena generation
	_test_arena_generation()

	print("=== Procedural Arena Generation tests completed ===")

	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func _test_resource_loading() -> void:
	print("\n--- Testing resource loading ---")

	# Test BiomeConfig loading
	var forest_biome = load("res://data/content/biomes/ForestBiome.tres")
	assert(forest_biome != null, "Failed to load ForestBiome.tres")
	assert(forest_biome is BiomeConfig, "ForestBiome is not a BiomeConfig")
	assert(forest_biome.is_valid(), "ForestBiome configuration is invalid")

	print("✓ ForestBiome loaded successfully: %s" % forest_biome.biome_name)
	print("  Floor tiles: %d, Boundary tiles: %d" % [forest_biome.floor_tiles.size(), forest_biome.boundary_tiles.size()])

	# Test GenerationParams loading
	var generation_params = load("res://data/content/biomes/DefaultGenerationParams.tres")
	assert(generation_params != null, "Failed to load DefaultGenerationParams.tres")
	assert(generation_params is GenerationParams, "DefaultGenerationParams is not a GenerationParams")
	assert(generation_params.is_valid(), "GenerationParams configuration is invalid")

	print("✓ GenerationParams loaded successfully: %s arena" % generation_params.arena_size)

func _test_procedural_arena_creation() -> void:
	print("\n--- Testing procedural arena creation ---")

	# Load the ProceduralArena scene
	var arena_scene = load("res://scenes/arena/ProceduralArena.tscn")
	assert(arena_scene != null, "Failed to load ProceduralArena.tscn")

	var arena_instance = arena_scene.instantiate()
	assert(arena_instance != null, "Failed to instantiate ProceduralArena")
	assert(arena_instance is ProceduralArenaGenerator, "Arena instance is not a ProceduralArenaGenerator")

	# Add to scene tree
	add_child(arena_instance)

	# Validate layer structure
	var ground_layer = arena_instance.get_node("Ground")
	var object_bases_layer = arena_instance.get_node("ObjectBases")
	var decorations_layer = arena_instance.get_node("Decorations")
	var interactive_layer = arena_instance.get_node("Interactive")
	var object_tops_layer = arena_instance.get_node("ObjectTops")

	assert(ground_layer != null and ground_layer is TileMapLayer, "Ground layer missing or wrong type")
	assert(object_bases_layer != null and object_bases_layer is TileMapLayer, "ObjectBases layer missing or wrong type")
	assert(decorations_layer != null and decorations_layer is TileMapLayer, "Decorations layer missing or wrong type")
	assert(interactive_layer != null and interactive_layer is TileMapLayer, "Interactive layer missing or wrong type")
	assert(object_tops_layer != null and object_tops_layer is TileMapLayer, "ObjectTops layer missing or wrong type")

	# Validate z-ordering
	assert(ground_layer.z_index == 0, "Ground layer z-index incorrect")
	assert(object_bases_layer.z_index == 1, "ObjectBases layer z-index incorrect")
	assert(decorations_layer.z_index == 2, "Decorations layer z-index incorrect")
	assert(interactive_layer.z_index == 5, "Interactive layer z-index incorrect")
	assert(object_tops_layer.z_index == 10, "ObjectTops layer z-index incorrect")
	assert(object_tops_layer.y_sort_enabled, "ObjectTops y_sort not enabled")

	print("✓ ProceduralArena created with proper 5-layer structure")
	print("  Z-indices: Ground(0), ObjectBases(1), Decorations(2), Interactive(5), ObjectTops(10)")

	# Store reference for next test
	_arena_instance = arena_instance

var _arena_instance: ProceduralArenaGenerator

func _test_arena_generation() -> void:
	print("\n--- Testing arena generation ---")

	if not _arena_instance:
		print("❌ No arena instance available for generation test")
		return

	# Wait a frame for setup to complete
	await get_tree().process_frame

	# Manually trigger generation
	_arena_instance.generate_arena()

	# Wait for generation to complete
	await _arena_instance.generation_complete

	# Validate generation results
	var ground_layer = _arena_instance.get_node("Ground")
	var object_bases_layer = _arena_instance.get_node("ObjectBases")
	var decorations_layer = _arena_instance.get_node("Decorations")

	var ground_tiles = ground_layer.get_used_cells()
	var boundary_tiles = object_bases_layer.get_used_cells()
	var decoration_tiles = decorations_layer.get_used_cells()

	print("✓ Arena generation completed")
	print("  Ground tiles: %d" % ground_tiles.size())
	print("  Boundary tiles: %d" % boundary_tiles.size())
	print("  Decoration tiles: %d" % decoration_tiles.size())

	# Validate that we have reasonable tile counts
	assert(ground_tiles.size() > 1000, "Too few ground tiles generated")
	assert(boundary_tiles.size() > 100, "Too few boundary tiles generated")

	# Test arena bounds
	var arena_bounds = _arena_instance.get_arena_bounds()
	print("  Arena bounds: %s" % arena_bounds)
	assert(arena_bounds.size.x == 40 and arena_bounds.size.y == 30, "Arena bounds incorrect")

	# Test regeneration with different seed
	var original_seed = _arena_instance.generation_params.generation_seed
	_arena_instance.regenerate_with_seed(99999)

	var new_ground_tiles = ground_layer.get_used_cells()
	print("✓ Arena regeneration with new seed completed")
	print("  New ground tiles: %d" % new_ground_tiles.size())

	# Should have same tile count but potentially different layout
	assert(new_ground_tiles.size() == ground_tiles.size(), "Regeneration changed tile count unexpectedly")

	print("✓ Procedural arena generation system working correctly")