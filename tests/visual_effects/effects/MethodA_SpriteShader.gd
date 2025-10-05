extends Node2D

# Method A: Sprite2D + Shader
# Visual effect using sprite with shader-based glow

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

func configure(params: Dictionary) -> void:
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale (visual + AOE)
	var scale_val = params.get("scale", 1.0)
	var aoe_radius = params.get("aoe_radius", 150.0)
	var aoe_scale = aoe_radius / 150.0  # Base radius: 150px
	sprite.scale = Vector2.ONE * scale_val * aoe_scale

	# Color
	var color = params.get("color", Color.WHITE)
	sprite.modulate = color

	# Simple fade animation (we'll add shader later)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
