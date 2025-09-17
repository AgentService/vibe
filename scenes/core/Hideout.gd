extends Node2D

## Hideout scene - the game's central hub for menus, character selection, and map entry.
## Spawns the player and provides access to game systems via interactive elements.

const PlayerSpawner = preload("res://scripts/systems/PlayerSpawner.gd")

var player_spawner: PlayerSpawner
var player_instance: Node2D

func _ready() -> void:
	Logger.info("Hideout scene initializing", "hideout")

	# Initialize player spawner
	player_spawner = PlayerSpawner.new()
	add_child(player_spawner)

	# Spawn player at default spawn point
	_spawn_player()

	Logger.info("Hideout scene ready", "hideout")

func _spawn_player() -> void:
	"""Spawns the player at the spawn_hideout_main in this hideout."""
	
	var spawn_point_name = "spawn_hideout_main"
	player_instance = player_spawner.spawn_player(spawn_point_name, self)
	
	if player_instance:
		Logger.info("Player spawned successfully in hideout", "hideout")
		
		# Connect player-related signals if needed
		# EventBus.player_position_changed.connect(_on_player_moved)
	else:
		Logger.error("Failed to spawn player in hideout", "hideout")

func get_player() -> Node2D:
	"""Returns the player instance for other systems to reference."""
	return player_instance

# Removed local ESC handling - PauseUI now handles ESC globally to avoid conflicts
