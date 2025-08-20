extends Node
class_name ObstacleSystem

## Obstacle system for managing walls, pillars, barriers, and destructible objects.
## Creates collision bodies and visual representation via MultiMeshInstance2D.

signal obstacles_updated(obstacle_transforms: Array[Transform2D])
signal obstacle_destroyed(obstacle_id: String, position: Vector2)

var obstacle_bodies: Array[StaticBody2D] = []
var obstacle_transforms: Array[Transform2D] = []
var obstacle_data: Dictionary = {}

const OBSTACLE_TEXTURE_PATH: String = "res://assets/sprites/obstacles/"
const DEFAULT_OBSTACLE_SIZE: Vector2 = Vector2(32, 32)

func _ready() -> void:
	pass

func load_obstacles(obstacles_config: Dictionary) -> void:
	clear_obstacles()
	obstacle_data = obstacles_config
	
	var obstacles := obstacles_config.get("objects", []) as Array
	
	for obstacle_data_item in obstacles:
		var obstacle := obstacle_data_item as Dictionary
		_create_obstacle(obstacle)
	
	_update_obstacle_visuals()

func clear_obstacles() -> void:
	# Remove collision bodies
	for body in obstacle_bodies:
		if is_instance_valid(body):
			body.queue_free()
	
	obstacle_bodies.clear()
	obstacle_transforms.clear()
	obstacle_data.clear()

func _create_obstacle(obstacle_config: Dictionary) -> void:
	var position := Vector2(
		obstacle_config.get("x", 0.0) as float,
		obstacle_config.get("y", 0.0) as float
	)
	var obstacle_type := obstacle_config.get("type", "pillar") as String
	var size := _parse_size(obstacle_config.get("size", {}))
	var rotation := obstacle_config.get("rotation", 0.0) as float
	var obstacle_id := obstacle_config.get("id", "obstacle_" + str(obstacle_bodies.size())) as String
	
	# Create collision body
	_create_obstacle_collision(position, size, rotation, obstacle_id, obstacle_type, obstacle_config)
	
	# Create visual transform
	var transform := Transform2D()
	transform.origin = position
	transform = transform.rotated(rotation)
	obstacle_transforms.append(transform)

func _create_obstacle_collision(pos: Vector2, size: Vector2, rotation: float, id: String, type: String, config: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = "Obstacle_" + id
	body.global_position = pos
	body.rotation = rotation
	
	# Set collision layers for proper interaction
	body.collision_layer = 2  # Obstacle layer
	body.collision_mask = 0   # Obstacles don't need to detect anything
	
	var collision := CollisionShape2D.new()
	var shape: Shape2D
	
	# Create appropriate collision shape based on obstacle type
	match type:
		"pillar", "barrel", "statue":
			# Circular obstacles
			var circle_shape := CircleShape2D.new()
			circle_shape.radius = min(size.x, size.y) * 0.5
			shape = circle_shape
		"wall", "barrier", "crate":
			# Rectangular obstacles
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = size
			shape = rect_shape
		_:
			# Default to rectangle
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = size
			shape = rect_shape
	
	collision.shape = shape
	body.add_child(collision)
	
	# Add metadata for identification
	body.set_meta("obstacle_id", id)
	body.set_meta("obstacle_type", type)
	body.set_meta("destructible", config.get("destructible", false))
	
	get_parent().add_child(body)
	obstacle_bodies.append(body)

func _parse_size(size_data: Dictionary) -> Vector2:
	return Vector2(
		size_data.get("width", DEFAULT_OBSTACLE_SIZE.x) as float,
		size_data.get("height", DEFAULT_OBSTACLE_SIZE.y) as float
	)

func _update_obstacle_visuals() -> void:
	obstacles_updated.emit(obstacle_transforms)

func destroy_obstacle(obstacle_id: String) -> bool:
	# Find and remove obstacle by ID
	for i in range(obstacle_bodies.size()):
		var body := obstacle_bodies[i]
		if body.get_meta("obstacle_id", "") == obstacle_id:
			var was_destructible := body.get_meta("destructible", false) as bool
			if not was_destructible:
				return false
			
			var position := body.global_position
			
			# Remove from arrays
			obstacle_bodies.remove_at(i)
			if i < obstacle_transforms.size():
				obstacle_transforms.remove_at(i)
			
			# Remove from scene
			body.queue_free()
			
			# Update visuals
			_update_obstacle_visuals()
			
			# Emit destruction signal
			obstacle_destroyed.emit(obstacle_id, position)
			return true
	
	return false

func get_obstacles_in_area(area: Rect2) -> Array[StaticBody2D]:
	var result: Array[StaticBody2D] = []
	
	for body in obstacle_bodies:
		if area.has_point(body.global_position):
			result.append(body)
	
	return result

func is_position_blocked(world_pos: Vector2, check_radius: float = 16.0) -> bool:
	# Check if a position is blocked by obstacles
	var space_state: PhysicsDirectSpaceState2D = get_parent().get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 2  # Obstacle layer
	
	var result: Array[Dictionary] = space_state.intersect_point(query)
	return result.size() > 0

func cleanup() -> void:
	clear_obstacles()

func _exit_tree() -> void:
	cleanup()
