extends Node

## Arena management system using native @export ArenaConfig for hot-reload support.

signal arena_loaded(arena_bounds: Rect2)

@export var arena_config: ArenaConfig

func _ready() -> void:
	arena_loaded.emit(get_arena_bounds())
	Logger.info("ArenaSystem initialized", "arena")

func get_arena_bounds() -> Rect2:
	if arena_config:
		return arena_config.bounds
	return Rect2(-400, -300, 800, 600)

func get_arena_center() -> Vector2:
	if arena_config:
		return arena_config.arena_center
	return Vector2.ZERO

func get_spawn_radius() -> float:
	if arena_config:
		return arena_config.spawn_radius
	return 200.0

func is_position_in_bounds(position: Vector2) -> bool:
	return get_arena_bounds().has_point(position)

func get_random_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var distance := randf() * get_spawn_radius()
	return get_arena_center() + Vector2(cos(angle), sin(angle)) * distance
