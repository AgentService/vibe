extends Node2D

# Method A: Sprite2D + Shader
# Visual effect using sprite with shader-based glow

var sprite: Sprite2D

func _ready() -> void:
	sprite = $Sprite2D

	# Use Kenney particle pack or create fallback texture
	if sprite and not sprite.texture:
		var particle_path = "res://assets/effects/kenney_particle-pack/PNG (Transparent)/light_01.png"
		if ResourceLoader.exists(particle_path):
			sprite.texture = load(particle_path)
		else:
			sprite.texture = _create_circle_texture(64, Color.WHITE)

func configure(params: Dictionary) -> void:
	# Ensure sprite is ready
	if not sprite:
		sprite = $Sprite2D
		if sprite and not sprite.texture:
			var particle_path = "res://assets/effects/kenney_particle-pack/PNG (Transparent)/light_01.png"
			if ResourceLoader.exists(particle_path):
				sprite.texture = load(particle_path)
			else:
				sprite.texture = _create_circle_texture(64, Color.WHITE)
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale (visual + AOE)
	if sprite:
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
	else:
		# No sprite - just cleanup after delay
		await get_tree().create_timer(0.5).timeout
		queue_free()

func _create_circle_texture(size: int, color: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0

	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.3  # Soft edges
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(img)
