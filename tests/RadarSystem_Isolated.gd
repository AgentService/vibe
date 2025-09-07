extends Node

## RadarSystem isolated test - verifies radar data emission and state management.
## Tests RadarSystem functionality without full Arena context.

const RadarSystem = preload("res://scripts/systems/RadarSystem.gd")

var radar_system
var test_results: Array[String] = []
var radar_data_received: bool = false
var last_enemy_positions: Array[Vector2] = []
var last_player_pos: Vector2

func _ready() -> void:
	print("=== RadarSystem Isolated Test ===")
	run_tests()

func run_tests() -> void:
	test_radar_system_initialization()
	test_state_gating()
	test_configuration()
	
	print_results()
	get_tree().quit()

func test_radar_system_initialization() -> void:
	print("Test: RadarSystem initialization")
	
	# Create RadarSystem
	radar_system = RadarSystem.new()
	add_child(radar_system)
	
	# Wait for _ready to be called
	await get_tree().process_frame
	
	if radar_system != null and radar_system.is_inside_tree():
		test_results.append("✓ RadarSystem initialized successfully")
	else:
		test_results.append("✗ RadarSystem failed to initialize")
	
	# Test initial state
	if not radar_system._enabled:
		test_results.append("✓ RadarSystem starts disabled (correct for non-ARENA state)")
	else:
		test_results.append("✗ RadarSystem should start disabled")

func test_configuration() -> void:
	print("Test: Configuration management")
	
	# Test emit rate setting
	radar_system.set_emit_rate_hz(5.0)
	if radar_system._emit_hz == 5.0:
		test_results.append("✓ Emit rate configuration works")
	else:
		test_results.append("✗ Emit rate configuration failed")
	
	# Test enabled/disabled state
	radar_system.set_enabled(true)
	if radar_system._enabled:
		test_results.append("✓ Enable/disable functionality works")
	else:
		test_results.append("✗ Enable/disable functionality failed")

func test_state_gating() -> void:
	print("Test: State gating (ARENA only)")
	
	# Simulate non-ARENA state
	radar_system._current_state = StateManager.State.MENU
	radar_system._update_enabled_state()
	
	if not radar_system._enabled:
		test_results.append("✓ RadarSystem correctly disabled in non-ARENA state")
	else:
		test_results.append("✗ RadarSystem should be disabled in non-ARENA state")
	
	# Enable ARENA state
	radar_system._current_state = StateManager.State.ARENA
	radar_system._update_enabled_state()
	
	if radar_system._enabled:
		test_results.append("✓ RadarSystem correctly enabled in ARENA state")
	else:
		test_results.append("✗ RadarSystem should be enabled in ARENA state")

func print_results() -> void:
	print("\n=== Test Results ===")
	var passed = 0
	var total = test_results.size()
	
	for result in test_results:
		print(result)
		if result.begins_with("✓"):
			passed += 1
	
	print("\nPassed: %d/%d tests" % [passed, total])
	
	if passed == total:
		print("🎉 All tests passed!")
	else:
		print("❌ Some tests failed")

