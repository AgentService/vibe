extends Resource

## Boss spawn configuration resource for editor-configurable boss spawn positions
## Allows level designers to configure boss spawns without hardcoded positions

class_name BossSpawnConfig

@export var boss_id: String = "dragon_lord": ## Boss type identifier (dragon_lord, ancient_lich, etc.)
	set(value):
		boss_id = value
		notify_property_list_changed()

@export var spawn_position: Vector2 = Vector2(150, 150): ## Offset from player position
	set(value):
		spawn_position = value
		notify_property_list_changed()

@export_enum("relative_to_player", "absolute", "random_circle") var spawn_method: String = "relative_to_player": ## Position calculation method
	set(value):
		spawn_method = value
		notify_property_list_changed()

@export var spawn_radius: float = 200.0: ## Radius for random_circle spawn method
	set(value):
		spawn_radius = value
		notify_property_list_changed()

@export var enabled: bool = true: ## Whether this spawn config is active
	set(value):
		enabled = value
		notify_property_list_changed()

## Calculate the final spawn position based on the configuration
## @param player_position: Current player position
## @param arena_center: Center of the arena (fallback if no player)
## @return Vector2: Final spawn position
func calculate_spawn_position(player_position: Vector2, arena_center: Vector2 = Vector2.ZERO) -> Vector2:
	var reference_pos = player_position if player_position != Vector2.ZERO else arena_center
	
	match spawn_method:
		"relative_to_player":
			return reference_pos + spawn_position
		"absolute":
			return spawn_position
		"random_circle":
			var angle = randf() * TAU
			var distance = randf() * spawn_radius
			return reference_pos + Vector2(cos(angle), sin(angle)) * distance
		_:
			Logger.warn("Unknown spawn method: " + spawn_method + ", using relative_to_player", "waves")
			return reference_pos + spawn_position

## Get a human-readable description of this spawn config
func get_description() -> String:
	var desc = boss_id
	if not enabled:
		desc += " (DISABLED)"
	
	match spawn_method:
		"relative_to_player":
			desc += " at offset " + str(spawn_position)
		"absolute":
			desc += " at absolute " + str(spawn_position)
		"random_circle":
			desc += " randomly within " + str(spawn_radius) + "px"
	
	return desc
