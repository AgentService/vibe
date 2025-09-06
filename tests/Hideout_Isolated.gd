extends Node

## Hideout Isolated Test
## Tests MapDevice interaction and signal emission in isolation
## Verifies that MapDevice emits enter_map_requested with correct payload

var test_results = []
var signal_captured = false
var captured_map_id: StringName

func _ready():
	print("=== Hideout Isolated Test ===")
	
	# Connect to the typed signal to capture it
	EventBus.enter_map_requested.connect(_on_enter_map_requested)
	
	await test_map_device_interaction()
	
	if test_results.size() == 0:
		print("\n=== All Hideout Isolated Tests Passed ===")
		get_tree().quit(0)
	else:
		print("\n=== Test Failures ===")
		for failure in test_results:
			print("  " + failure)
		get_tree().quit(1)

func test_map_device_interaction():
	print("\n1. Testing MapDevice signal emission...")
	
	# Create MapDevice instance
	var map_device_scene = load("res://scenes/core/MapDevice.gd")
	if not map_device_scene:
		test_results.append("FAIL: Could not load MapDevice script")
		return
	
	# Create Area2D and attach the script
	var map_device = Area2D.new()
	map_device.set_script(map_device_scene)
	map_device.name = "MapDevice"
	
	# Set test configuration
	map_device.map_id = StringName("forest_01")
	map_device.map_display_name = "Test Forest"
	
	add_child(map_device)
	
	# Wait for MapDevice to initialize
	await get_tree().process_frame
	
	# Simulate _activate_map_device() call (since we can't easily simulate player interaction)
	if map_device.has_method("_activate_map_device"):
		signal_captured = false
		captured_map_id = StringName()
		
		# Call the activation method directly
		map_device._activate_map_device()
		
		# Wait a frame for signal processing
		await get_tree().process_frame
		
		# Verify signal was emitted with correct data
		if not signal_captured:
			test_results.append("FAIL: enter_map_requested signal was not emitted")
		elif captured_map_id != StringName("forest_01"):
			test_results.append("FAIL: enter_map_requested emitted wrong map_id. Expected 'forest_01', got: " + str(captured_map_id))
		else:
			print("  PASS: MapDevice emitted enter_map_requested with correct map_id: " + str(captured_map_id))
	else:
		test_results.append("FAIL: MapDevice does not have _activate_map_device method")
	
	# Clean up
	map_device.queue_free()

func _on_enter_map_requested(map_id: StringName):
	"""Called when the typed signal is emitted"""
	signal_captured = true
	captured_map_id = map_id
	print("  Signal captured: enter_map_requested(" + str(map_id) + ")")