extends Node2D

## Isolated core loop test - validates StateManager integration and basic functionality.
## Tests state transitions, pause permissions, and core game loop mechanics.

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
	print("Controls: WASD to move, P to pause, ESC to pause (global), Mouse wheel to zoom camera")
	print("Testing StateManager integration, global pause system, and core game loop")
	
	# Set StateManager to ARENA state for testing
	StateManager.current_state = StateManager.State.ARENA
	
	_setup_player()
	_setup_camera()
	_setup_ui()
	_test_state_manager_integration()
	_test_pause_functionality()

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
			_toggle_local_pause()
		elif event.keycode == KEY_Q:
			print("Exiting CoreLoop test...")
			get_tree().quit()
		# ESC will be handled by GameOrchestrator for global pause testing
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

func _toggle_local_pause():
	# Test local pause (P key) - this tests StateManager pause permissions
	if StateManager.is_pause_allowed():
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
		
		print("Game paused: ", is_paused, " (StateManager allows pause: ", StateManager.is_pause_allowed(), ")")
	else:
		print("Pause blocked - not allowed in current state: ", StateManager.get_current_state_string())

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
	info_label.text += "Paused: " + ("Yes" if is_paused else "No") + "\n"
	info_label.text += "StateManager State: " + StateManager.get_current_state_string() + "\n"
	info_label.text += "Pause Allowed: " + ("Yes" if StateManager.is_pause_allowed() else "No")

func _test_state_manager_integration():
	"""Test StateManager integration and report results."""
	print("=== StateManager Integration Tests ===")
	
	# Test 1: Current state should be ARENA
	var current_state = StateManager.get_current_state()
	if current_state == StateManager.State.ARENA:
		print("✓ StateManager in ARENA state")
	else:
		print("✗ StateManager not in expected ARENA state: ", current_state)
	
	# Test 2: Pause should be allowed in ARENA
	if StateManager.is_pause_allowed():
		print("✓ Pause allowed in ARENA state")
	else:
		print("✗ Pause not allowed in ARENA state (unexpected)")
	
	# Test 3: Test state string conversion
	var state_string = StateManager.get_current_state_string()
	if state_string == "ARENA":
		print("✓ State string conversion works")
	else:
		print("✗ State string conversion failed: ", state_string)
	
	print("=== Integration Tests Complete ===")
	print("Use P to test local pause, ESC to test global pause functionality")

func _test_pause_functionality():
	"""Test pause functionality integration with PauseManager and PauseUI."""
	print("\n=== Testing Pause System Integration ===")
	
	# Connect to pause events to monitor them
	if not EventBus.game_paused_changed.is_connected(_on_pause_changed_test):
		EventBus.game_paused_changed.connect(_on_pause_changed_test)
	
	# Test 1: Initial pause state should be false
	if not PauseManager.is_paused():
		print("✓ Initial pause state is false")
	else:
		print("✗ Initial pause state should be false")
	
	# Test 2: PauseUI should exist and be accessible
	if PauseUI:
		print("✓ PauseUI autoload accessible")
	else:
		print("✗ PauseUI autoload not found")
	
	# Test 3: StateManager should allow pause in ARENA state
	if StateManager.is_pause_allowed():
		print("✓ Pause allowed in current state (ARENA)")
	else:
		print("✗ Pause should be allowed in ARENA state")
	
	print("Manual tests available:")
	print("  - Press P to test local pause (tests StateManager.is_pause_allowed)")
	print("  - Press ESC to test global pause (tests GameOrchestrator -> PauseUI flow)")
	print("  - Press Q to exit test")

func _on_pause_changed_test(payload) -> void:
	"""Monitor pause state changes for testing."""
	var is_paused = payload.is_paused if payload else false
	print("Pause state changed: ", is_paused)
	
	if is_paused:
		print("  - Game is now paused")
		print("  - PauseUI overlay should be visible")
	else:
		print("  - Game is now unpaused") 
		print("  - PauseUI overlay should be hidden")