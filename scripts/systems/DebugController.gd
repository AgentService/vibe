extends Node

## Debug Controller - Phase 3 Arena Refactoring
## Handles all debug input actions (F11, F12, B, C, T keys) and debug testing
## Can be disabled in production builds

class_name DebugController

const PerformanceMonitor_Type = preload("res://scripts/systems/PerformanceMonitor.gd")

# System references needed for debug actions
var card_system: CardSystem
var arena_ref: Node  # Reference to Arena for accessing HUD, player, etc.
var performance_monitor

var enabled: bool = true

func setup(arena: Node, deps: Dictionary) -> void:
	arena_ref = arena
	card_system = deps.get("card_system")
	
	# Create performance monitor for debug stats
	performance_monitor = PerformanceMonitor_Type.new()
	add_child(performance_monitor)

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey and event.pressed):
		return
		
	match event.keycode:
		KEY_C:
			Logger.info("Manual card selection test", "debug")
			_test_card_selection()
		KEY_F12:
			Logger.info("Performance stats display", "debug")
			_display_performance_stats()
		# F11, B, T keys removed - obsolete debug functions

# Debug Methods - Only essential ones kept active

func _test_card_selection() -> void:
	Logger.info("=== MANUAL CARD SELECTION TEST ===", "debug")
	if not card_system:
		Logger.error("Card system not available for test", "debug")
		return
	
	# Simulate level up with level 1 cards
	var test_cards: Array[CardResource] = card_system.get_card_selection(1, 3)
	Logger.info("Got " + str(test_cards.size()) + " test cards", "debug")
	
	if test_cards.is_empty():
		Logger.error("No test cards available", "debug")
		return
	
	Logger.info("Pausing game for manual test", "debug")
	PauseManager.pause_game(true)
	Logger.debug("Game pause state after PauseManager.pause_game(true): " + str(get_tree().paused), "debug")
	Logger.info("Opening card selection manually", "debug")
	
	if arena_ref.ui_manager:
		arena_ref.ui_manager.open_card_selection(test_cards)
	else:
		Logger.error("UI manager not available for card selection test", "debug")

func _display_performance_stats() -> void:
	Logger.info("=== PERFORMANCE STATS DEBUG TEST ===", "debug")
	if not performance_monitor:
		Logger.error("Performance monitor not available", "debug")
		return
	
	# Gather system references from arena
	var wave_director = arena_ref._injected.get("WaveDirector")
	var ability_system = arena_ref._injected.get("AbilitySystem")
	
	if not wave_director:
		Logger.warn("WaveDirector not available for performance stats", "debug")
	if not ability_system:
		Logger.warn("AbilitySystem not available for performance stats", "debug")
	
	# Get and display performance stats
	var stats = performance_monitor.get_debug_stats(arena_ref, wave_director, ability_system)
	performance_monitor.print_stats(stats)
	
	Logger.info("Performance stats completed", "debug")

# Obsolete debug methods removed - F11, B, T keys no longer needed