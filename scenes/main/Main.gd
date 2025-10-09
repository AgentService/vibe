extends Control

## Main scene that manages dynamic scene loading and transitions.
## Supports both debug config initial loading and runtime scene transitions via SceneTransitionManager.

const SceneTransitionManagerScript = preload("res://scripts/systems/arena/SceneTransitionManager.gd")

var current_scene: Node
var debug_config: DebugConfig
var scene_transition_manager: SceneTransitionManagerScript

func _ready() -> void:
	# FPS limiting now handled by FPSLimiter autoload
	# Default is 60 FPS cap (configurable via FPSLimiter.set_fps_mode())

	Logger.info("Main scene initializing with dynamic scene loading", "main")
	_setup_scene_transition_manager()
	_load_debug_config()
	_setup_initial_state()

	# Connect to combat step for debug purposes
	EventBus.combat_step.connect(_on_combat_step)

func _setup_scene_transition_manager() -> void:
	"""Initialize the scene transition manager for runtime scene changes."""
	
	scene_transition_manager = SceneTransitionManagerScript.new()
	add_child(scene_transition_manager)
	
	# Connect transition signals for logging and coordination
	scene_transition_manager.transition_started.connect(_on_transition_started)
	scene_transition_manager.transition_completed.connect(_on_transition_completed)
	
	Logger.info("SceneTransitionManager initialized", "main")


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

func _setup_initial_state() -> void:
	"""Setup initial state through StateManager based on debug config."""
	
	# Check if we should skip main menu for development
	if debug_config.skip_main_menu or (debug_config.start_mode != "menu"):
		# TODO: New progression - Character loading removed (will use MetaProgression)

		match debug_config.start_mode:
			"menu":
				if debug_config.skip_main_menu:
					Logger.info("Skipping main menu - going directly to hideout for development", "main")
					StateManager.go_to_hideout({"source": "debug_skip_menu"})
				else:
					StateManager.go_to_menu({"source": "debug_menu"})
			"hideout":
				StateManager.go_to_hideout({"source": "debug_hideout"})
			"arena", "map", _:
				var arena_id = StringName("arena")
				StateManager.start_run(arena_id, {"source": "debug_arena"})
	else:
		StateManager.go_to_menu({"source": "normal_boot"})
	
	Logger.info("Initial state setup complete via StateManager", "main")

# TODO: New progression - Removed _load_debug_character() function
# Character loading will be handled by MetaProgression system (Task 04)

# NOTE: Initial scene loading now handled by StateManager + GameOrchestrator + SceneTransitionManager

func _on_transition_started(from_scene: String, to_scene: String) -> void:
	"""Called when scene transition begins."""
	Logger.info("Scene transition started: " + from_scene + " → " + to_scene, "main")

func _on_transition_completed(scene_name: String) -> void:
	"""Called when scene transition completes."""
	Logger.info("Scene transition completed: " + scene_name, "main")
	
	# Update current scene reference
	current_scene = scene_transition_manager.get_current_scene()

func _on_scene_transitioned(new_scene: Node) -> void:
	"""Called by SceneTransitionManager to update Main's scene reference."""
	current_scene = new_scene

func _on_combat_step(_payload) -> void:
	# Main scene just passes through - loaded scenes handle their own logic
	pass
