extends Node
class_name DebugSystemControls

## Debug System Controls
## Provides system-level debugging controls and utilities

var spawn_director: SpawnDirector
var ai_paused: bool = false
var collision_shapes_visible: bool = false

func _ready() -> void:
	# Check debug configuration to see if panels should be disabled
	var config_path: String = "res://config/debug.tres"
	if ResourceLoader.exists(config_path):
		var debug_config: DebugConfig = load(config_path) as DebugConfig
		if debug_config and not debug_config.debug_panels_enabled:
			Logger.info("DebugSystemControls disabled via debug.tres configuration", "debug")
			queue_free()  # Remove the entire node
			return
	
	# Try to find SpawnDirector reference
	spawn_director = get_node_or_null("/root/SpawnDirector")
	if not spawn_director:
		# Try alternative paths
		var scene_tree = get_tree()
		if scene_tree and scene_tree.current_scene:
			spawn_director = _find_spawn_director(scene_tree.current_scene)
	
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

func is_ai_paused() -> bool:
	"""Get current AI pause state"""
	return ai_paused

func set_collision_shapes_visible(visible: bool) -> void:
	"""Toggle collision shape visibility - DEPRECATED: Non-working functionality removed"""
	collision_shapes_visible = visible
	Logger.warn("Collision shape debugging functionality has been removed (non-working)", "debug")

func clear_all_entities() -> void:
	"""Clear all enemies and bosses from the scene"""
	var cleared_count = 0
	
	# Clear via WaveDirector if available
	if spawn_director and spawn_director.has_method("clear_all_enemies"):
		spawn_director.clear_all_enemies()
		cleared_count += 1
	
	# Clear bosses from scene tree
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		cleared_count += _clear_bosses_recursive(scene_tree.current_scene)
	
	Logger.info("Cleared %d enemy groups/bosses" % cleared_count, "debug")

func reset_session() -> void:
	"""Comprehensive debug session reset - delegates to SessionManager"""
	Logger.info("Debug session reset initiated (delegating to SessionManager)", "debug")
	
	# Use centralized SessionManager for unified reset handling
	if SessionManager:
		await SessionManager.reset_debug()
		Logger.info("Debug session reset completed via SessionManager", "debug")
	else:
		Logger.error("SessionManager not available - cannot perform reset", "debug")


# Helper methods

func _find_spawn_director(node: Node) -> SpawnDirector:
	if node is SpawnDirector:
		return node as SpawnDirector
	
	for child in node.get_children():
		var result = _find_spawn_director(child)
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
