extends Node

## EnemyRadar view isolated test - verifies UI rendering without scene traversal.
## Tests that EnemyRadar only uses EventBus and has no domain dependencies.

var enemy_radar: EnemyRadar
var test_results: Array[String] = []
var redraw_called: bool = false

func _ready() -> void:
	print("=== EnemyRadar View Isolated Test ===")
	run_tests()

func run_tests() -> void:
	test_enemy_radar_initialization()
	test_eventbus_connection()
	test_radar_data_update()
	test_no_scene_traversal()
	
	print_results()
	get_tree().quit()

func test_enemy_radar_initialization() -> void:
	print("Test: EnemyRadar initialization")
	
	# Create EnemyRadar UI component
	enemy_radar = EnemyRadar.new()
	add_child(enemy_radar)
	
	# Wait for ready
	await get_tree().process_frame
	
	if enemy_radar != null and enemy_radar.is_inside_tree():
		test_results.append("✓ EnemyRadar initialized successfully")
	else:
		test_results.append("✗ EnemyRadar failed to initialize")

func test_eventbus_connection() -> void:
	print("Test: EventBus connection")
	
	# Check if EventBus radar signal is connected
	var is_connected = false
	
	if EventBus and EventBus.radar_data_updated:
		# Check if the signal has connections
		var connections = EventBus.radar_data_updated.get_connections()
		for connection in connections:
			if connection.callable.get_object() == enemy_radar:
				is_connected = true
				break
	
	if is_connected:
		test_results.append("✓ EnemyRadar properly connected to EventBus.radar_data_updated")
	else:
		test_results.append("✗ EnemyRadar not connected to EventBus.radar_data_updated")

func test_radar_data_update() -> void:
	print("Test: Radar data update via EventBus")
	
	# Reset redraw flag
	redraw_called = false
	
	# Connect to the draw signal to detect redraws
	if not enemy_radar.draw.is_connected(_on_draw_called):
		enemy_radar.draw.connect(_on_draw_called)
	
	# Send test radar data via EventBus with mixed enemy and boss entities
	var test_entities: Array[EventBus.RadarEntity] = [
		EventBus.RadarEntity.new(Vector2(100, 100), "enemy"),
		EventBus.RadarEntity.new(Vector2(200, 200), "enemy"),
		EventBus.RadarEntity.new(Vector2(300, 300), "boss")
	]
	var test_player_pos = Vector2(50, 50)
	
	if EventBus:
		EventBus.radar_data_updated.emit(test_entities, test_player_pos)
	
	await get_tree().process_frame
	
	# Check if radar data was updated
	if enemy_radar.radar_entities.size() == 3 and enemy_radar.player_position == test_player_pos:
		test_results.append("✓ Radar data updated correctly from EventBus (2 enemies + 1 boss)")
	else:
		test_results.append("✗ Radar data not updated correctly (entities: %d, player_pos: %s)" % [enemy_radar.radar_entities.size(), enemy_radar.player_position])
	
	if redraw_called:
		test_results.append("✓ UI redraw triggered on data update")
	else:
		test_results.append("✗ UI redraw not triggered on data update")

func test_no_scene_traversal() -> void:
	print("Test: No scene traversal (static analysis)")
	
	# Check that critical traversal methods are not used in the script
	var script_source = load("res://scenes/ui/EnemyRadar.gd").source_code
	var has_violations = false
	var violations: Array[String] = []
	
	# Check for scene traversal patterns
	var forbidden_patterns = [
		"get_parent()",
		"get_node(",
		"find_child(",
		"get_children(",
		"wave_director",
		"Arena"
	]
	
	for pattern in forbidden_patterns:
		if script_source.contains(pattern):
			has_violations = true
			violations.append(pattern)
	
	if not has_violations:
		test_results.append("✓ No scene traversal patterns found in EnemyRadar")
	else:
		test_results.append("✗ Scene traversal violations found: %s" % str(violations))
	
	# Check that the script uses EventBus properly
	if script_source.contains("EventBus.radar_data_updated"):
		test_results.append("✓ Uses EventBus.radar_data_updated signal")
	else:
		test_results.append("✗ Does not use EventBus.radar_data_updated signal")

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

func _on_draw_called() -> void:
	redraw_called = true