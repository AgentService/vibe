extends Node

## Isolated test for PlayerProgression system
## Tests core progression logic: XP gain, level-ups, max level, signals

var test_results: Array[String] = []
var signals_received: Array[Dictionary] = []

func _ready() -> void:
	print("=== PlayerProgression Isolated Test ===")
	print("Testing core progression logic with dummy curve")
	
	# Set up signal monitoring
	_setup_signal_monitoring()
	
	# Run test cases
	_test_basic_xp_gain()
	_test_multi_level_up()
	_test_max_level_cap()
	_test_save_load_functionality()
	_test_unlock_system()
	
	# Print results
	_print_results()
	
	# Wait a moment then quit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _setup_signal_monitoring() -> void:
	# Connect to progression signals to verify they're emitted correctly
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.leveled_up.connect(_on_leveled_up)
	EventBus.progression_changed.connect(_on_progression_changed)
	
	print("Signal monitoring set up")

func _on_xp_gained(amount: float, new_total: float) -> void:
	signals_received.append({
		"type": "xp_gained",
		"amount": amount,
		"new_total": new_total
	})

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	signals_received.append({
		"type": "leveled_up",
		"new_level": new_level,
		"prev_level": prev_level
	})

func _on_progression_changed(state: Dictionary) -> void:
	signals_received.append({
		"type": "progression_changed",
		"state": state.duplicate()
	})

func _test_basic_xp_gain() -> void:
	print("\n--- Test 1: Basic XP Gain ---")
	
	# Reset signals
	signals_received.clear()
	
	# Ensure we start at level 1
	var initial_state = PlayerProgression.get_progression_state()
	if initial_state.level != 1 or initial_state.exp != 0.0:
		_add_result("FAIL: Initial state incorrect - Level: %d, XP: %.1f" % [initial_state.level, initial_state.exp])
		return
	
	# Gain some XP (50 - should not level up with 100 XP threshold)
	PlayerProgression.gain_exp(50.0)
	
	var state = PlayerProgression.get_progression_state()
	
	# Check state
	if state.level == 1 and state.exp == 50.0 and state.xp_to_next == 100.0:
		_add_result("PASS: Basic XP gain correct")
	else:
		_add_result("FAIL: Basic XP gain - Level: %d, XP: %.1f, Next: %.1f" % [state.level, state.exp, state.xp_to_next])
	
	# Check signals
	if signals_received.size() >= 2:
		var xp_signal = signals_received.filter(func(s): return s.type == "xp_gained")[0]
		var prog_signal = signals_received.filter(func(s): return s.type == "progression_changed")[0]
		
		if xp_signal.amount == 50.0 and xp_signal.new_total == 50.0:
			_add_result("PASS: XP gained signal correct")
		else:
			_add_result("FAIL: XP gained signal incorrect")
		
		if prog_signal.state.level == 1 and prog_signal.state.exp == 50.0:
			_add_result("PASS: Progression changed signal correct")
		else:
			_add_result("FAIL: Progression changed signal incorrect")
	else:
		_add_result("FAIL: Expected signals not received")

func _test_multi_level_up() -> void:
	print("\n--- Test 2: Multi-Level Up ---")
	
	# Reset signals
	signals_received.clear()
	
	# Gain 500 XP from current state (50 XP) - should trigger multiple level-ups
	# Level 1->2: 100 XP total (need 50 more)
	# Level 2->3: 300 XP total (need 200 more) 
	# Level 3->4: 600 XP total (need 300 more)
	# Total needed: 50 + 200 + 300 = 550, but we're giving 500, so should reach level 3
	PlayerProgression.gain_exp(500.0)
	
	var state = PlayerProgression.get_progression_state()
	
	# Should be level 3 with some XP remaining
	if state.level == 3:
		_add_result("PASS: Multi-level-up reached correct level")
	else:
		_add_result("FAIL: Multi-level-up incorrect level: %d" % state.level)
	
	# Check for level-up signals
	var level_up_signals = signals_received.filter(func(s): return s.type == "leveled_up")
	if level_up_signals.size() == 2:  # Should have 2 level-ups: 1->2, 2->3
		_add_result("PASS: Correct number of level-up signals")
	else:
		_add_result("FAIL: Expected 2 level-up signals, got %d" % level_up_signals.size())

func _test_max_level_cap() -> void:
	print("\n--- Test 3: Max Level Cap ---")
	
	# Reset signals
	signals_received.clear()
	
	# Force to max level (level 11) by gaining massive XP
	PlayerProgression.gain_exp(10000.0)
	
	var state = PlayerProgression.get_progression_state()
	
	# Should be at max level with max_level_reached flag
	if state.level == 11 and state.get("max_level_reached", false):
		_add_result("PASS: Max level reached correctly")
	else:
		_add_result("FAIL: Max level cap - Level: %d, Max reached: %s" % [state.level, state.get("max_level_reached", false)])
	
	# Try to gain more XP - should be ignored
	var xp_before = state.exp
	PlayerProgression.gain_exp(100.0)
	
	var state_after = PlayerProgression.get_progression_state()
	if state_after.exp == xp_before:
		_add_result("PASS: XP gain ignored at max level")
	else:
		_add_result("FAIL: XP gain not ignored at max level")

func _test_save_load_functionality() -> void:
	print("\n--- Test 4: Save/Load Functionality ---")
	
	# Export current state
	var saved_state = PlayerProgression.export_state()
	
	# Load a different state
	var test_profile = {"level": 5, "exp": 150.0}
	PlayerProgression.load_from_profile(test_profile)
	
	var loaded_state = PlayerProgression.get_progression_state()
	
	if loaded_state.level == 5 and loaded_state.exp == 150.0:
		_add_result("PASS: Profile loading works correctly")
	else:
		_add_result("FAIL: Profile loading incorrect - Level: %d, XP: %.1f" % [loaded_state.level, loaded_state.exp])
	
	# Test export format
	var exported = PlayerProgression.export_state()
	if exported.has("level") and exported.has("exp") and exported.has("version"):
		_add_result("PASS: Export state format correct")
	else:
		_add_result("FAIL: Export state missing required fields")

func _test_unlock_system() -> void:
	print("\n--- Test 5: Unlock System ---")
	
	# Test unlock checking (should work with empty unlock data)
	var has_basic_unlock = PlayerProgression.has_unlock("basic_ability")
	
	if has_basic_unlock == true:  # Should default to true for unknown unlocks
		_add_result("PASS: Unlock system defaults to available")
	else:
		_add_result("FAIL: Unlock system incorrect default behavior")

func _add_result(result: String) -> void:
	test_results.append(result)
	print("  " + result)

func _print_results() -> void:
	print("\n=== Test Results Summary ===")
	
	var passes = test_results.filter(func(r): return r.begins_with("PASS")).size()
	var fails = test_results.filter(func(r): return r.begins_with("FAIL")).size()
	
	print("PASSED: %d" % passes)
	print("FAILED: %d" % fails)
	
	if fails > 0:
		print("\nFAILED TESTS:")
		for result in test_results:
			if result.begins_with("FAIL"):
				print("  " + result)
	
	print("\nSignals received during testing: %d" % signals_received.size())
	
	if fails == 0:
		print("\n🎉 All tests PASSED!")
	else:
		print("\n❌ Some tests FAILED")