extends Node

## Test scene for validating HUD component system functionality
## Tests component registration, layout management, and performance

var test_results: Array[Dictionary] = []
var hud_container: Control

func _ready() -> void:
	Logger.info("Starting HUD System validation tests", "ui")
	
	# Give autoloads time to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	run_all_tests()

func run_all_tests() -> void:
	print("=== HUD System Tests ===")
	
	# Test 1: HUDManager initialization
	await test_hud_manager_initialization()
	
	# Test 2: Component registration and lifecycle
	await test_component_registration()
	
	# Test 3: Layout configuration
	await test_layout_configuration()
	
	# Test 4: Performance monitoring
	await test_performance_monitoring()
	
	# Test 5: Component communication
	await test_component_communication()
	
	# Print results
	print_test_results()
	
	# Cleanup and exit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func test_hud_manager_initialization() -> void:
	print("Test 1: HUDManager Initialization")
	
	# Check if HUDManager is available
	var test_result := {
		"test_name": "HUDManager Initialization",
		"passed": false,
		"details": ""
	}
	
	if not HUDManager:
		test_result.details = "HUDManager autoload not available"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	# Check if HUDManager has required methods
	var required_methods = ["register_component", "unregister_component", "get_component", "load_layout_preset"]
	for method in required_methods:
		if not HUDManager.has_method(method):
			test_result.details = "Missing required method: " + method
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
	
	test_result.passed = true
	test_result.details = "HUDManager properly initialized with all required methods"
	test_results.append(test_result)
	print("  ✅ PASSED: " + test_result.details)
	
	await get_tree().process_frame

func test_component_registration() -> void:
	print("Test 2: Component Registration and Lifecycle")
	
	var test_result := {
		"test_name": "Component Registration",
		"passed": false,
		"details": ""
	}
	
	# Create test components
	var health_component = preload("res://scenes/ui/hud/components/core/HealthBarComponent.tscn").instantiate()
	var radar_component = preload("res://scenes/ui/hud/components/core/RadarComponent.tscn").instantiate()
	var performance_component = preload("res://scenes/ui/hud/components/debug/PerformanceComponent.tscn").instantiate()
	
	add_child(health_component)
	add_child(radar_component)
	add_child(performance_component)
	
	await get_tree().process_frame
	
	# Test registration
	var registered_components = HUDManager.get_all_components()
	var expected_components = ["health_bar", "radar", "performance"]
	
	for component_id in expected_components:
		if not registered_components.has(component_id):
			test_result.details = "Component not registered: " + component_id
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
		
		var component = registered_components[component_id]
		if not component or not component.has_method("get_performance_stats"):
			test_result.details = "Registered component invalid: " + component_id
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
	
	# Test unregistration
	health_component.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	
	registered_components = HUDManager.get_all_components()
	if registered_components.has("health_bar"):
		test_result.details = "Component not properly unregistered after free"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	test_result.passed = true
	test_result.details = "Component registration/unregistration working correctly"
	test_results.append(test_result)
	print("  ✅ PASSED: " + test_result.details)

func test_layout_configuration() -> void:
	print("Test 3: Layout Configuration")
	
	var test_result := {
		"test_name": "Layout Configuration",
		"passed": false,
		"details": ""
	}
	
	# Test loading different presets
	var presets = [
		HUDConfigResource.LayoutPreset.DEFAULT,
		HUDConfigResource.LayoutPreset.MINIMAL,
		HUDConfigResource.LayoutPreset.COMPETITIVE
	]
	
	for preset in presets:
		HUDManager.load_layout_preset(preset)
		await get_tree().process_frame
		
		# Verify the layout was applied
		if not HUDManager.hud_config:
			test_result.details = "Layout config not created for preset: " + str(preset)
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
		
		if HUDManager.hud_config.current_preset != preset:
			test_result.details = "Layout preset not applied correctly: " + str(preset)
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
	
	# Test custom positioning
	HUDManager.set_component_position("radar", Control.PRESET_TOP_LEFT, Vector2(50, 50))
	var config = HUDManager.hud_config.get_component_position("radar")
	if config.get("anchor_preset") != Control.PRESET_TOP_LEFT or config.get("offset") != Vector2(50, 50):
		test_result.details = "Custom component positioning not working"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	test_result.passed = true
	test_result.details = "Layout configuration working correctly"
	test_results.append(test_result)
	print("  ✅ PASSED: " + test_result.details)

func test_performance_monitoring() -> void:
	print("Test 4: Performance Monitoring")
	
	var test_result := {
		"test_name": "Performance Monitoring",
		"passed": false,
		"details": ""
	}
	
	# Get performance stats from HUDManager
	var performance_stats = HUDManager.get_performance_stats()
	
	if not performance_stats.has("total_components"):
		test_result.details = "Performance stats missing total_components"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	if not performance_stats.has("visible_components"):
		test_result.details = "Performance stats missing visible_components"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	# Check individual component performance stats
	var registered_components = HUDManager.get_all_components()
	for component_id in registered_components:
		var component = registered_components[component_id]
		if component.has_method("get_performance_stats"):
			var component_stats = component.get_performance_stats()
			if not component_stats.has("component_id") or not component_stats.has("update_count"):
				test_result.details = "Component performance stats incomplete: " + component_id
				test_results.append(test_result)
				print("  ❌ FAILED: " + test_result.details)
				return
	
	test_result.passed = true
	test_result.details = "Performance monitoring working correctly"
	test_results.append(test_result)
	print("  ✅ PASSED: " + test_result.details)
	
	await get_tree().process_frame

func test_component_communication() -> void:
	print("Test 5: Component Communication")
	
	var test_result := {
		"test_name": "Component Communication",
		"passed": false,
		"details": ""
	}
	
	# Test EventBus signal availability
	var required_signals = [
		"health_changed",
		"shield_changed", 
		"resource_changed",
		"ability_cooldown_started",
		"ability_ready",
		"damage_dealt",
		"notification_requested"
	]
	
	for signal_name in required_signals:
		if not EventBus.has_signal(signal_name):
			test_result.details = "Missing required signal: " + signal_name
			test_results.append(test_result)
			print("  ❌ FAILED: " + test_result.details)
			return
	
	# Test signal emission (basic test)
	var signal_received := false
	var test_callback = func(): signal_received = true
	
	EventBus.health_changed.connect(test_callback, CONNECT_ONE_SHOT)
	EventBus.health_changed.emit(75.0, 100.0)
	
	await get_tree().process_frame
	
	if not signal_received:
		test_result.details = "Signal emission/reception not working"
		test_results.append(test_result)
		print("  ❌ FAILED: " + test_result.details)
		return
	
	test_result.passed = true
	test_result.details = "Component communication via EventBus working correctly"
	test_results.append(test_result)
	print("  ✅ PASSED: " + test_result.details)

func print_test_results() -> void:
	print("\n=== Test Results Summary ===")
	
	var passed_count := 0
	var total_count := test_results.size()
	
	for result in test_results:
		var status = "✅ PASSED" if result.passed else "❌ FAILED"
		print("%s: %s - %s" % [status, result.test_name, result.details])
		if result.passed:
			passed_count += 1
	
	print("\nResults: %d/%d tests passed" % [passed_count, total_count])
	
	if passed_count == total_count:
		print("🎉 All HUD System tests PASSED!")
	else:
		print("❌ Some HUD System tests FAILED")
	
	# Log to system as well
	Logger.info("HUD System tests completed: %d/%d passed" % [passed_count, total_count], "ui")