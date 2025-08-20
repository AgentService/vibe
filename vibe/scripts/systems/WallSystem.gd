extends Node

## Wall System for arena boundaries and collision
## Manages wall collision bodies and visual representation
## Now integrated with ArenaSystem for data-driven configuration

signal walls_updated(wall_transforms: Array[Transform2D])

var wall_bodies: Array[StaticBody2D] = []
var wall_transforms: Array[Transform2D] = []
var boundary_data: Dictionary = {}

const WALL_TEXTURE_PATH: String = "res://assets/sprites/walls/wall_segment.webp"
const DEFAULT_WALL_SEGMENT_SIZE: Vector2 = Vector2(64, 32)
const DEFAULT_ARENA_SIZE: Vector2 = Vector2(800, 600)
const DEFAULT_WALL_THICKNESS: float = 32.0

func _ready() -> void:
	# Don't auto-create walls - wait for load_boundaries call from ArenaSystem
	pass

func load_boundaries(boundaries_config: Dictionary) -> void:
	cleanup()
	boundary_data = boundaries_config
	
	# Get configuration values with fallbacks
	var arena_size := _parse_arena_size(boundaries_config.get("arena_size", {}))
	var wall_thickness := boundaries_config.get("wall_thickness", DEFAULT_WALL_THICKNESS) as float
	var wall_segment_size := _parse_wall_segment_size(boundaries_config.get("wall_segment_size", {}))
	
	# Create walls based on configuration
	_create_arena_walls(arena_size, wall_thickness, wall_segment_size)
	_update_wall_visuals()

func _parse_arena_size(size_data: Dictionary) -> Vector2:
	return Vector2(
		size_data.get("x", DEFAULT_ARENA_SIZE.x) as float,
		size_data.get("y", DEFAULT_ARENA_SIZE.y) as float
	)

func _parse_wall_segment_size(size_data: Dictionary) -> Vector2:
	return Vector2(
		size_data.get("x", DEFAULT_WALL_SEGMENT_SIZE.x) as float,
		size_data.get("y", DEFAULT_WALL_SEGMENT_SIZE.y) as float
	)

func _create_arena_walls(arena_size: Vector2, wall_thickness: float, segment_size: Vector2) -> void:
	var arena_bounds := Rect2(-arena_size * 0.5, arena_size)
	var half_thickness := wall_thickness * 0.5
	
	# Create walls exactly at the arena boundaries
	# Player can move to the edge but not beyond
	
	# Top wall - positioned at the top boundary
	_create_wall_segment(
		Vector2(arena_bounds.position.x + arena_bounds.size.x * 0.5, arena_bounds.position.y + half_thickness),
		Vector2(arena_bounds.size.x + wall_thickness, wall_thickness),
		segment_size
	)
	
	# Bottom wall - positioned at the bottom boundary
	_create_wall_segment(
		Vector2(arena_bounds.position.x + arena_bounds.size.x * 0.5, arena_bounds.position.y + arena_bounds.size.y - half_thickness),
		Vector2(arena_bounds.size.x + wall_thickness, wall_thickness),
		segment_size
	)
	
	# Left wall - positioned at the left boundary
	_create_wall_segment(
		Vector2(arena_bounds.position.x + half_thickness, arena_bounds.position.y + arena_bounds.size.y * 0.5),
		Vector2(wall_thickness, arena_bounds.size.y),
		segment_size
	)
	
	# Right wall - positioned at the right boundary
	_create_wall_segment(
		Vector2(arena_bounds.position.x + arena_bounds.size.x - half_thickness, arena_bounds.position.y + arena_bounds.size.y * 0.5),
		Vector2(wall_thickness, arena_bounds.size.y),
		segment_size
	)

func _create_wall_segment(position: Vector2, size: Vector2, segment_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Wall_" + str(wall_bodies.size())
	body.global_position = position
	
	var collision := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	collision.shape = rect_shape
	
	body.add_child(collision)
	get_parent().add_child(body)
	wall_bodies.append(body)
	
	# Store visual transforms for rendering - align segments to wall boundaries
	var segments_x: int = max(1, int(size.x / segment_size.x))
	var segments_y: int = max(1, int(size.y / segment_size.y))
	
	# Calculate starting position to align with wall boundary
	var start_x := position.x - size.x * 0.5
	var start_y := position.y - size.y * 0.5
	
	for x in range(segments_x):
		for y in range(segments_y):
			var segment_pos := Vector2(
				start_x + x * segment_size.x + segment_size.x * 0.5,
				start_y + y * segment_size.y + segment_size.y * 0.5
			)
			var transform := Transform2D()
			transform.origin = segment_pos
			wall_transforms.append(transform)

func _update_wall_visuals() -> void:
	walls_updated.emit(wall_transforms)

func get_arena_bounds() -> Rect2:
	if boundary_data.has("arena_size"):
		var arena_size := _parse_arena_size(boundary_data.arena_size)
		return Rect2(-arena_size * 0.5, arena_size)
	return Rect2(-DEFAULT_ARENA_SIZE * 0.5, DEFAULT_ARENA_SIZE)

func cleanup() -> void:
	for body in wall_bodies:
		if is_instance_valid(body):
			body.queue_free()
	wall_bodies.clear()
	wall_transforms.clear()

func _exit_tree() -> void:
	cleanup()