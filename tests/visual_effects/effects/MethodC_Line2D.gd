extends Node2D

# Method C: Line2D (AOE Circle)
# Procedurally generated circle using Line2D

var line: Line2D

func _ready() -> void:
	line = $Line2D
	if line:
		line.width = 5.0
		line.default_color = Color.WHITE

func configure(params: Dictionary) -> void:
	# Ensure line is ready
	if not line:
		line = $Line2D

	if not line:
		push_warning("Line2D node not found")
		queue_free()
		return

	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Generate circle arc
	var aoe_radius = params.get("aoe_radius", 150.0)
	var segments = 32

	line.clear_points()
	for i in segments + 1:  # +1 to close circle
		var angle = float(i) / segments * TAU
		var point = Vector2(cos(angle), sin(angle)) * aoe_radius
		line.add_point(point)

	# Color
	line.default_color = params.get("color", Color.WHITE)

	# Scale (line width)
	var scale_val = params.get("scale", 1.0)
	line.width = 5.0 * scale_val

	# Fade out
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
