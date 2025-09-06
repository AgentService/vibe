extends Node
class_name SceneTransitionManager

## SceneTransitionManager handles scene loading/unloading and transitions.
## Listens to EventBus for transition requests and manages the flow between scenes.
## Supports data passing between scenes (spawn points, character state, etc.)

signal transition_started(from_scene: String, to_scene: String)
signal transition_completed(scene_name: String)

var current_scene_node: Node
var transition_data: Dictionary = {}

func _ready() -> void:
	Logger.info("SceneTransitionManager initialized", "transition")
	
	# Connect to EventBus signals for scene transitions
	EventBus.request_enter_map.connect(_on_request_enter_map)
	EventBus.request_return_hideout.connect(_on_request_return_hideout)

func _on_request_enter_map(data: Dictionary) -> void:
	"""
	Handles requests to enter a map/arena from the hideout.
	
	Args:
		data: {
			"map_id": String,           # Map identifier
			"spawn_point": String,      # Optional spawn point override
			"character_data": Dictionary # Optional character state
		}
	"""
	Logger.info("Map entry requested: " + str(data.get("map_id", "default")), "transition")
	
	var map_scene_path = _resolve_map_path(data.get("map_id", "arena"))
	transition_data = data
	
	transition_to_scene(map_scene_path, "map")

func _on_request_return_hideout(data: Dictionary = {}) -> void:
	"""
	Handles requests to return to hideout from any scene.
	
	Args:
		data: {
			"spawn_point": String,      # Optional spawn point in hideout
			"character_data": Dictionary # Character state to preserve
		}
	"""
	Logger.info("Hideout return requested", "transition")
	
	transition_data = data
	transition_to_scene("res://scenes/core/Hideout.tscn", "hideout")

func transition_to_scene(scene_path: String, scene_type: String) -> void:
	"""
	Performs the actual scene transition.
	
	Args:
		scene_path: Full path to the scene file
		scene_type: Type identifier for logging ("map", "hideout", etc.)
	"""
	var current_scene_name = _get_current_scene_name()
	Logger.info("Starting transition: " + current_scene_name + " → " + scene_type, "transition")
	
	transition_started.emit(current_scene_name, scene_type)
	
	# Load new scene
	var new_scene = load(scene_path)
	if not new_scene:
		Logger.error("Failed to load scene: " + scene_path, "transition")
		return
	
	# Remove current scene
	if current_scene_node:
		Logger.debug("Removing current scene: " + current_scene_node.name, "transition")
		
		# Call teardown method if it exists
		if current_scene_node.has_method("on_teardown"):
			current_scene_node.on_teardown()
			Logger.debug("SceneTransitionManager: Called teardown on " + current_scene_node.name, "transition")
		
		current_scene_node.queue_free()
		current_scene_node = null
	
	# Instantiate and add new scene
	current_scene_node = new_scene.instantiate()
	if not current_scene_node:
		Logger.error("Failed to instantiate scene: " + scene_path, "transition")
		return
	
	# Get parent (should be Main)
	var main_node = get_parent()
	main_node.add_child(current_scene_node)
	
	# Update Main's current_scene reference if it exists
	if main_node.has_method("_on_scene_transitioned"):
		main_node._on_scene_transitioned(current_scene_node)
	
	Logger.info("Scene transition completed: " + scene_type, "transition")
	transition_completed.emit(scene_type)
	
	# Apply any transition data (spawn points, character state, etc.)
	_apply_transition_data()

func _resolve_map_path(map_id: String) -> String:
	"""
	Resolves map ID to scene path.
	
	Args:
		map_id: Map identifier ("arena", "hideout", "main_menu", etc.)
	
	Returns:
		Full scene path
	"""
	match map_id:
		"arena", "default":
			return "res://scenes/arena/Arena.tscn"
		"hideout":
			return "res://scenes/core/Hideout.tscn"
		"main_menu":
			return "res://scenes/ui/MainMenu.tscn"
		"character_select":
			return "res://scenes/ui/CharacterSelect.tscn"
		"forest":
			return "res://scenes/maps/Forest.tscn"  # Future maps
		"dungeon":
			return "res://scenes/maps/Dungeon.tscn"  # Future maps
		_:
			Logger.warn("Unknown map_id: " + map_id + ", defaulting to arena", "transition")
			return "res://scenes/arena/Arena.tscn"

func _apply_transition_data() -> void:
	"""
	Applies transition data to the newly loaded scene.
	This includes spawn points, character state, etc.
	"""
	if transition_data.is_empty():
		return
	
	Logger.debug("Applying transition data: " + str(transition_data), "transition")
	
	# Apply spawn point if specified
	var spawn_point = transition_data.get("spawn_point", "")
	if spawn_point != "" and current_scene_node.has_method("set_spawn_override"):
		current_scene_node.set_spawn_override(spawn_point)
	
	# Apply character data if specified
	var character_data = transition_data.get("character_data", {})
	if not character_data.is_empty() and current_scene_node.has_method("apply_character_data"):
		current_scene_node.apply_character_data(character_data)
	
	# Clear transition data
	transition_data.clear()

func _get_current_scene_name() -> String:
	"""Returns the name of the current scene for logging."""
	if current_scene_node:
		return current_scene_node.name
	return "none"

func get_current_scene() -> Node:
	"""Returns reference to the current scene node."""
	return current_scene_node

func set_current_scene(scene_node: Node) -> void:
	"""Sets the current scene reference (called by Main on initial load)."""
	current_scene_node = scene_node
