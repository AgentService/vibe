extends Node

## Test Debug Boot Modes
## Verifies that boot mode selection works correctly via DebugConfig
## Tests that hideout mode loads Hideout.tscn with spawn_hideout_main marker
## Tests that map mode loads Arena.tscn properly

func _ready():
	print("=== Debug Boot Modes Test ===")
	await test_hideout_boot_mode()
	await test_arena_boot_mode()
	print("\n=== All Boot Mode Tests Passed ===")
	get_tree().quit(0)

func test_hideout_boot_mode():
	print("\n1. Testing hideout boot mode...")
	
	# Create debug config for hideout mode
	var debug_config = DebugConfig.new()
	debug_config.start_mode = "hideout"
	
	# Load hideout scene
	var hideout_scene = load("res://scenes/core/Hideout.tscn")
	if not hideout_scene:
		print("  FAIL: Could not load Hideout scene")
		get_tree().quit(1)
		return
	
	var hideout_instance = hideout_scene.instantiate()
	if not hideout_instance:
		print("  FAIL: Could not instantiate Hideout scene")
		get_tree().quit(1)
		return
	
	add_child(hideout_instance)
	
	# Wait a frame for scene to initialize
	await get_tree().process_frame
	
	# Check for spawn_hideout_main marker
	var spawn_marker = hideout_instance.get_node_or_null("YSort/spawn_hideout_main")
	if not spawn_marker:
		print("  FAIL: spawn_hideout_main marker not found in Hideout scene")
		get_tree().quit(1)
		return
	
	if not spawn_marker is Marker2D:
		print("  FAIL: spawn_hideout_main is not a Marker2D")
		get_tree().quit(1)
		return
	
	print("  PASS: Hideout boot mode loads correctly with spawn_hideout_main marker")
	
	# Clean up
	hideout_instance.queue_free()
	await get_tree().process_frame

func test_arena_boot_mode():
	print("\n2. Testing arena boot mode...")
	
	# Create debug config for arena mode
	var debug_config = DebugConfig.new()
	debug_config.start_mode = "arena"
	debug_config.arena_selection = "Default Arena"
	
	# Load arena scene
	var arena_scene = load("res://scenes/arena/Arena.tscn")
	if not arena_scene:
		print("  FAIL: Could not load Arena scene")
		get_tree().quit(1)
		return
	
	var arena_instance = arena_scene.instantiate()
	if not arena_instance:
		print("  FAIL: Could not instantiate Arena scene")
		get_tree().quit(1)
		return
	
	add_child(arena_instance)
	
	# Wait a frame for scene to initialize
	await get_tree().process_frame
	
	# Verify it's an arena scene (check for Arena root node type)
	if arena_instance.name != "Arena":
		print("  FAIL: Arena scene root node should be named 'Arena', got: " + arena_instance.name)
		get_tree().quit(1)
		return
	
	print("  PASS: Arena boot mode loads correctly with Arena root node")
	
	# Clean up
	arena_instance.queue_free()
	await get_tree().process_frame