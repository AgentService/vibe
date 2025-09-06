extends Node2D

## Main scene that manages dynamic scene loading based on debug configuration.
## Loads either Hideout or Arena based on debug.json settings.

var current_scene: Node2D
var debug_config: Dictionary = {}

func _ready() -> void:
	Logger.info("Main scene initializing with dynamic scene loading", "main")
	_load_debug_config()
	_load_initial_scene()
	
	# Connect to combat step for debug purposes
	EventBus.combat_step.connect(_on_combat_step)

func _load_debug_config() -> void:
	var config_path: String = "res://config/debug.json"
	
	if not FileAccess.file_exists(config_path):
		Logger.warn("Debug config not found, using defaults", "main")
		debug_config = {
			"debug_mode": false,
			"start_mode": "arena",
			"map_scene": "res://scenes/arena/Arena.tscn",
			"character_id": "knight_default"
		}
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Logger.error("Failed to open debug config file", "main")
		return
		
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		Logger.error("Failed to parse debug config JSON", "main")
		return
		
	debug_config = json.data
	Logger.info("Debug config loaded: start_mode=" + str(debug_config.get("start_mode", "arena")), "main")

func _load_initial_scene() -> void:
	var start_mode = debug_config.get("start_mode", "arena")
	var scene_path: String
	
	match start_mode:
		"hideout":
			scene_path = "res://scenes/core/Hideout.tscn"
		"arena", "map", _:
			scene_path = debug_config.get("map_scene", "res://scenes/arena/Arena.tscn")
	
	Logger.info("Loading scene: " + scene_path, "main")
	_instantiate_scene(scene_path)

func _instantiate_scene(scene_path: String) -> void:
	var scene_resource = load(scene_path)
	if not scene_resource:
		Logger.error("Failed to load scene: " + scene_path, "main")
		return
	
	current_scene = scene_resource.instantiate()
	if not current_scene:
		Logger.error("Failed to instantiate scene: " + scene_path, "main")
		return
	
	add_child(current_scene)
	Logger.info("Scene loaded successfully: " + scene_path, "main")

func _on_combat_step(_payload) -> void:
	# Main scene just passes through - loaded scenes handle their own logic
	pass
