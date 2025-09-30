extends Resource
class_name DebugConfig

## Debug configuration resource for controlling game startup modes and settings.
## Used by Main.gd to determine which scene to load and how to configure the game.

@export var debug_panels_enabled: bool = false  # Default: debug panels disabled for performance
@export_enum("menu", "arena", "hideout", "map", "map_test") var start_mode: String = "menu"
@export var skip_main_menu: bool = false

@export_group("Arena Selection")
## Arena to load for debug mode - auto-discovered from scenes/arena/
@export_enum("Arena", "PathAware_Forest", "ProceduralArena", "UnderworldArena", "Custom Path") var arena_selection: String = "Arena"
@export var custom_arena_path: String = ""  # Used when arena_selection is "Custom Path"

@export_group("Character Selection")
@export_enum("auto", "knight", "ranger", "custom_id", "create_new") var character_selection: String = "auto"
@export var character_id: StringName = &""  # Used when character_selection is "custom_id"

@export_group("Boss Debug")
@export var show_personal_space_circles: bool = false  # Control boss personal space visualization

@export_group("Performance Debug")
@export var enable_breach_monitoring: bool = false  # Enable automatic breach performance monitoring
@export var enable_ritual_monitoring: bool = false  # Enable automatic ritual performance monitoring
@export var enable_packhunt_monitoring: bool = false  # Enable automatic pack hunt performance monitoring
@export var enable_boss_monitoring: bool = false  # Enable automatic boss performance monitoring
@export var event_monitor_interval: float = 5.0  # Seconds between automatic monitoring reports


func _init(
	p_debug_panels_enabled: bool = false,
	p_start_mode: String = "arena",
	p_skip_main_menu: bool = false,
	p_arena_selection: String = "Arena",
	p_character_selection: String = "auto"
) -> void:
	debug_panels_enabled = p_debug_panels_enabled
	start_mode = p_start_mode
	skip_main_menu = p_skip_main_menu
	arena_selection = p_arena_selection
	character_selection = p_character_selection


func get_arena_scene_name() -> String:
	"""Get the arena scene name based on the selected arena."""
	if arena_selection == "Custom Path":
		if custom_arena_path.is_empty():
			Logger.warn("Debug: Custom arena path is empty, falling back to default", "debug")
			return custom_arena_path
		return custom_arena_path

	# Return just the scene name, let caller construct full path
	return arena_selection

func get_debug_character_id() -> StringName:
	"""Get the character ID to use for debug mode, supporting auto-selection."""
	if character_selection == "auto":
		# Use last played character if available
		if CharacterManager:
			var characters = CharacterManager.list_characters()
			if not characters.is_empty():
				var last_played = characters[0]  # Already sorted by last_played
				Logger.info("Debug: Auto-selecting last played character: %s (%s)" % [last_played.name, last_played.id], "debug")
				return last_played.id

		# Fallback to creating a default character
		Logger.info("Debug: No characters found, will create default character", "debug")
		return &""  # Empty means create default
	elif character_selection == "knight":
		Logger.info("Debug: Selecting Knight character", "debug")
		return &"knight"
	elif character_selection == "ranger":
		Logger.info("Debug: Selecting Ranger character", "debug")
		return &"ranger"
	elif character_selection == "custom_id":
		# Use custom character_id if specified
		if not character_id.is_empty():
			Logger.info("Debug: Using custom character ID: %s" % character_id, "debug")
			return character_id
		else:
			Logger.warn("Debug: custom_id selected but no character_id specified, falling back to auto", "debug")
			# Manually execute auto mode logic to avoid infinite recursion
			if CharacterManager:
				var characters = CharacterManager.list_characters()
				if not characters.is_empty():
					var last_played = characters[0]
					return last_played.id
			return &""
	elif character_selection == "create_new":
		# Always create a new debug character
		Logger.info("Debug: Will create new debug character", "debug")
		return &""  # Empty means create new
	else:
		# Fallback to auto mode without recursion
		Logger.warn("Debug: Unknown character_selection '%s', using auto" % character_selection, "debug")
		if CharacterManager:
			var characters = CharacterManager.list_characters()
			if not characters.is_empty():
				return characters[0].id
		return &""
