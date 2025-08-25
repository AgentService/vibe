extends Node2D

## Isolated camera system test - camera following, zoom, bounds.
## Tests camera movement, zoom controls, and arena boundaries.

@onready var player: CharacterBody2D = $Player
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0
const CameraSystem = preload("res://scripts/systems/CameraSystem.gd")

var camera_system: CameraSystem
var test_camera: Camera2D
var arena_bounds: Rect2 = Rect2(-500, -300, 1000, 600)

func _ready():
	print("=== CameraSystem_Isolated Test Started ===")
	print("Controls: WASD to move, Mouse wheel to zoom, B to toggle bounds")
	
	_setup_player()
	_setup_camera_system()
	_setup_arena_bounds_visualization()

func _setup_player():
	var player_sprite = player.get_node("Sprite2D")
	var player_collision = player.get_node("CollisionShape2D")
	
	# Create green player texture
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.GREEN)
	texture.set_image(image)
	player_sprite.texture = texture
	
	# Set up collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	player_collision.shape = shape

func _setup_camera_system():
	camera_system = CameraSystem.new()
	add_child(camera_system)
	
	# Create and setup the camera  
	test_camera = Camera2D.new()
	test_camera.name = "TestCamera"
	test_camera.enabled = true
	# Don't parent to player - keep it separate for manual control
	add_child(test_camera)
	
	# Set camera system properties
	camera_system.camera = test_camera
	camera_system.follow_speed = 8.0
	camera_system.zoom_speed = 5.0
	camera_system.min_zoom = 0.5
	camera_system.max_zoom = 3.0
	camera_system.default_zoom = 1.0
	camera_system.deadzone_radius = 50.0
	camera_system.arena_bounds = arena_bounds
	
	# Initialize camera position
	test_camera.global_position = player.global_position
	test_camera.zoom = Vector2(camera_system.default_zoom, camera_system.default_zoom)
	camera_system.target_position = player.global_position
	camera_system.target_zoom = camera_system.default_zoom
	
	print("Camera setup: deadzone=", camera_system.deadzone_radius, " bounds=", arena_bounds)

func _setup_arena_bounds_visualization():
	# Create a visual representation of arena bounds
	var bounds_rect = ColorRect.new()
	bounds_rect.color = Color(1, 0, 0, 0.1)  # Semi-transparent red
	bounds_rect.position = arena_bounds.position
	bounds_rect.size = arena_bounds.size
	add_child(bounds_rect)
	
	# Add border lines
	for i in 4:
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = Color.RED
		add_child(line)
		
		match i:
			0: # Top
				line.add_point(Vector2(arena_bounds.position.x, arena_bounds.position.y))
				line.add_point(Vector2(arena_bounds.position.x + arena_bounds.size.x, arena_bounds.position.y))
			1: # Right
				line.add_point(Vector2(arena_bounds.position.x + arena_bounds.size.x, arena_bounds.position.y))
				line.add_point(Vector2(arena_bounds.position.x + arena_bounds.size.x, arena_bounds.position.y + arena_bounds.size.y))
			2: # Bottom
				line.add_point(Vector2(arena_bounds.position.x + arena_bounds.size.x, arena_bounds.position.y + arena_bounds.size.y))
				line.add_point(Vector2(arena_bounds.position.x, arena_bounds.position.y + arena_bounds.size.y))
			3: # Left
				line.add_point(Vector2(arena_bounds.position.x, arena_bounds.position.y + arena_bounds.size.y))
				line.add_point(Vector2(arena_bounds.position.x, arena_bounds.position.y))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_B:
				_toggle_bounds()
			KEY_R:
				_reset_camera()
			KEY_S:
				if event.shift_pressed:
					_trigger_camera_shake()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-0.1)

func _physics_process(delta):
	_handle_player_movement(delta)
	_update_camera_system(delta)
	_update_info_display()

func _handle_player_movement(delta):
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		player.velocity = input_vector * PLAYER_SPEED
	else:
		player.velocity = Vector2.ZERO
	
	player.move_and_slide()
	
	# Update camera target position
	camera_system.target_position = player.global_position

func _update_camera_system(delta):
	if camera_system and camera_system.has_method("_physics_process"):
		# Manually call camera system update since it might not auto-process
		camera_system._physics_process(delta)
	
	# Additional manual bounds enforcement for testing
	if camera_system.arena_bounds != Rect2() and test_camera:
		_enforce_camera_bounds()

func _zoom_camera(zoom_delta: float):
	var new_zoom = clamp(
		camera_system.target_zoom + zoom_delta,
		camera_system.min_zoom,
		camera_system.max_zoom
	)
	camera_system.target_zoom = new_zoom
	print("Target zoom: ", new_zoom)

func _toggle_bounds():
	if camera_system.arena_bounds != Rect2():
		camera_system.arena_bounds = Rect2()
		print("Camera bounds disabled")
	else:
		camera_system.arena_bounds = arena_bounds
		print("Camera bounds enabled: ", arena_bounds)

func _reset_camera():
	camera_system.target_position = player.global_position
	camera_system.target_zoom = camera_system.default_zoom
	test_camera.global_position = player.global_position
	test_camera.zoom = Vector2(camera_system.default_zoom, camera_system.default_zoom)
	print("Camera reset to player position")

func _trigger_camera_shake():
	if camera_system.has_method("start_shake"):
		camera_system.start_shake(20.0, 1.0)
	else:
		# Manual shake simulation
		camera_system.shake_intensity = 20.0
		camera_system.shake_duration = 1.0
		camera_system.shake_timer = 1.0
	print("Camera shake triggered")

func _enforce_camera_bounds():
	# Manual camera bounds enforcement for testing
	var bounds = camera_system.arena_bounds
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_factor = test_camera.zoom.x
	var half_view = viewport_size / (2.0 * zoom_factor)
	
	# Calculate the constrained camera position
	var current_pos = test_camera.global_position
	var new_pos = current_pos
	
	# Clamp to bounds with margin for viewport
	new_pos.x = clamp(new_pos.x, 
		bounds.position.x + half_view.x,
		bounds.position.x + bounds.size.x - half_view.x)
	new_pos.y = clamp(new_pos.y,
		bounds.position.y + half_view.y,
		bounds.position.y + bounds.size.y - half_view.y)
	
	# Apply the constrained position
	if new_pos != current_pos:
		test_camera.global_position = new_pos
		print("Camera constrained to bounds: ", new_pos)

func _update_info_display():
	var player_pos = player.global_position
	var camera_pos = test_camera.global_position if test_camera else Vector2.ZERO
	var camera_zoom = test_camera.zoom.x if test_camera else 1.0
	var distance_to_target = camera_pos.distance_to(camera_system.target_position)
	
	info_label.text = "Camera System Test\n"
	info_label.text += "WASD: Move player\n"
	info_label.text += "Mouse wheel: Zoom camera\n"
	info_label.text += "B: Toggle bounds\n"
	info_label.text += "R: Reset camera\n"
	info_label.text += "Shift+S: Camera shake\n\n"
	info_label.text += "Player pos: " + str(player_pos.round()) + "\n"
	info_label.text += "Camera pos: " + str(camera_pos.round()) + "\n"
	info_label.text += "Distance: " + str(distance_to_target) + "\n"
	info_label.text += "Zoom: " + str(camera_zoom) + "\n"
	info_label.text += "Target zoom: " + str(camera_system.target_zoom) + "\n"
	info_label.text += "Bounds active: " + ("Yes" if camera_system.arena_bounds != Rect2() else "No") + "\n"
	info_label.text += "Deadzone: " + str(camera_system.deadzone_radius)
