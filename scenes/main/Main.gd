extends Node2D

## Main scene that manages dynamic scene loading and transitions.
## Supports both debug config initial loading and runtime scene transitions via SceneTransitionManager.

const SceneTransitionManagerScript = preload("res://scripts/systems/SceneTransitionManager.gd")

var current_scene: Node
var debug_config: DebugConfig
var scene_transition_manager: SceneTransitionManagerScript

func _ready() -> void:
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
		# Load character profile for debug mode
		_load_debug_character()
		
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

func _load_debug_character() -> void:
	"""Load character profile for debug mode when skipping menu."""
	if not CharacterManager:
		Logger.error("CharacterManager not available for debug character loading", "main")
		return
	
	var debug_character_id = debug_config.get_debug_character_id()
	
	if debug_character_id.is_empty():
		# Auto-load the most recently played character instead of creating new one
		Logger.info("Loading most recently played character for debug mode", "main")
		var characters = CharacterManager.list_characters()
		
		if characters.size() > 0:
			# Characters are already sorted by last_played (most recent first) in CharacterManager
			var most_recent_character = characters[0]
			CharacterManager.load_character(most_recent_character.id)
			PlayerProgression.load_from_profile(most_recent_character.get_progression_data())
			Logger.info("Loaded most recent character for debug: %s (Level %d)" % [most_recent_character.name, most_recent_character.level], "main")
		else:
			# No characters exist - create a fallback
			Logger.info("No existing characters found, creating fallback debug character", "main")
			var profile = CharacterManager.create_character("Debug Knight", StringName("Knight"))
			if profile:
				CharacterManager.load_character(profile.id)
				PlayerProgression.load_from_profile(profile.get_progression_data())
				Logger.info("Created and loaded fallback debug character: %s" % profile.name, "main")
			else:
				Logger.error("Failed to create fallback debug character", "main")
	else:
		# Try to load existing character
		var characters = CharacterManager.list_characters()
		var found_character: CharacterProfile = null
		
		for character in characters:
			if character.id == debug_character_id:
				found_character = character
				break
		
		if found_character:
			# Load existing character
			CharacterManager.load_character(debug_character_id)
			PlayerProgression.load_from_profile(found_character.get_progression_data())
			Logger.info("Loaded debug character: %s (Level %d)" % [found_character.name, found_character.level], "main")
		else:
			# Character not found, create a fallback
			Logger.warn("Debug character ID '%s' not found, creating fallback" % debug_character_id, "main")
			var profile = CharacterManager.create_character("Debug Fallback", StringName("Knight"))
			if profile:
				CharacterManager.load_character(profile.id)
				PlayerProgression.load_from_profile(profile.get_progression_data())
				Logger.info("Created fallback debug character: %s" % profile.name, "main")

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
