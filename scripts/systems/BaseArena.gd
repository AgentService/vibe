class_name BaseArena
extends Node2D

## Base class for all arena scenes in the game
## Provides standardized interface for systems like WaveDirector, ArenaSystem, etc.
## Future arena variants (Arena2, CityArena, etc.) should extend this class

# Arena identification and configuration
@export var arena_id: String = "default_arena"
@export var arena_name: String = "Default Arena"

# Spawn configuration - can be overridden in child arenas
@export var spawn_radius: float = 400.0
@export var arena_bounds: float = 500.0

# Arena state tracking
var is_player_dead: bool = false

func _ready() -> void:
	Logger.info("BaseArena initialized: %s (%s)" % [arena_name, arena_id], "arena")
	
	# Defer EventBus connection to avoid architecture boundary violation
	call_deferred("_connect_events")

## Explicit arena identification method for systems
func is_arena_scene() -> bool:
	return true

## Handle player death - common logic for all arena types
func _on_player_died() -> void:
	"""Handle player death - set death state and pause arena systems"""
	is_player_dead = true
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	Logger.info("BaseArena: Player died, disabling arena processing", "arena")

## Get spawn radius for this arena (can be overridden)
func get_spawn_radius() -> float:
	return spawn_radius

## Get arena bounds for this arena (can be overridden)
func get_arena_bounds() -> float:
	return arena_bounds

## Get arena center (default implementation, can be overridden)
func get_arena_center() -> Vector2:
	return global_position

## Connect to EventBus (deferred to avoid architecture boundary violation)
func _connect_events() -> void:
	# Connect to player death events for all arena types
	if EventBus.player_died.connect(_on_player_died) != OK:
		Logger.warn("BaseArena: Failed to connect to player_died signal", "arena")