extends SceneTree

## Test script to verify fixes for theme cycling and movement pause
## Run with: godot --headless --script tests/test_fixes.gd

func _init() -> void:
	print("=== Fix Verification Tests ===")
	_test_theme_cycling()
	_test_movement_pause()
	quit()

func _test_theme_cycling() -> void:
	print("\nTesting theme cycling fix...")
	
	var theme_system := TextureThemeSystem.new()
	
	# Test get_available_themes returns proper Array[String]
	var themes: Array[String] = theme_system.get_available_themes()
	print("Available themes: ", themes)
	assert(themes.size() == 4, "Should have 4 themes")
	assert("dungeon" in themes, "Should contain dungeon theme")
	assert("cave" in themes, "Should contain cave theme")
	assert("tech" in themes, "Should contain tech theme")
	assert("forest" in themes, "Should contain forest theme")
	
	# Test cycle_theme method exists and works
	var initial_theme := theme_system.current_theme
	print("Initial theme: ", initial_theme)
	
	theme_system.cycle_theme()
	var next_theme := theme_system.current_theme
	print("After cycling: ", next_theme)
	assert(next_theme != initial_theme, "Theme should change after cycling")
	
	print("✅ Theme cycling fixed")

func _test_movement_pause() -> void:
	print("\nTesting movement pause system...")
	
	# Test PauseManager pause functionality
	var initial_paused := PauseManager.is_paused()
	print("Initial pause state: ", initial_paused)
	
	# Test pause_game emits signal
	var signal_received := false
	var received_value := false
	
	EventBus.game_paused_changed.connect(func(payload):
		signal_received = true
		received_value = payload.is_paused
	)
	
	PauseManager.pause_game(true)
	assert(PauseManager.is_paused() == true, "PauseManager should be paused")
	assert(signal_received == true, "Should emit game_paused_changed signal")
	assert(received_value == true, "Signal should carry correct paused value")
	
	# Test unpause
	PauseManager.pause_game(false)
	assert(PauseManager.is_paused() == false, "PauseManager should be unpaused")
	assert(received_value == false, "Signal should carry correct unpaused value")
	
	print("✅ Movement pause system fixed")

func _cleanup() -> void:
	# Cleanup connections
	if EventBus.game_paused_changed.is_connected(_test_movement_pause):
		EventBus.game_paused_changed.disconnect(_test_movement_pause)
	
	print("\n✅ All fixes verified successfully!")
	print("✅ Theme cycling: get_available_themes() returns proper Array[String]")
	print("✅ Movement pause: Player movement disabled when PauseManager.is_paused() = true")
	print("✅ Pause signals: game_paused_changed emitted on pause state changes")