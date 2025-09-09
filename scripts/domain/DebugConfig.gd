extends Resource
class_name DebugConfig

## Debug configuration resource for controlling game startup modes and settings.
## Used by Main.gd to determine which scene to load and how to configure the game.

@export var debug_mode: bool = true
@export_enum("menu", "arena", "hideout", "map", "map_test") var start_mode: String = "menu"
@export var skip_main_menu: bool = false
@export var map_scene: String = ""
@export_enum("auto", "custom_id", "create_new") var character_selection: String = "auto"
@export var character_id: StringName = &""  # Used when character_selection is "custom_id"

func _init(
	p_debug_mode: bool = true,
	p_start_mode: String = "arena", 
	p_skip_main_menu: bool = false,
	p_map_scene: String = "",
	p_character_selection: String = "auto"
) -> void:
	debug_mode = p_debug_mode
	start_mode = p_start_mode
	skip_main_menu = p_skip_main_menu
	map_scene = p_map_scene
	character_selection = p_character_selection

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
