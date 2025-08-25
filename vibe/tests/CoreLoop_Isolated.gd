extends Node2D

## Isolated core loop test - basic player movement, camera, HUD, pause.
## Tests fundamental game loop mechanics without combat systems.

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var info_label: Label = $UILayer/HUD/InfoLabel
@onready var pause_overlay: ColorRect = $UILayer/PauseOverlay

const PLAYER_SPEED = 300.0
const CAMERA_ZOOM_MIN = 0.5
const CAMERA_ZOOM_MAX = 2.0

var is_paused: bool = false
var camera_zoom: float = 1.0

func _ready():
	print("=== CoreLoop_Isolated Test Started ===")
	print("Controls: WASD to move, P to pause, Mouse wheel to zoom camera")
	
	_setup_player()
	_setup_camera()
	_setup_ui()

func _setup_player():
	var player_sprite = player.get_node("Sprite2D")
	var player_collision = player.get_node("CollisionShape2D")
	
	# Create blue player texture
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	texture.set_image(image)
	player_sprite.texture = texture
	
	# Set up collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	player_collision.shape = shape

func _setup_camera():
	camera.enabled = true
	camera.zoom = Vector2(camera_zoom, camera_zoom)

func _setup_ui():
	# Set up pause overlay
	pause_overlay.color = Color(0, 0, 0, 0.5)
	pause_overlay.visible = false
	pause_overlay.anchors_preset = Control.PRESET_FULL_RECT

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			_toggle_pause()
		elif event.keycode == KEY_ESCAPE:
			print("Exiting CoreLoop test...")
			get_tree().quit()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-0.1)

func _physics_process(delta):
	if not is_paused:
		_handle_player_movement(delta)
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

func _toggle_pause():
	is_paused = not is_paused
	pause_overlay.visible = is_paused
	
	var pause_text = pause_overlay.get_node_or_null("PauseLabel")
	if not pause_text:
		pause_text = Label.new()
		pause_text.name = "PauseLabel"
		pause_text.text = "PAUSED - Press P to Resume"
		pause_text.anchors_preset = Control.PRESET_CENTER
		pause_text.add_theme_font_size_override("font_size", 32)
		pause_overlay.add_child(pause_text)
	
	print("Game paused: ", is_paused)

func _zoom_camera(zoom_delta: float):
	camera_zoom = clamp(camera_zoom + zoom_delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	print("Camera zoom: ", camera_zoom)

func _update_info_display():
	var player_pos = player.global_position
	var velocity_magnitude = player.velocity.length()
	
	info_label.text = "Core Loop Test\n"
	info_label.text += "WASD: Move player\n"
	info_label.text += "P: Pause/Resume\n"
	info_label.text += "Mouse Wheel: Zoom camera\n"
	info_label.text += "ESC: Exit test\n\n"
	info_label.text += "Player Position: " + str(player_pos.round()) + "\n"
	info_label.text += "Velocity: " + str(velocity_magnitude) + "\n"
	info_label.text += "Camera Zoom: " + str(camera_zoom) + "\n"
	info_label.text += "Paused: " + ("Yes" if is_paused else "No")