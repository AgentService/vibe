extends Resource
class_name DebugConfig

## Debug configuration resource for controlling game startup modes and settings.
## Used by Main.gd to determine which scene to load and how to configure the game.

@export var debug_mode: bool = true
@export_enum("menu", "arena", "hideout", "map", "map_test") var start_mode: String = "menu"
@export var skip_main_menu: bool = false
@export var map_scene: String = ""
@export var character_id: StringName = &"knight_default"

func _init(
	p_debug_mode: bool = true,
	p_start_mode: String = "arena", 
	p_skip_main_menu: bool = false,
	p_map_scene: String = "",
	p_character_id: StringName = &"knight_default"
) -> void:
	debug_mode = p_debug_mode
	start_mode = p_start_mode
	skip_main_menu = p_skip_main_menu
	map_scene = p_map_scene
	character_id = p_character_id