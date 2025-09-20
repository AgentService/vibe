@tool
extends Node2D
class_name BreachIndicator

## Scene-based breach visual indicator with expanding purple circle
## Editor-friendly: You can adjust colors, timing, and effects in the Godot editor
## Connected to EventInstance for automatic lifecycle updates

@export_group("Visual Settings")
@export var waiting_color: Color = Color(0.6, 0.2, 0.8, 0.4)  # Faded purple while waiting
@export var expanding_color: Color = Color(0.8, 0.3, 1.0, 0.6)  # Bright purple during expansion
@export var shrinking_color: Color = Color(1.0, 0.4, 0.9, 0.8)  # Very visible during cleanup
@export var border_width: float = 3.0
@export var fill_alpha: float = 0.3
@export var editor_preview_radius: float = 100.0  # Size to show in editor for visibility

@export_group("Animation Settings")
@export var pulse_speed: float = 4.0  # How fast the waiting circle pulses
@export var expansion_curve: Curve  # Editor-tweakable expansion curve
@export var shrink_curve: Curve     # Editor-tweakable shrink curve

@export_group("Effects")
@export var enable_particles: bool = true
@export var particle_scene: PackedScene  # Drag particle scene in editor
@export var enable_sound: bool = true
@export var activation_sound: AudioStream  # Drag sound file in editor

@export_group("Off-Screen Indicators")
@export var enable_offscreen_arrows: bool = true
@export var arrow_color: Color = Color(1.0, 0.3, 1.0, 1.0)  # Bright purple arrow
@export var arrow_size: float = 30.0
@export var arrow_distance_from_edge: float = 50.0
@export var arrow_pulse: bool = true
@export var arrow_smooth_speed: float = 8.0  # How fast arrow moves between positions

# Internal state
var breach_event: EventInstance
var pulse_timer: float = 0.0
var particle_emitter: Node2D
var screen_indicator: Control  # Off-screen indicator UI
var current_arrow_position: Vector2 = Vector2.ZERO  # Smooth arrow position tracking

func _ready() -> void:
	# Set up particle effects if enabled
	if enable_particles and particle_scene:
		particle_emitter = particle_scene.instantiate()
		add_child(particle_emitter)

	# Create off-screen indicator on UI layer
	if enable_offscreen_arrows:
		_create_screen_indicator()

func setup_breach(event_instance: EventInstance) -> void:
	"""Connect this visual indicator to a breach event instance"""
	breach_event = event_instance
	global_position = breach_event.center_position

	# Use config from EventInstance if available
	if breach_event.config:
		pulse_speed = breach_event.config.pulse_speed

	# Ensure the Node2D stays at the breach position for collision detection
	# The visual representation is now drawn in world-space via _draw()

	# Initialize default curves if not set in editor (temporarily simplified)
	# TODO: Re-enable curve initialization once parser errors are resolved

var last_phase: EventInstance.Phase = EventInstance.Phase.WAITING
var last_camera_pos: Vector2 = Vector2.ZERO
var is_animating: bool = false

func _process(dt: float) -> void:
	if not breach_event:
		return

	# IMPORTANT: Do NOT update global_position here - breach should stay at fixed location!
	# The Node2D position represents the breach's world location for collision detection

	# Only update when phase changes
	if breach_event.phase != last_phase:
		_on_phase_changed(last_phase, breach_event.phase)
		last_phase = breach_event.phase

	# Continuous redraw ONLY during active animations for world-space circle
	if is_animating:
		queue_redraw()  # Redraw world-space circle
		if screen_indicator:
			screen_indicator.queue_redraw()  # Redraw screen-space arrows
	# Only update screen indicator when camera moves significantly (more than 10 pixels)
	elif screen_indicator:
		var camera = get_viewport().get_camera_2d() if get_viewport() else null
		if camera:
			var camera_pos = camera.global_position
			if camera_pos.distance_to(last_camera_pos) > 10:
				last_camera_pos = camera_pos
				screen_indicator.queue_redraw()

	# Update pulse animation for waiting state - smoother updates
	if breach_event.phase == EventInstance.Phase.WAITING:
		pulse_timer += dt * pulse_speed
		# Redraw for pulse more frequently for smoother animation
		if int(pulse_timer * 30) % 3 == 0:  # Update every 3rd frame at 30Hz
			queue_redraw()  # Redraw world-space circle for pulse
			screen_indicator.queue_redraw() if screen_indicator else null

func _on_phase_changed(old_phase: EventInstance.Phase, new_phase: EventInstance.Phase) -> void:
	"""Handle phase transitions - set animation flag instead of using Tweens"""

	match new_phase:
		EventInstance.Phase.EXPANDING:
			# Trigger activation effects once
			_trigger_activation_effects()
			# Enable continuous redraw during expansion
			is_animating = true

		EventInstance.Phase.SHRINKING:
			# Enable continuous redraw during shrinking
			is_animating = true

		EventInstance.Phase.WAITING:
			# Stop animating, draw once
			is_animating = false
			if screen_indicator:
				screen_indicator.queue_redraw()

		EventInstance.Phase.COMPLETED:
			# Stop animating, final redraw
			is_animating = false
			if screen_indicator:
				screen_indicator.queue_redraw()

func _draw() -> void:
	# Show preview in editor even without breach event
	if Engine.is_editor_hint():
		var preview_color = waiting_color
		draw_circle(Vector2.ZERO, editor_preview_radius, preview_color * Color(1, 1, 1, fill_alpha))
		draw_arc(Vector2.ZERO, editor_preview_radius, 0, TAU, 32, preview_color, border_width)
		return

	# Draw breach circle in world-space (will render below entities naturally)
	if not breach_event:
		return

	var breach_radius = _get_current_visual_radius()
	var breach_color = _get_current_color()

	# Draw filled circle
	var fill_color = breach_color * Color(1, 1, 1, fill_alpha)
	draw_circle(Vector2.ZERO, breach_radius, fill_color)

	# Draw border
	draw_arc(Vector2.ZERO, breach_radius, 0, TAU, 32, breach_color, border_width)

func _get_current_visual_radius() -> float:
	"""Get the current visual radius based on breach state and editor curves"""
	match breach_event.phase:
		EventInstance.Phase.WAITING:
			# Pulse effect while waiting
			var pulse_factor = 1.0 + sin(pulse_timer) * 0.1  # 10% size variation
			return breach_event.initial_radius * pulse_factor

		EventInstance.Phase.EXPANDING:
			# Simple linear expansion (temporarily simplified)
			var progress = breach_event.phase_timer / breach_event.expand_duration
			return lerp(breach_event.initial_radius, breach_event.max_radius, progress)

		EventInstance.Phase.SHRINKING:
			# Simple linear shrinking (temporarily simplified)
			var progress = breach_event.phase_timer / breach_event.shrink_duration
			return lerp(breach_event.max_radius, breach_event.initial_radius, progress)

		EventInstance.Phase.COMPLETED:
			return breach_event.initial_radius

		_:
			return breach_event.current_radius

func _get_current_color() -> Color:
	"""Get current color based on breach phase"""
	match breach_event.phase:
		EventInstance.Phase.WAITING:
			return waiting_color
		EventInstance.Phase.EXPANDING:
			return expanding_color
		EventInstance.Phase.SHRINKING:
			return shrinking_color
		EventInstance.Phase.COMPLETED:
			return waiting_color
		_:
			return waiting_color

func _trigger_activation_effects() -> void:
	"""Trigger visual and audio effects when breach activates"""

	# Play activation sound
	if enable_sound and activation_sound:
		var audio_player = AudioStreamPlayer2D.new()
		add_child(audio_player)
		audio_player.stream = activation_sound
		audio_player.play()
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())

	# Start particle effects
	if enable_particles and particle_emitter:
		if particle_emitter.has_method("restart"):
			particle_emitter.restart()
		elif particle_emitter.has_method("emitting"):
			particle_emitter.emitting = true

	Logger.debug("Breach activation effects triggered", "events")

func get_breach_progress() -> float:
	"""Get breach progress for external UI systems"""
	return breach_event.get_progress() if breach_event else 0.0

func is_breach_active() -> bool:
	"""Check if breach is currently active (expanding or shrinking)"""
	if not breach_event:
		return false
	return breach_event.phase in [EventInstance.Phase.EXPANDING, EventInstance.Phase.SHRINKING]

func _create_screen_indicator() -> void:
	"""Create off-screen arrow indicator on UI layer"""
	# Don't create in editor
	if Engine.is_editor_hint():
		return

	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "BreachScreenIndicator"
	canvas_layer.layer = 0  # Same layer as game objects
	add_child(canvas_layer)

	screen_indicator = Control.new()
	screen_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(screen_indicator)

	# Connect drawing
	screen_indicator.draw.connect(_draw_screen_indicator)


func _draw_screen_indicator() -> void:
	"""Draw unified indicator that transitions from arrow to breach circle"""
	if not breach_event or not screen_indicator:
		return

	# Don't draw if not in tree yet
	if not is_inside_tree() or not screen_indicator.is_inside_tree():
		return

	var viewport = get_viewport()
	if not viewport or not viewport.get_visible_rect().has_area():
		return

	var camera = viewport.get_camera_2d()
	if not camera:
		return

	var screen_size = Vector2(viewport.size)  # Convert Vector2i to Vector2
	var screen_center = screen_size / 2


	# Calculate the breach's position in screen coordinates
	# Use the camera's transform to convert world to screen
	var camera_transform = camera.get_canvas_transform()
	var breach_screen_pos = camera_transform * global_position

	# Calculate if breach is within screen bounds
	var edge_margin = arrow_distance_from_edge
	var screen_rect = Rect2(Vector2(edge_margin, edge_margin),
							screen_size - Vector2(edge_margin * 2, edge_margin * 2))
	var is_breach_on_screen = screen_rect.has_point(breach_screen_pos)

	# Get breach state for visual
	var breach_radius = _get_current_visual_radius() if breach_event else 30.0
	var breach_color = _get_current_color() if breach_event else waiting_color
	var edge_position: Vector2  # Declare here for proper scope

	# Check if breach is active (expanding or shrinking)
	var is_breach_active = breach_event.phase in [EventInstance.Phase.EXPANDING, EventInstance.Phase.SHRINKING]

	# Only draw screen-space elements for waiting breaches when off-screen
	# The breach circle itself is now drawn in world-space via _draw()
	if false:  # Disable on-screen circle drawing in screen space
		pass
	elif breach_event.phase == EventInstance.Phase.WAITING and not is_breach_on_screen:
		# BREACH IS OFF SCREEN AND WAITING - Draw arrow at edge pointing toward it
		var direction = (breach_screen_pos - screen_center).normalized()
		edge_position = _get_edge_position(screen_center, direction, screen_size, edge_margin)

		# Calculate arrow angle to point toward breach
		var arrow_angle = direction.angle()

		# Create arrow shape
		var arrow_points: PackedVector2Array = []
		var tip = edge_position + Vector2.from_angle(arrow_angle) * arrow_size
		var base1 = edge_position + Vector2.from_angle(arrow_angle + 2.5) * arrow_size * 0.7
		var base2 = edge_position + Vector2.from_angle(arrow_angle - 2.5) * arrow_size * 0.7

		arrow_points.append(tip)
		arrow_points.append(base1)
		arrow_points.append(base2)

		# Apply pulsing effect
		var final_color = breach_color
		if arrow_pulse:
			final_color.a = 0.6 + sin(pulse_timer * 1.5) * 0.4

		# Draw the arrow
		screen_indicator.draw_colored_polygon(arrow_points, final_color)

	# Draw distance text only for waiting breaches (remove after activation)
	if breach_event.phase == EventInstance.Phase.WAITING:
		var distance = global_position.distance_to(PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO)
		var distance_text = "%dm" % int(distance / 10)  # Assuming 10 units = 1 meter

		# Position text appropriately (waiting breaches only)
		var text_position: Vector2
		if is_breach_on_screen:
			text_position = breach_screen_pos + Vector2(0, breach_radius + 20)
		else:
			text_position = edge_position + Vector2(0, arrow_size + 15)

		# Use theme font if available
		if screen_indicator.has_theme_font("font"):
			var font = screen_indicator.get_theme_font("font")
			screen_indicator.draw_string(font, text_position, distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, arrow_color)
		elif ThemeDB.fallback_font:
			screen_indicator.draw_string(ThemeDB.fallback_font, text_position, distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, arrow_color)

func _get_edge_position(center: Vector2, direction: Vector2, screen_size: Vector2, margin: float) -> Vector2:
	"""Calculate where arrow should be drawn on screen edge"""
	var edge_x = screen_size.x - margin if direction.x > 0 else margin
	var edge_y = screen_size.y - margin if direction.y > 0 else margin

	# Find intersection with screen edge
	var t_x = abs((edge_x - center.x) / direction.x) if direction.x != 0 else INF
	var t_y = abs((edge_y - center.y) / direction.y) if direction.y != 0 else INF

	var t = min(t_x, t_y)
	return center + direction * t
