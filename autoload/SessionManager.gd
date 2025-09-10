extends Node

## Centralized Session Management System
## Handles all session resets for multiple scenarios: death, debug reset, map transitions, hideout returns
## Provides unified reset API that other systems can listen to and extend

# Session states
enum ResetReason {
	DEBUG_RESET,      # Manual debug reset button
	PLAYER_DEATH,     # Player died
	MAP_TRANSITION,   # Moving between maps/arenas
	HIDEOUT_RETURN,   # Returning to hideout
	RUN_END,          # Run completed/ended
	LEVEL_RESTART     # Restart same level
}

# Typed signals for session events
signal session_reset_started(reason: ResetReason, context: Dictionary)
signal session_reset_completed(reason: ResetReason, duration_ms: float)
signal entities_cleared()
signal player_reset()
signal systems_reset()

# State tracking
var _reset_in_progress: bool = false
var _reset_start_time: float = 0.0

func _ready() -> void:
	Logger.info("SessionManager initialized", "session")

## PUBLIC API - Session Reset Methods

func reset_session(reason: ResetReason, context: Dictionary = {}) -> void:
	"""Perform comprehensive session reset with specified reason and context"""
	if _reset_in_progress:
		Logger.warn("Session reset already in progress, ignoring duplicate request", "session")
		return
		
	_reset_in_progress = true
	_reset_start_time = Time.get_ticks_msec()
	
	var reason_text = _reason_to_string(reason)
	Logger.info("Session reset started - reason: %s" % reason_text, "session")
	
	# Emit session reset started event
	session_reset_started.emit(reason, context)
	
	# Perform reset steps in order
	await _perform_reset_sequence(reason, context)
	
	# Calculate reset duration
	var duration_ms = Time.get_ticks_msec() - _reset_start_time
	_reset_in_progress = false
	
	Logger.info("Session reset completed - reason: %s, duration: %.1fms" % [reason_text, duration_ms], "session")
	session_reset_completed.emit(reason, duration_ms)

func reset_debug() -> void:
	"""Quick debug reset - used by debug panel reset button"""
	await reset_session(ResetReason.DEBUG_RESET, {"source": "debug_panel"})

func reset_player_death() -> void:
	"""Reset after player death - preserve some state, clear enemies"""
	await reset_session(ResetReason.PLAYER_DEATH, {"preserve_progression": true})

func reset_map_transition(from_map: String, to_map: String) -> void:
	"""Reset for map transition - preserve progression, clear map-specific state"""
	await reset_session(ResetReason.MAP_TRANSITION, {
		"from_map": from_map,
		"to_map": to_map,
		"preserve_progression": true
	})

func reset_hideout_return() -> void:
	"""Reset when returning to hideout - preserve character data"""
	await reset_session(ResetReason.HIDEOUT_RETURN, {"preserve_character": true})

func is_reset_in_progress() -> bool:
	"""Check if a reset is currently being processed"""
	return _reset_in_progress

## INTERNAL IMPLEMENTATION

func _perform_reset_sequence(reason: ResetReason, context: Dictionary) -> void:
	"""Execute the complete reset sequence"""
	
	# Step 1: Clear all entities (enemies, bosses, projectiles)
	Logger.debug("Reset step 1: Clearing entities", "session")
	_clear_entities()
	entities_cleared.emit()
	
	# Wait for entity clearing to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Step 2: Reset player state
	Logger.debug("Reset step 2: Resetting player", "session")
	_reset_player_state(reason, context)
	player_reset.emit()
	
	# Step 3: Reset systems based on reason
	Logger.debug("Reset step 3: Resetting systems", "session")
	_reset_systems(reason, context)
	systems_reset.emit()
	
	# Step 4: Reset progression/XP based on context
	if not context.get("preserve_progression", false):
		Logger.debug("Reset step 4: Resetting progression", "session")
		_reset_progression(reason, context)
	
	# Step 5: Reset UI state
	Logger.debug("Reset step 5: Resetting UI", "session")
	_reset_ui_state(reason, context)
	
	# Wait one more frame for everything to settle
	await get_tree().process_frame

func _clear_entities() -> void:
	"""Clear all entities using the unified damage-based system"""
	if DebugManager and DebugManager.has_method("clear_all_entities"):
		DebugManager.clear_all_entities()
	else:
		Logger.warn("DebugManager.clear_all_entities not available", "session")

func _reset_player_state(reason: ResetReason, context: Dictionary) -> void:
	"""Reset player position, health, and state"""
	if not PlayerState.has_player_reference():
		Logger.warn("No player reference available for reset", "session")
		return
	
	var player = PlayerState._player_ref
	if not player:
		Logger.warn("Player reference is invalid", "session")
		return
	
	# Reset player position to spawn point or arena center
	var spawn_pos = context.get("spawn_position", Vector2.ZERO)
	player.global_position = spawn_pos
	Logger.debug("Reset player position to %s" % spawn_pos, "session")
	
	# Reset player health
	if player.has_method("reset_health"):
		player.reset_health()
	elif player.has_method("heal_full"):
		player.heal_full()
	else:
		Logger.warn("Player has no health reset method available", "session")
	
	# Reset player velocity/movement
	if player.has_method("stop_movement"):
		player.stop_movement()
	elif "velocity" in player:
		player.velocity = Vector2.ZERO

func _reset_systems(reason: ResetReason, context: Dictionary) -> void:
	"""Reset various game systems based on the reset reason"""
	
	# Reset wave director
	var wave_director = get_node_or_null("/root/WaveDirector")
	if wave_director and wave_director.has_method("reset"):
		wave_director.reset()
		Logger.debug("WaveDirector reset", "session")
	
	# Reset XP system (conditionally)
	if not context.get("preserve_progression", false):
		if PlayerProgression and PlayerProgression.has_method("reset_session"):
			PlayerProgression.reset_session()
			Logger.debug("PlayerProgression reset", "session")
	
	# Reset ability cooldowns
	# TODO: Add ability system reset when implemented
	
	# Reset any timers or temporary effects
	# TODO: Add effect system reset when implemented

func _reset_progression(reason: ResetReason, context: Dictionary) -> void:
	"""Reset XP, level, and progression state"""
	if PlayerProgression:
		if PlayerProgression.has_method("reset_to_level_1"):
			PlayerProgression.reset_to_level_1()
			Logger.debug("Player progression reset to level 1", "session")
		elif PlayerProgression.has_method("reset"):
			PlayerProgression.reset()
			Logger.debug("Player progression reset", "session")

func _reset_ui_state(reason: ResetReason, context: Dictionary) -> void:
	"""Reset UI elements and overlays"""
	# Reset any temporary UI states, dialog boxes, etc.
	# This could include closing modal dialogs, resetting HUD states, etc.
	
	# Emit event for UI systems to listen to
	EventBus.session_ui_reset.emit({"reason": reason, "context": context})

func _reason_to_string(reason: ResetReason) -> String:
	"""Convert reset reason enum to readable string"""
	match reason:
		ResetReason.DEBUG_RESET:
			return "Debug Reset"
		ResetReason.PLAYER_DEATH:
			return "Player Death"
		ResetReason.MAP_TRANSITION:
			return "Map Transition"
		ResetReason.HIDEOUT_RETURN:
			return "Hideout Return"
		ResetReason.RUN_END:
			return "Run End"
		ResetReason.LEVEL_RESTART:
			return "Level Restart"
		_:
			return "Unknown"

## CONSOLE COMMANDS

func cmd_reset_session(reason: String = "debug") -> void:
	"""Console command to trigger session reset"""
	var reset_reason = ResetReason.DEBUG_RESET
	match reason.to_lower():
		"death":
			reset_reason = ResetReason.PLAYER_DEATH
		"transition", "map":
			reset_reason = ResetReason.MAP_TRANSITION
		"hideout":
			reset_reason = ResetReason.HIDEOUT_RETURN
		"debug", _:
			reset_reason = ResetReason.DEBUG_RESET
	
	await reset_session(reset_reason, {"source": "console"})
	Logger.info("Console session reset completed", "session")