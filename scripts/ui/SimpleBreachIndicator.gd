extends Node2D
class_name SimpleBreachIndicator

## Simplified breach indicator using Godot's built-in transforms
## Shows breach circle when on-screen, arrow at edge when off-screen

@export var indicator_color: Color = Color(1.0, 0.3, 1.0, 0.8)
@export var arrow_size: float = 25.0
@export var edge_margin: float = 40.0

var breach_event: EventInstance
var ui_layer: CanvasLayer
var ui_control: Control

func _ready() -> void:
	# Create a CanvasLayer for UI overlay
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# Create a Control that covers the whole screen for drawing
	ui_control = Control.new()
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_control)

	# Connect drawing
	ui_control.draw.connect(_draw_indicator)

func setup_breach(event: EventInstance) -> void:
	breach_event = event
	global_position = event.center_position

func _process(_delta: float) -> void:
	if breach_event and ui_control:
		ui_control.queue_redraw()

func _draw_indicator() -> void:
	if not breach_event:
		return

	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	# Convert world position to screen position using Godot's built-in transform
	var screen_pos = get_viewport().get_screen_transform() * global_position
	var screen_size = Vector2(get_viewport().size)  # Convert Vector2i to Vector2

	# Check if on-screen (with margin)
	var on_screen = (screen_pos.x > edge_margin and
					 screen_pos.x < screen_size.x - edge_margin and
					 screen_pos.y > edge_margin and
					 screen_pos.y < screen_size.y - edge_margin)

	var edge_pos: Vector2  # Declare outside the blocks for proper scope
	var text_pos: Vector2

	if on_screen:
		# Draw breach circle at screen position
		var radius = breach_event.current_radius
		ui_control.draw_circle(screen_pos, radius, indicator_color * Color(1, 1, 1, 0.3))
		ui_control.draw_arc(screen_pos, radius, 0, TAU, 32, indicator_color, 3.0)
		text_pos = screen_pos + Vector2(0, radius + 20)
	else:
		# Calculate edge position for arrow
		var center = screen_size / 2
		var direction = (screen_pos - center).normalized()

		# Find intersection with screen edge
		edge_pos = _get_edge_position(center, direction, screen_size)

		# Draw arrow pointing toward breach
		var angle = direction.angle()
		var arrow_points = PackedVector2Array()
		arrow_points.append(edge_pos + Vector2.from_angle(angle) * arrow_size)
		arrow_points.append(edge_pos + Vector2.from_angle(angle + 2.5) * arrow_size * 0.7)
		arrow_points.append(edge_pos + Vector2.from_angle(angle - 2.5) * arrow_size * 0.7)

		ui_control.draw_colored_polygon(arrow_points, indicator_color)
		text_pos = edge_pos + Vector2(0, 20)

	# Draw distance text
	var distance = global_position.distance_to(get_viewport().get_camera_2d().global_position)
	var text = "%dm" % int(distance / 10)

	if ui_control.has_theme_font("font"):
		ui_control.draw_string(ui_control.get_theme_font("font"), text_pos, text,
							  HORIZONTAL_ALIGNMENT_CENTER, -1, 16, indicator_color)

func _get_edge_position(center: Vector2, dir: Vector2, size: Vector2) -> Vector2:
	# Calculate intersection with screen edges
	var t_vals = []

	if dir.x != 0:
		t_vals.append((edge_margin - center.x) / dir.x)  # Left edge
		t_vals.append((size.x - edge_margin - center.x) / dir.x)  # Right edge

	if dir.y != 0:
		t_vals.append((edge_margin - center.y) / dir.y)  # Top edge
		t_vals.append((size.y - edge_margin - center.y) / dir.y)  # Bottom edge

	# Find the smallest positive t value
	var min_t = INF
	for t in t_vals:
		if t > 0 and t < min_t:
			min_t = t

	return center + dir * min_t
