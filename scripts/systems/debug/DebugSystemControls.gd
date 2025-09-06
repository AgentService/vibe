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
	"""Toggle collision shape visibility"""
	collision_shapes_visible = visible
	
	# Apply to current scene
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		_set_collision_visible_recursive(scene_tree.current_scene, visible)
	
	Logger.info("Collision shapes visible: %s" % visible, "debug")

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
	"""Reset the current game session"""
	# Clear all entities first
	clear_all_entities()
	
	# Reset player if accessible
	var player = get_node_or_null("/root/Player")
	if player and player.has_method("reset_stats"):
		player.reset_stats()
	
	# Reset wave director
	if wave_director and wave_director.has_method("reset"):
		wave_director.reset()
	
	Logger.info("Session reset completed", "debug")

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

func _set_collision_visible_recursive(node: Node, visible: bool) -> void:
	# Toggle collision shape visibility
	if node is CollisionShape2D:
		var collision = node as CollisionShape2D
		collision.debug_color = Color.RED if visible else Color.TRANSPARENT
	elif node is Area2D:
		var area = node as Area2D
		for child in area.get_children():
			if child is CollisionShape2D:
				var collision = child as CollisionShape2D
				collision.debug_color = Color.BLUE if visible else Color.TRANSPARENT
	
	# Process children
	for child in node.get_children():
		_set_collision_visible_recursive(child, visible)

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