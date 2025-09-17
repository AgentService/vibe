extends Node
class_name PlayerSpawner

## PlayerSpawner system for unified player instantiation and positioning.
## Handles spawning the player at specified spawn points across different scenes.
## Used by both Hideout and Arena to maintain consistent player setup.

# Character scene paths
const PLAYER_SCENES: Dictionary = {
	"Knight": "res://scenes/arena/Player.tscn",
	"Ranger": "res://scenes/arena/PlayerRanger.tscn"
}
const DEFAULT_PLAYER_SCENE: String = "res://scenes/arena/Player.tscn"

var player_instance: Node2D

## Get the correct player scene path based on character class
func _get_player_scene_path() -> String:
	var current_profile := CharacterManager.get_current()
	if not current_profile:
		Logger.warn("No current character profile found, using default player scene", "spawner")
		return DEFAULT_PLAYER_SCENE
	
	var character_class := str(current_profile.clazz)
	var scene_path: String = PLAYER_SCENES.get(character_class, DEFAULT_PLAYER_SCENE)
	
	Logger.info("Using player scene: %s for class: %s" % [scene_path, character_class], "spawner")
	return scene_path

func spawn_player(spawn_point_id: String, parent_node: Node2D) -> Node2D:
	"""
	Spawns the player at the specified spawn point.
	
	Args:
		spawn_point_id: Name or identifier of the spawn point (Marker2D)
		parent_node: The scene node that contains the spawn points
	
	Returns:
		The instantiated player node, or null if spawn failed
	"""
	
	Logger.info("Spawning player at spawn point: " + spawn_point_id, "spawner")
	
	# Find the spawn point
	var spawn_point: Marker2D = _find_spawn_point(spawn_point_id, parent_node)
	if not spawn_point:
		Logger.error("Spawn point not found: " + spawn_point_id, "spawner")
		return null
	
	# Load and instantiate player using character-specific scene
	var scene_path: String = _get_player_scene_path()
	var player_scene = load(scene_path)
	if not player_scene:
		Logger.error("Failed to load player scene: " + scene_path, "spawner")
		return null
	
	player_instance = player_scene.instantiate()
	if not player_instance:
		Logger.error("Failed to instantiate player scene", "spawner")
		return null
	
	# Position player at spawn point
	player_instance.global_position = spawn_point.global_position
	
	# Add player to scene
	parent_node.add_child(player_instance)

	Logger.info("Player spawned successfully at position: " + str(spawn_point.global_position), "spawner")

	# Emit spawn event for other systems
	EventBus.player_position_changed.emit({
		"position": player_instance.global_position,
		"spawn_point_id": spawn_point_id
	})

	return player_instance

func _find_spawn_point(spawn_point_id: String, parent_node: Node2D) -> Marker2D:
	"""
	Finds a spawn point by name within the parent node.
	Searches both direct children and nested children.
	"""
	
	# First check direct children
	var spawn_point = parent_node.get_node_or_null(spawn_point_id)
	if spawn_point and spawn_point is Marker2D:
		return spawn_point
	
	# Search all children recursively
	var found_marker = _search_children_for_marker(parent_node, spawn_point_id)
	if found_marker:
		return found_marker
	
	Logger.warn("Spawn point not found: " + spawn_point_id + " in scene", "spawner")
	return null

func _search_children_for_marker(node: Node, target_name: String) -> Marker2D:
	"""Recursively search for a Marker2D with the target name."""
	
	for child in node.get_children():
		if child.name == target_name and child is Marker2D:
			return child
		
		# Recursively search child nodes
		var result = _search_children_for_marker(child, target_name)
		if result:
			return result
	
	return null

func get_player_instance() -> Node2D:
	"""Returns the current player instance, or null if no player spawned."""
	return player_instance

func is_player_spawned() -> bool:
	"""Returns true if player has been spawned and is valid."""
	return player_instance != null and is_instance_valid(player_instance)

func spawn_at(root: Node, spawn_name: String) -> Node2D:
	"""
	Phase 0 API - Spawns player at specified spawn point using deferred spawn to avoid race.
	This is the new API contract as specified in the Hideout Phase 0 task.
	
	Args:
		root: The root node containing the spawn point
		spawn_name: Name of the spawn marker (e.g. "spawn_hideout_main")
		
	Returns:
		The player instance or null if spawn failed
	"""
	
	var marker := root.get_node_or_null(spawn_name)
	if marker == null:
		Logger.error("Spawn marker not found: %s" % spawn_name, "PlayerSpawner")
		return null
	
	# Load player scene using character-specific path
	var scene_path: String = _get_player_scene_path()
	var player_scene = load(scene_path)
	if not player_scene:
		Logger.error("Failed to load player scene: " + scene_path, "PlayerSpawner")
		return null
	
	var player: Node2D = player_scene.instantiate()
	if not player:
		Logger.error("Failed to instantiate player scene", "PlayerSpawner")
		return null
	
	# Use deferred spawn to avoid race conditions
	call_deferred("_finalize_spawn", root, player, marker)
	player_instance = player
	return player

func _finalize_spawn(root: Node, player: Node2D, marker: Node) -> void:
	"""Finalize spawn placement - called deferred to avoid timing issues."""

	if not is_instance_valid(player) or not is_instance_valid(marker):
		Logger.error("Invalid player or marker during finalize spawn", "PlayerSpawner")
		return

	player.global_position = (marker as Node2D).global_position
	root.add_child(player)

	Logger.info("Player spawned at deferred position: " + str(player.global_position), "PlayerSpawner")
