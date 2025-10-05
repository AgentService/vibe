extends GPUParticles2D

# Method B: GPUParticles2D
# Visual effect using GPU-accelerated particles

const BASE_AOE := 150.0

func configure(params: Dictionary) -> void:
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale
	var scale_val = params.get("scale", 1.0)
	var aoe_radius = params.get("aoe_radius", BASE_AOE)
	var aoe_scale = aoe_radius / BASE_AOE

	scale = Vector2.ONE * scale_val * aoe_scale

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

	# Color
	var color = params.get("color", Color.WHITE)
	if process_material is ParticleProcessMaterial:
		process_material.color = color

	# Start emission
	emitting = true
	one_shot = true

	# Auto-cleanup
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _ready() -> void:
	# Set basic properties
	amount = 30
	lifetime = 0.8
	one_shot = true
