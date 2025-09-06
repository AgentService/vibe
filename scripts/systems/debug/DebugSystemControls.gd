extends Node
class_name DebugSystemControls

## Debug System Controls
## Provides system-level debugging controls and utilities

var wave_director: WaveDirector
var ai_paused: bool = false
var collision_shapes_visible: bool = false

func _ready() -> void:
	# Try to find WaveDirector reference
	wave_director = get_node_or_null("/root/WaveDirector")
	if not wave_director:
		# Try alternative paths
		var scene_tree = get_tree()
		if scene_tree and scene_tree.current_scene:
			wave_director = _find_wave_director(scene_tree.current_scene)
	
	Logger.debug("DebugSystemControls initialized", "debug")

func _exit_tree() -> void:
	Logger.debug("DebugSystemControls: Cleaned up", "debug")

func set_ai_paused(paused: bool) -> void:
	"""Pause/unpause AI for all enemies via EventBus signal"""
	ai_paused = paused
	
	# Emit cheat toggle event for AI pause
	var payload := EventBus.CheatTogglePayload_Type.new("ai_paused", paused)
	EventBus.cheat_toggled.emit(payload)
	
	Logger.info("AI paused: %s" % paused, "debug")

func set_collision_shapes_visible(visible: bool) -> void:
	"""Toggle collision shape visibility - DEPRECATED: Non-working functionality removed"""
	collision_shapes_visible = visible
	Logger.warn("Collision shape debugging functionality has been removed (non-working)", "debug")

func clear_all_entities() -> void:
	"""Clear all enemies and bosses from the scene"""
	var cleared_count = 0
	
	# Clear via WaveDirector if available
	if wave_director and wave_director.has_method("clear_all_enemies"):
		wave_director.clear_all_enemies()
		cleared_count += 1
	
	# Clear bosses from scene tree
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		cleared_count += _clear_bosses_recursive(scene_tree.current_scene)
	
	Logger.info("Cleared %d enemy groups/bosses" % cleared_count, "debug")

func reset_session() -> void:
	"""Comprehensive debug session reset - clean slate for testing scenarios"""
	Logger.info("Debug session reset initiated", "debug")
	
	# 1. Clear all entities (enemies, bosses, projectiles)
	clear_all_entities()
	
	# 2. Reset player state properly
	_reset_player_state()
	
	# 3. Reset XP and progression systems
	_reset_xp_and_progression()
	
	# 4. Reset wave and spawn systems
	_reset_wave_systems()
	
	# 5. Clear projectiles and visual effects
	_clear_projectiles_and_effects()
	
	# 6. Reset UI and session counters
	_reset_ui_and_session_data()
	
	Logger.info("Debug session reset completed - ready for testing", "debug")

# Helper methods

func _find_wave_director(node: Node) -> WaveDirector:
	if node is WaveDirector:
		return node as WaveDirector
	
	for child in node.get_children():
		var result = _find_wave_director(child)
		if result:
			return result
	
	return null

func _set_ai_paused_recursive(node: Node, paused: bool) -> void:
	# Check if node has AI that can be paused
	if node.has_method("set_ai_enabled"):
		node.set_ai_enabled(not paused)
	elif node.has_method("pause_ai"):
		node.pause_ai(paused)
	elif "ai_enabled" in node:
		node.ai_enabled = not paused
	
	# Process children
	for child in node.get_children():
		_set_ai_paused_recursive(child, paused)


func _clear_bosses_recursive(node: Node) -> int:
	var cleared = 0
	
	# Check if this node is a boss
	if node.name.contains("Boss") or node.name.contains("Lich") or node.name.contains("Dragon"):
		if node.has_method("die"):
			node.die()
		else:
			node.queue_free()
		cleared += 1
	elif node.is_in_group("bosses"):
		if node.has_method("die"):
			node.die()
		else:
			node.queue_free()
		cleared += 1
	else:
		# Process children
		for child in node.get_children():
			cleared += _clear_bosses_recursive(child)
	
	return cleared

# Comprehensive reset helper methods

func _reset_player_state() -> void:
	"""Reset player position, health, and state"""
	if PlayerState.has_player_reference():
		var player = PlayerState._player_ref
		if player:
			# Reset player position to arena center
			player.global_position = Vector2.ZERO
			Logger.debug("Reset player position to arena center", "debug")
			
			# Reset player health if methods exist
			if player.has_method("reset_health"):
				player.reset_health()
				Logger.debug("Reset player health via reset_health()", "debug")
			elif player.has_method("heal_full"):
				player.heal_full()
				Logger.debug("Reset player health via heal_full()", "debug")
			elif "current_health" in player and "max_health" in player:
				player.current_health = player.max_health
				Logger.debug("Reset player health via direct property access", "debug")
			elif "health" in player and "max_health" in player:
				player.health = player.max_health
				Logger.debug("Reset player health via health property", "debug")
		
		# Force position update in PlayerState
		PlayerState.position = Vector2.ZERO
		PlayerState._last_emitted_position = Vector2.ZERO
	else:
		Logger.warn("No player reference available for reset", "debug")

func _reset_xp_and_progression() -> void:
	"""Reset XP, levels, and progression systems"""
	# Find XP system in scene tree
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		var xp_system = _find_xp_system(scene_tree.current_scene)
		if xp_system:
			# Reset XP system state
			if "current_xp" in xp_system:
				xp_system.current_xp = 0
			if "current_level" in xp_system:
				xp_system.current_level = 1
			if xp_system.has_method("_update_next_level_xp"):
				xp_system._update_next_level_xp()
			
			Logger.debug("Reset XP system: Level 1, 0 XP", "debug")
		else:
			Logger.debug("XP system not found - skipping XP reset", "debug")

func _reset_wave_systems() -> void:
	"""Reset wave progression and spawning state"""
	if wave_director:
		# Reset wave-related state
		if "spawn_timer" in wave_director:
			wave_director.spawn_timer = 0.0
		if wave_director.has_method("reset"):
			wave_director.reset()
		
		Logger.debug("Reset wave director state", "debug")
	else:
		Logger.warn("No wave director available for reset", "debug")

func _clear_projectiles_and_effects() -> void:
	"""Clear all projectiles and visual effects"""
	var scene_tree = get_tree()
	if not scene_tree or not scene_tree.current_scene:
		return
	
	var cleared_count = 0
	
	# Clear MultiMesh projectiles
	var multimesh_nodes = _find_multimesh_projectiles(scene_tree.current_scene)
	for mm_node in multimesh_nodes:
		if mm_node.multimesh and mm_node.multimesh.instance_count > 0:
			mm_node.multimesh.instance_count = 0
			cleared_count += 1
			Logger.debug("Cleared MultiMesh projectiles: %s" % mm_node.name, "debug")
	
	# Clear visual effects nodes
	var effects_nodes = scene_tree.get_nodes_in_group("visual_effects")
	for effect in effects_nodes:
		if effect.has_method("clear_all"):
			effect.clear_all()
			cleared_count += 1
		elif effect.has_method("reset"):
			effect.reset()
			cleared_count += 1
	
	# Clear melee effects
	var melee_effects = _find_melee_effects(scene_tree.current_scene)
	if melee_effects:
		for child in melee_effects.get_children():
			child.queue_free()
		cleared_count += 1
		Logger.debug("Cleared melee effects", "debug")
	
	if cleared_count > 0:
		Logger.debug("Cleared %d projectile/effect systems" % cleared_count, "debug")

func _reset_ui_and_session_data() -> void:
	"""Reset UI counters and session statistics"""
	# Reset GameOrchestrator session data if available
	if GameOrchestrator and GameOrchestrator.has_method("reset_session_stats"):
		GameOrchestrator.reset_session_stats()
		Logger.debug("Reset GameOrchestrator session stats", "debug")
	
	# Emit session reset event for other systems to listen to
	var payload := EventBus.CheatTogglePayload_Type.new("session_reset", true)
	EventBus.cheat_toggled.emit(payload)
	Logger.debug("Emitted session_reset event for other systems", "debug")

# Helper finder methods

func _find_xp_system(node: Node):
	if node is XpSystem:
		return node
	if node.name == "XpSystem" or node.name.contains("XP"):
		return node
	
	for child in node.get_children():
		var result = _find_xp_system(child)
		if result:
			return result
	return null

func _find_multimesh_projectiles(node: Node) -> Array[MultiMeshInstance2D]:
	var result: Array[MultiMeshInstance2D] = []
	
	if node is MultiMeshInstance2D:
		var mm_node = node as MultiMeshInstance2D
		# Check if it's a projectile MultiMesh by name
		if mm_node.name.to_lower().contains("projectile") or mm_node.name.contains("MM_Projectiles"):
			result.append(mm_node)
	
	for child in node.get_children():
		var child_results = _find_multimesh_projectiles(child)
		result.append_array(child_results)
	
	return result

func _find_melee_effects(node: Node) -> Node2D:
	if node.name == "MeleeEffects":
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_melee_effects(child)
		if result:
			return result
	
	return null