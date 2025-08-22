extends Node

## Camera System for smooth player following with limits and zoom controls.
## Follows the project's system architecture with signal-based communication.

signal camera_moved(position: Vector2)
signal camera_zoomed(zoom_level: float)
signal camera_shake_requested(intensity: float, duration: float)

@export var follow_speed: float = 8.0
@export var zoom_speed: float = 5.0
@export var max_zoom: float = 2.0
var min_zoom: float  # Will be loaded from balance data
@export var default_zoom: float = 2
@export var deadzone_radius: float = 20.0
@export var shake_intensity: float = 0.0

var camera: Camera2D
var target_position: Vector2
var target_zoom: float
var arena_bounds: Rect2
var shake_timer: float = 0.0
var shake_duration: float = 0.0
var original_position: Vector2

func _ready() -> void:
	# Camera should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Load min zoom from balance data
	min_zoom = BalanceDB.get_waves_value("camera_min_zoom")
	target_zoom = default_zoom
	_connect_signals()

func _connect_signals() -> void:
	EventBus.arena_bounds_changed.connect(_on_arena_bounds_changed)
	EventBus.player_position_changed.connect(_on_player_position_changed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.game_paused_changed.connect(_on_game_paused_changed)
	PlayerState.player_position_changed.connect(_on_player_moved)

func setup_camera(player_node: Node2D) -> void:
	if not player_node:
		push_error("CameraSystem: Cannot setup camera - player node is null")
		return
	
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.zoom = Vector2(default_zoom, default_zoom)
	camera.enabled = true
	
	# Add camera to player so it follows automatically
	player_node.add_child(camera)
	
	target_position = player_node.global_position
	original_position = target_position

func _physics_process(delta: float) -> void:
	if not camera:
		return
	
	_update_camera_position(delta)
	_update_zoom(delta)
	_update_shake(delta)

func _update_camera_position(delta: float) -> void:
	if target_position == Vector2.ZERO:
		return
	
	var current_pos := camera.global_position
	var distance := current_pos.distance_to(target_position)
	
	# Only move camera if player is outside deadzone
	if distance > deadzone_radius:
		var move_direction := (target_position - current_pos).normalized()
		var move_speed := follow_speed * (distance / deadzone_radius)
		
		var new_position := current_pos + move_direction * move_speed * delta * 60.0
		
		# Clamp camera to arena bounds if set
		if arena_bounds != Rect2():
			var viewport_size := get_viewport().get_visible_rect().size
			var zoom_factor := camera.zoom.x
			var half_view := viewport_size / (2.0 * zoom_factor)
			
			new_position.x = clamp(new_position.x, 
				arena_bounds.position.x + half_view.x,
				arena_bounds.position.x + arena_bounds.size.x - half_view.x)
			new_position.y = clamp(new_position.y,
				arena_bounds.position.y + half_view.y,
				arena_bounds.position.y + arena_bounds.size.y - half_view.y)
		
		camera.global_position = new_position
		camera_moved.emit(new_position)

func _update_zoom(delta: float) -> void:
	var current_zoom: float = camera.zoom.x
	if abs(current_zoom - target_zoom) > 0.01:
		var new_zoom: float = lerp(current_zoom, target_zoom, zoom_speed * delta)
		camera.zoom = Vector2(new_zoom, new_zoom)
		camera_zoomed.emit(new_zoom)

func _update_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		
		# Calculate shake offset
		var shake_offset := Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		# Apply shake with falloff
		var shake_factor := shake_timer / shake_duration
		camera.offset = shake_offset * shake_factor
		
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not camera:
		return
	
	# Zoom controls
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()

func zoom_in() -> void:
	target_zoom = clamp(target_zoom + 0.2, min_zoom, max_zoom)

func zoom_out() -> void:
	target_zoom = clamp(target_zoom - 0.2, min_zoom, max_zoom)

func set_zoom(zoom_level: float) -> void:
	target_zoom = clamp(zoom_level, min_zoom, max_zoom)

func shake_camera(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration
	camera_shake_requested.emit(intensity, duration)

func set_arena_bounds(bounds: Rect2) -> void:
	arena_bounds = bounds

func center_on_position(position: Vector2) -> void:
	target_position = position
	if camera:
		camera.global_position = position

func _on_arena_bounds_changed(payload) -> void:
	set_arena_bounds(payload.bounds)

func _on_player_position_changed(payload) -> void:
	target_position = payload.position

func _on_player_moved(position: Vector2) -> void:
	target_position = position

func _on_damage_dealt(payload) -> void:
	# Add screen shake for significant damage
	if payload.damage > 50.0:
		shake_camera(2.0, 0.2)
	elif payload.damage > 20.0:
		shake_camera(1.0, 0.1)

func _on_game_paused_changed(payload) -> void:
	# Camera should continue working during pause (for UI interactions)
	# Just ensure we keep receiving player position updates
	if not payload.is_paused and camera:
		# Re-sync camera when unpaused
		camera.enabled = true

func get_camera_position() -> Vector2:
	if camera:
		return camera.global_position
	return Vector2.ZERO

func get_camera_zoom() -> float:
	if camera:
		return camera.zoom.x
	return 1.0