extends Resource
class_name ArenaConfig

## Arena configuration resource for defining arena properties.
## Migrated from JSON to .tres for type safety and inspector support.

@export var arena_id: String = "default_arena"
@export var arena_name: String = "Combat Arena"

# Arena spatial properties
@export var bounds: Rect2 = Rect2(-400, -300, 800, 600)
@export var arena_center: Vector2 = Vector2.ZERO  
@export var spawn_radius: float = 200.0

func get_bounds() -> Rect2:
	return bounds

func get_center() -> Vector2:
	return arena_center

func get_spawn_radius() -> float:
	return spawn_radius

func is_position_in_bounds(position: Vector2) -> bool:
	return bounds.has_point(position)