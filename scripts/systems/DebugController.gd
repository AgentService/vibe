extends Node

## Debug Controller - Phase 3 Arena Refactoring
## Handles all debug input actions (F11, F12, B, C, T keys) and debug testing
## Can be disabled in production builds

class_name DebugController

# System references needed for debug actions
var card_system: CardSystem
var arena_ref: Node  # Reference to Arena for accessing HUD, player, etc.

var enabled: bool = true

func setup(arena: Node, deps: Dictionary) -> void:
	arena_ref = arena
	card_system = deps.get("card_system")

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey and event.pressed):
		return
		
	match event.keycode:
		KEY_C:
			Logger.info("Manual card selection test", "debug")
			_test_card_selection()
		# F11, F12, B, T keys removed - obsolete debug functions

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

# Obsolete debug methods removed - F11, F12, B, T keys no longer needed