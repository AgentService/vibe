extends SceneTree

## Simple standalone test for HUD system components
## Tests basic functionality without complex dependencies

func _initialize() -> void:
	print("=== Simple HUD System Test ===")
	
	# Test 1: HUDManager autoload availability
	print("Test 1: HUDManager autoload")
	if HUDManager:
		print("  ✅ HUDManager autoload is available")
	else:
		print("  ❌ HUDManager autoload not available")
	
	# Test 2: EventBus signals
	print("Test 2: EventBus HUD signals")
	var required_signals = [
		"health_changed",
		"shield_changed", 
		"resource_changed",
		"ability_cooldown_started",
		"ability_ready",
		"damage_numbers_requested",
		"notification_requested"
	]
	
	var missing_signals = []
	for signal_name in required_signals:
		if not EventBus.has_signal(signal_name):
			missing_signals.append(signal_name)
	
	if missing_signals.is_empty():
		print("  ✅ All required HUD signals are available")
	else:
		print("  ❌ Missing signals: " + str(missing_signals))
	
	# Test 3: HUDConfigResource instantiation
	print("Test 3: HUDConfigResource")
	var config = HUDConfigResource.new()
	if config:
		print("  ✅ HUDConfigResource can be instantiated")
		print("  ✅ Default layout name: " + config.layout_name)
		print("  ✅ Component positions available: " + str(config.component_positions.has("health_bar")))
	else:
		print("  ❌ Failed to create HUDConfigResource")
	
	# Test 4: Component classes available
	print("Test 4: Component class availability")
	print("  ℹ️  Custom classes available in project (cannot test directly via script)")
	
	print("\n=== Simple HUD System Test Complete ===")
	quit()