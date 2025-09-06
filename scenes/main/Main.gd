extends Node2D

## Main scene that manages dynamic scene loading based on debug configuration.
## Loads either Hideout or Arena based on debug.tres settings.

var current_scene: Node2D
var debug_config: DebugConfig

func _ready() -> void:
	Logger.info("Main scene initializing with dynamic scene loading", "main")
	_load_debug_config()
	_load_initial_scene()
	
	# Connect to combat step for debug purposes
	EventBus.combat_step.connect(_on_combat_step)

func _load_debug_config() -> void:
	var config_path: String = "res://config/debug.tres"
	
	if not ResourceLoader.exists(config_path):
		Logger.warn("Debug config not found, creating default", "main")
		debug_config = DebugConfig.new()
		return
	
	debug_config = load(config_path) as DebugConfig
	if not debug_config:
		Logger.error("Failed to load debug config resource, using default", "main")
		debug_config = DebugConfig.new()
		return
		
	Logger.info("Debug config loaded: start_mode=" + debug_config.start_mode, "main")

func _load_initial_scene() -> void:
	var scene_path: String
	
	match debug_config.start_mode:
		"hideout":
			scene_path = "res://scenes/core/Hideout.tscn"
		"arena", "map", _:
			scene_path = debug_config.map_scene
	
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
