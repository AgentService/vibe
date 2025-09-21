extends Resource
class_name EventSpawnStrategy

## Base class for event-specific spawning strategies
## Each event type (breach, ritual, pack hunt) can define custom spawn behavior
## while keeping SpawnDirector clean and extensible

@export_group("Strategy Settings")
@export var strategy_name: String = "default"
@export var respects_player_proximity: bool = true
@export var respects_zone_bounds: bool = true

@export_group("Spawn Validation")
@export var max_spawn_attempts: int = 10
@export var fallback_to_center: bool = true

func validate_spawn_position(position: Vector2, context: Dictionary) -> bool:
	"""Validate if a spawn position is acceptable for this strategy"""
	return true  # Override in subclasses

func get_spawn_position(context: Dictionary) -> Vector2:
	"""Generate a spawn position based on strategy-specific logic"""
	return Vector2.ZERO  # Override in subclasses

func should_spawn_now(context: Dictionary) -> bool:
	"""Check if spawning should occur now based on strategy timing"""
	return true  # Override for timing control

func get_strategy_info() -> Dictionary:
	"""Return debug information about this strategy"""
	return {
		"name": strategy_name,
		"respects_proximity": respects_player_proximity,
		"respects_zones": respects_zone_bounds,
		"max_attempts": max_spawn_attempts
	}

# Helper methods for common validation tasks
func _is_position_in_zone(position: Vector2, zone_area: Area2D) -> bool:
	"""Check if position is within zone bounds"""
	if not zone_area:
		return true

	var shape_owners = zone_area.get_shape_owners()
	if shape_owners.size() == 0:
		return true

	var owner_id = shape_owners[0]
	var shape = zone_area.shape_owner_get_shape(owner_id, 0)
	var zone_transform = zone_area.global_transform

	# Transform position to zone local space and test collision
	var local_pos = zone_transform.affine_inverse() * position

	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var half_size = rect_shape.size / 2
		return abs(local_pos.x) <= half_size.x and abs(local_pos.y) <= half_size.y
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		return local_pos.length() <= circle_shape.radius

	return true

func _distance_to_player(position: Vector2) -> float:
	"""Get distance from position to player"""
	if PlayerState.has_player_reference():
		return position.distance_to(PlayerState.position)
	return 0.0

func _is_within_proximity_range(position: Vector2, min_distance: float, max_distance: float) -> bool:
	"""Check if position is within player proximity range"""
	if not respects_player_proximity:
		return true

	var distance = _distance_to_player(position)
	return distance >= min_distance and distance <= max_distance