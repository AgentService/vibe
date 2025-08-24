extends Node

## Arena management system - bounds now determined by TileMapLayer walls in editor.
## Spawn zones and arena center calculated from actual tile geometry.

signal arena_loaded(arena_bounds: Rect2)

var arena_bounds: Rect2 = Rect2()  # Will be calculated from TileMapLayer
var arena_center: Vector2 = Vector2.ZERO
var spawn_radius: float = 200.0

const ARENA_RESOURCE_PATH: String = "res://vibe/data/content/arena/default_arena.tres"

func _ready() -> void:
	load_default_arena()

func load_default_arena() -> bool:
	if ResourceLoader.exists(ARENA_RESOURCE_PATH):
		var arena_config = load(ARENA_RESOURCE_PATH)
		if arena_config:
			_apply_arena_config(arena_config)
			arena_loaded.emit(arena_bounds)
			print("Arena loaded from .tres resource")
			return true
	
	# Fallback to default values if resource doesn't exist
	print("Arena resource not found, using defaults")
	arena_loaded.emit(arena_bounds)
	return false

func _apply_arena_config(config) -> void:
	if config.has_method("get_bounds"):
		arena_bounds = config.get_bounds()
	if config.has_method("get_center"):
		arena_center = config.get_center()
	if config.has_method("get_spawn_radius"):
		spawn_radius = config.get_spawn_radius()

func get_arena_bounds() -> Rect2:
	return arena_bounds

func get_arena_center() -> Vector2:
	return arena_center

func get_spawn_radius() -> float:
	return spawn_radius

func is_position_in_bounds(position: Vector2) -> bool:
	return arena_bounds.has_point(position)

func get_random_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var distance := randf() * spawn_radius
	return arena_center + Vector2(cos(angle), sin(angle)) * distance

func cleanup() -> void:
	# Simple cleanup - reset to empty (bounds will be recalculated from tiles)
	arena_bounds = Rect2()
	arena_center = Vector2.ZERO
	spawn_radius = 200.0
