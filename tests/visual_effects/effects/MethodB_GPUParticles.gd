extends GPUParticles2D

# Method B: GPUParticles2D
# Visual effect using GPU-accelerated particles

const BASE_AOE := 150.0

func _ready() -> void:
	# Set basic properties
	amount = 30
	lifetime = 0.8
	one_shot = true

	# Create simple particle texture if none exists
	if not texture:
		texture = _create_particle_texture(16, Color.WHITE)

	# Create process material if not exists
	if not process_material:
		var mat = ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 50.0
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 50.0
		mat.initial_velocity_max = 100.0
		mat.gravity = Vector3.ZERO
		process_material = mat

func configure(params: Dictionary) -> void:
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale
	var scale_val = params.get("scale", 1.0)
	var aoe_radius = params.get("aoe_radius", BASE_AOE)
	var aoe_scale = aoe_radius / BASE_AOE

	scale = Vector2.ONE * scale_val * aoe_scale

	# Update emission radius based on AOE
	if process_material is ParticleProcessMaterial:
		process_material.emission_sphere_radius = 50.0 * aoe_scale

	# Color
	var color = params.get("color", Color.WHITE)
	if process_material is ParticleProcessMaterial:
		process_material.color = color

	# Start emission
	emitting = true

	# Auto-cleanup - wait until in tree
	if is_inside_tree():
		await get_tree().create_timer(lifetime).timeout
		queue_free()
	else:
		# Wait for tree_entered, then cleanup
		await tree_entered
		await get_tree().create_timer(lifetime).timeout
		queue_free()

func _create_particle_texture(size: int, color: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0

	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)  # Gradient fade
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	return ImageTexture.create_from_image(img)
