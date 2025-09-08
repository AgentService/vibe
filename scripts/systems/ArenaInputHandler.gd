class_name ArenaInputHandler
extends Node

# Handles all Arena-specific input events and routing to appropriate systems
# Centralized input management for pause menu, attacks, and auto-attack targeting

# System references needed for input handling
var ui_manager: ArenaUIManager
var melee_system: MeleeSystem
var player_attack_handler: PlayerAttackHandler
var arena_ref: Node  # For get_global_mouse_position()

func setup(ui_mgr: ArenaUIManager, melee_sys: MeleeSystem, attack_handler: PlayerAttackHandler, arena: Node) -> void:
	ui_manager = ui_mgr
	melee_system = melee_sys
	player_attack_handler = attack_handler
	arena_ref = arena
	Logger.info("ArenaInputHandler initialized", "input")

func _input(event: InputEvent) -> void:
	# Handle Escape key for pause menu (priority handling)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_handle_escape_key()
		get_viewport().set_input_as_handled()  # Prevent other systems from handling this ESC
		return
	
	# Handle mouse position updates for auto-attack
	if event is InputEventMouseMotion:
		_handle_mouse_motion()
	
	# Handle mouse clicks for attacks
	if event is InputEventMouseButton and event.pressed:
		_handle_mouse_click(event)
		return
	
	# All debug keys now handled by DebugController system

func _handle_escape_key() -> void:
	# Check if card selection is currently visible - if so, let it handle the input
	if ui_manager and ui_manager.get_card_selection() and ui_manager.get_card_selection().visible:
		return  # Let card selection handle the escape key
	
	# Use StateManager-aware pause system via PauseUI autoload
	if StateManager.is_pause_allowed():
		PauseManager.toggle_pause()
		Logger.info("Pause toggled via ArenaInputHandler ESC", "input")
	else:
		Logger.warn("Pause not allowed in current state: %s" % StateManager.get_current_state_string(), "input")

func _handle_mouse_motion() -> void:
	if not arena_ref or not melee_system:
		return
	
	var world_pos = arena_ref.get_global_mouse_position()
	melee_system.set_auto_attack_target(world_pos)

func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if not arena_ref or not player_attack_handler:
		return
	
	# Convert screen coordinates to world coordinates
	var world_pos = arena_ref.get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT:
		Logger.info("ArenaInputHandler: Left-click detected, triggering melee attack", "input")
		player_attack_handler.handle_melee_attack(world_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT and RunManager.stats.get("has_projectiles", false):
		player_attack_handler.handle_projectile_attack(world_pos)
