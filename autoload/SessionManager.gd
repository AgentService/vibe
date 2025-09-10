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
	var reason_text = _reason_to_string(reason)
	Logger.debug("Starting reset sequence for: %s" % reason_text, "session")
	
	# Step 1: Clear all entities (enemies, bosses, projectiles) - but not for player death
	Logger.debug("Reset step 1: Clearing entities", "session")
	_clear_entities()
	entities_cleared.emit()
	
	# Wait for entity clearing to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Step 2: Reset systems FIRST (before player) to ensure clean state
	Logger.debug("Reset step 2: Resetting systems", "session")
	_reset_systems(reason, context)
	systems_reset.emit()
	
	# Wait for systems to settle
	await get_tree().process_frame
	
	# Step 3: Reset player state (after systems are clean)
	Logger.debug("Reset step 3: Resetting player", "session")
	await _reset_player_state(reason, context)
	player_reset.emit()
	
	# Step 4: Validate player registration after all resets
	Logger.debug("Reset step 4: Validating player registration", "session")
	await _validate_player_registration_post_reset()
	
	# Step 5: Reset progression/XP based on context
	if not context.get("preserve_progression", false):
		Logger.debug("Reset step 5: Resetting progression", "session")
		_reset_progression(reason, context)
	
	# Step 6: Clear temporary visual effects (preserve permanent nodes)
	Logger.debug("Reset step 6: Clearing temporary effects", "session")
	_clear_temporary_effects()
	
	# Step 7: Reset UI state
	Logger.debug("Reset step 7: Resetting UI", "session")
	_reset_ui_state(reason, context)
	
	# Wait one more frame for everything to settle
	await get_tree().process_frame
	
	Logger.debug("Reset sequence complete for: %s" % reason_text, "session")

func _validate_player_registration_post_reset() -> void:
	"""Final validation that player is properly registered after reset"""
	if not PlayerState.has_player_reference():
		Logger.warn("No player reference for post-reset validation", "session")
		return
	
	var player = PlayerState._player_ref
	if not player:
		Logger.warn("Invalid player reference for post-reset validation", "session")
		return
	
	var is_registered = false
	if player.has_method("is_registered_with_damage_system"):
		is_registered = player.is_registered_with_damage_system()
	else:
		is_registered = DamageService.is_entity_alive("player") and EntityTracker.is_entity_alive("player")
	
	if not is_registered:
		Logger.error("CRITICAL: Player not registered after reset - attempting emergency registration", "session")
		if player.has_method("ensure_damage_registration"):
			var success = player.ensure_damage_registration()
			Logger.info("Emergency registration result: %s" % success, "session")
		else:
			Logger.error("Player missing ensure_damage_registration method!", "session")
	else:
		Logger.info("Player registration validated successfully after reset", "session")

func _clear_entities() -> void:
	"""Clear all entities using the unified damage-based system"""
	Logger.warn("🔴 SessionManager._clear_entities() called - this should not happen during player death!", "session")
	
	# Check if this is a player death scenario - if so, skip entity clearing to preserve enemies for results screen
	if _is_player_death_scenario():
		Logger.info("Skipping entity clearing for player death scenario - enemies preserved for results", "session")
		return
	
	if DebugManager and DebugManager.has_method("clear_all_entities"):
		Logger.debug("Clearing all entities via DebugManager", "session")
		DebugManager.clear_all_entities()
	else:
		Logger.warn("DebugManager.clear_all_entities not available", "session")

func _is_player_death_scenario() -> bool:
	"""Check if current reset is due to player death rather than debug reset"""
	# This is a simple heuristic - in the future we could pass more context
	# For now, if the player is dead/dying, this is likely a death reset
	if not PlayerState.has_player_reference():
		return false
	
	var player = PlayerState._player_ref
	if not player:
		return false
	
	# Check if player health is 0 or if player is in death state
	var current_hp = player.get_health() if player.has_method("get_health") else 100
	return current_hp <= 0

func _reset_player_state(reason: ResetReason, context: Dictionary) -> void:
	"""Reset player position, health, and state"""
	Logger.debug("Starting player state reset for reason: %s" % _reason_to_string(reason), "session")
	
	if not PlayerState.has_player_reference():
		Logger.warn("No player reference available for reset", "session")
		return
	
	var player = PlayerState._player_ref
	if not player:
		Logger.warn("Player reference is invalid", "session")
		return
	
	Logger.debug("Player reference valid - proceeding with reset", "session")
	
	# Reset player position (only for respawn scenarios, not hideout returns)
	if reason != ResetReason.HIDEOUT_RETURN:
		var spawn_pos = context.get("spawn_position", Vector2.ZERO)
		player.global_position = spawn_pos
		Logger.debug("Reset player position to %s" % spawn_pos, "session")
	else:
		Logger.debug("Hideout return - preserving player position: %s" % player.global_position, "session")
	
	# Reset player health
	if player.has_method("reset_health"):
		player.reset_health()
		Logger.debug("Player health reset via reset_health()", "session")
	elif player.has_method("heal_full"):
		player.heal_full()
		Logger.debug("Player health reset via heal_full()", "session")
	else:
		Logger.warn("Player has no health reset method available", "session")
	
	# Reset player velocity/movement
	if player.has_method("stop_movement"):
		player.stop_movement()
	elif "velocity" in player:
		player.velocity = Vector2.ZERO
	
	# CRITICAL: Ensure player is registered with damage systems after reset
	Logger.debug("Starting player damage system re-registration", "session")
	
	if not player.has_method("_register_with_damage_system"):
		Logger.error("CRITICAL: Player missing _register_with_damage_system method!", "session")
		return
	
	# Check if player is already properly registered
	if player.has_method("is_registered_with_damage_system") and player.is_registered_with_damage_system():
		Logger.info("Player already properly registered - skipping re-registration", "session")
	else:
		Logger.debug("Player not registered or partially registered - performing registration", "session")
		player._register_with_damage_system()
		
		# Wait a frame to ensure registration is processed
		await get_tree().process_frame
		
		# Verify registration was successful with retry
		var registration_success = false
		for retry in range(3):  # Try up to 3 times
			if player.has_method("is_registered_with_damage_system"):
				registration_success = player.is_registered_with_damage_system()
			else:
				# Fallback: direct check if newer method not available
				registration_success = DamageService.is_entity_alive("player") and EntityTracker.is_entity_alive("player")
			
			if registration_success:
				Logger.info("Player damage system registration verified - SUCCESS (attempt %d)" % (retry + 1), "session")
				break
			else:
				Logger.warn("Player registration verification failed - attempt %d/3" % (retry + 1), "session")
				if retry < 2:  # Don't re-register on final attempt
					player._register_with_damage_system()
					await get_tree().process_frame
		
		if not registration_success:
			Logger.error("CRITICAL: Player damage system registration FAILED after 3 attempts!", "session")
			Logger.error("DamageService alive: %s, EntityTracker alive: %s" % [DamageService.is_entity_alive("player"), EntityTracker.is_entity_alive("player")], "session")
	
	Logger.debug("Player state reset complete", "session")

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

func _clear_temporary_effects() -> void:
	"""Clear temporary visual effects while preserving permanent visual nodes like MeleeCone"""
	var scene_tree = get_tree()
	if not scene_tree or not scene_tree.current_scene:
		return
	
	var cleared_count = 0
	
	# Clear MultiMesh projectiles (always temporary)
	var multimesh_nodes = _find_multimesh_projectiles(scene_tree.current_scene)
	for mm_node in multimesh_nodes:
		if mm_node.multimesh and mm_node.multimesh.instance_count > 0:
			mm_node.multimesh.instance_count = 0
			cleared_count += 1
			Logger.debug("Cleared MultiMesh projectiles: %s" % mm_node.name, "session")
	
	# Clear visual effects group (temporary effects only)
	var effects_nodes = scene_tree.get_nodes_in_group("visual_effects")
	for effect in effects_nodes:
		if effect.has_method("clear_all"):
			effect.clear_all()
			cleared_count += 1
		elif effect.has_method("reset"):
			effect.reset()
			cleared_count += 1
	
	# Clear temporary melee effects but preserve permanent visual nodes
	var melee_effects = _find_melee_effects(scene_tree.current_scene)
	if melee_effects:
		for child in melee_effects.get_children():
			# Only clear temporary effects, preserve permanent visual nodes like MeleeCone
			if _is_temporary_effect_node(child):
				child.queue_free()
				cleared_count += 1
				Logger.debug("Cleared temporary melee effect: %s" % child.name, "session")
	
	if cleared_count > 0:
		Logger.debug("Cleared %d temporary effect systems" % cleared_count, "session")

func _is_temporary_effect_node(node: Node) -> bool:
	"""Determine if a node is a temporary effect that should be cleared during reset"""
	var node_name = node.name.to_lower()
	
	# Preserve permanent visual nodes
	if node_name.contains("meleecone") or node_name.contains("cone"):
		return false
	
	# Clear temporary effect nodes (projectiles, particles, etc.)
	if node_name.contains("projectile") or node_name.contains("particle") or node_name.contains("temp"):
		return true
	
	# Default: preserve nodes unless explicitly temporary
	return false

func _find_multimesh_projectiles(node: Node) -> Array[MultiMeshInstance2D]:
	"""Find MultiMesh projectile nodes for clearing"""
	var result: Array[MultiMeshInstance2D] = []
	
	if node is MultiMeshInstance2D:
		var mm_node = node as MultiMeshInstance2D
		if mm_node.name.to_lower().contains("projectile") or mm_node.name.contains("MM_Projectiles"):
			result.append(mm_node)
	
	for child in node.get_children():
		var child_results = _find_multimesh_projectiles(child)
		result.append_array(child_results)
	
	return result

func _find_melee_effects(node: Node) -> Node2D:
	"""Find the MeleeEffects node in the scene tree"""
	if node.name == "MeleeEffects":
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_melee_effects(child)
		if result:
			return result
	
	return null

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