extends Node

## Camera System for zero-stutter player following with limits and zoom controls.
##
## ARCHITECTURE: Uses parent-child relationship for perfect camera following.
## The camera is parented directly to the player node, which provides:
## - Zero-lag following (no physics vs render timing issues)
## - Perfect transform inheritance (eliminates all stuttering)
## - No need for manual position updates or smoothing
##
## This approach is the Godot best practice for locked, zero-deadzone cameras.
## Follows the project's system architecture with signal-based communication.

signal camera_moved(position: Vector2)
signal camera_zoomed(zoom_level: float)
signal camera_shake_requested(intensity: float, duration: float)

@export var zoom_speed: float = 5.0
@export var min_zoom: float = 0.5  # Godot: <1 zooms in (closer), >1 zooms out
@export var max_zoom: float = 3.0  # Cap zoom out
@export var default_zoom: float = 1.0  # Neutral default zoom
@export var shake_intensity: float = 0.0

var camera: Camera2D
var target_zoom: float
var arena_bounds: Rect2
var shake_timer: float = 0.0
var shake_duration: float = 0.0
var last_camera_position: Vector2

func _ready() -> void:
	# Camera should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)
	
	# Lock zoom at default level - no zoom controls enabled
	target_zoom = default_zoom
	_connect_signals()

func _connect_signals() -> void:
	EventBus.arena_bounds_changed.connect(_on_arena_bounds_changed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.game_paused_changed.connect(_on_game_paused_changed)
	# Camera follows player automatically as child - no position updates needed

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.arena_bounds_changed.is_connected(_on_arena_bounds_changed):
		EventBus.arena_bounds_changed.disconnect(_on_arena_bounds_changed)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.game_paused_changed.is_connected(_on_game_paused_changed):
		EventBus.game_paused_changed.disconnect(_on_game_paused_changed)
	Logger.debug("CameraSystem: Cleaned up signal connections", "systems")

func setup_camera(player_node: Node2D) -> void:
	if not player_node:
		push_error("CameraSystem: Cannot setup camera - player node is null")
		return
	
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.zoom = Vector2(default_zoom, default_zoom)
	camera.enabled = true
	
	# Camera parented to player for zero-lag, stutter-free following
	# This approach eliminates physics vs render timing issues completely
	camera.position_smoothing_enabled = false  # Not needed with direct parenting
	
	# Add camera as child of player for perfect transform inheritance
	player_node.add_child(camera)
	
	# Initialize position tracking for signal optimization
	last_camera_position = camera.global_position

func _process(delta: float) -> void:
	if not camera:
		return
	
	_update_zoom(delta)
	_update_shake(delta)
	
	# Emit camera moved signal only when position actually changes
	var current_position = camera.global_position
	if current_position != last_camera_position:
		camera_moved.emit(current_position)
		last_camera_position = current_position

func _update_zoom(delta: float) -> void:
	var current_zoom: float = camera.zoom.x
	if abs(current_zoom - target_zoom) > 0.01:
		var new_zoom: float = lerp(current_zoom, target_zoom, zoom_speed * delta)
		camera.zoom = Vector2(new_zoom, new_zoom)
		camera_zoomed.emit(new_zoom)

func _update_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		
		# Calculate shake offset (deterministic RNG stream)
		var shake_offset := Vector2(
			RNG.randf_range("camera_shake", -shake_intensity, shake_intensity),
			RNG.randf_range("camera_shake", -shake_intensity, shake_intensity)
		)
		
		# Apply shake with falloff
		var shake_factor := shake_timer / shake_duration
		camera.offset = shake_offset * shake_factor
		
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO

func _input(_event: InputEvent) -> void:
	# Zoom controls disabled - camera locked at default zoom level
	pass

func zoom_in() -> void:
	# Increase zoom.x to zoom in (Godot: larger zoom -> closer)
	target_zoom = clamp(target_zoom + 0.2, min_zoom, max_zoom)

func zoom_out() -> void:
	# Decrease zoom.x to zoom out (Godot: smaller zoom -> farther)
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
	
	# Use Camera2D built-in limits for cleaner bounds handling
	if camera and bounds != Rect2():
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.position.x + bounds.size.x)
		camera.limit_bottom = int(bounds.position.y + bounds.size.y)

func center_on_position(_position: Vector2) -> void:
	# With parented camera, centering is handled automatically
	# This method exists for API compatibility but does nothing
	pass

func _on_arena_bounds_changed(payload) -> void:
	set_arena_bounds(payload.bounds)


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
