extends Node

## Test script for forest arena generation
## Validates that tiles are placed correctly and generation works

@onready var forest_arena: ProceduralArenaGenerator = $ForestArena

func _ready() -> void:
	print("=== Forest Arena Generation Test ===")
	
	if not forest_arena:
		print("ERROR: ForestArena node not found!")
		get_tree().quit(1)
		return
	
	# Connect to generation complete signal
	forest_arena.generation_complete.connect(_on_generation_complete)
	
	print("Waiting for arena generation to complete...")

func _on_generation_complete() -> void:
	print("Arena generation completed! Running validation tests...")
	
	# Test 1: Check if TileMapLayers exist and have tiles
	var ground_layer = forest_arena.get_node("Ground") as TileMapLayer
	var boundaries_layer = forest_arena.get_node("Boundaries") as TileMapLayer

	if not ground_layer:
		print("FAIL: Ground layer not found")
		get_tree().quit(1)
		return

	if not boundaries_layer:
		print("FAIL: Boundaries layer not found")
		get_tree().quit(1)
		return

	print("PASS: TileMapLayers found")
	
	# Test 2: Check if arena has floor tiles
	var ground_tiles_count = count_tiles_in_layer(ground_layer)
	print("Ground tiles count: ", ground_tiles_count)
	
	if ground_tiles_count == 0:
		print("FAIL: No ground tiles found")
		get_tree().quit(1)
		return
	
	print("PASS: Ground tiles generated")
	
	# Test 3: Check if arena has boundary tiles
	var boundary_tiles_count = count_tiles_in_layer(boundaries_layer)
	print("Boundary tiles count: ", boundary_tiles_count)

	if boundary_tiles_count == 0:
		print("FAIL: No boundary tiles found")
		get_tree().quit(1)
		return

	print("PASS: Boundary tiles generated")
	
	# Test 4: Check arena bounds
	var arena_bounds = forest_arena.get_arena_bounds()
	print("Arena bounds: ", arena_bounds)
	
	if arena_bounds.size.x <= 0 or arena_bounds.size.y <= 0:
		print("FAIL: Invalid arena bounds")
		get_tree().quit(1)
		return
	
	print("PASS: Arena bounds valid")
	
	# Test 5: Check player spawn point
	var player_spawn = forest_arena.get_node("PlayerSpawnPoint") as Marker2D
	if player_spawn and player_spawn.position == Vector2.ZERO:
		print("PASS: Player spawn point set correctly")
	else:
		print("FAIL: Player spawn point not set correctly")
		get_tree().quit(1)
		return
	
	print("=== All Tests Passed! ===")
	print("Forest arena generation is working correctly.")
	
	# Test regeneration with different seed
	print("Testing regeneration with new seed...")
	forest_arena.regenerate_with_seed(98765)
	
	# Wait a bit then exit successfully
	await get_tree().create_timer(1.0).timeout
	print("Test completed successfully!")
	get_tree().quit(0)

func count_tiles_in_layer(layer: TileMapLayer) -> int:
	"""Count non-empty tiles in a TileMapLayer"""
	var count = 0
	var used_rect = layer.get_used_rect()
	
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell_source_id = layer.get_cell_source_id(Vector2i(x, y))
			if cell_source_id != -1:  # -1 means empty cell
				count += 1
	
	return count

func _input(event: InputEvent) -> void:
	# Allow manual exit with Escape
	if event.is_action_pressed("ui_cancel"):
		print("Test cancelled by user")
		get_tree().quit(0)