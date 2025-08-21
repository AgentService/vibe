extends CharacterBody2D
class_name Player

## Player character with WASD movement and collision.
## Serves as the center point for projectile spawning and XP collection.

@export var move_speed: float = 220.0
@export var pickup_radius: float = 12.0

func _ready() -> void:
	# Player should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	_setup_collision()

func _setup_collision() -> void:
	var collision_shape := $CollisionShape2D
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 8.0
	collision_shape.shape = circle_shape

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1.0
	
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * move_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func get_pos() -> Vector2:
	return global_position
