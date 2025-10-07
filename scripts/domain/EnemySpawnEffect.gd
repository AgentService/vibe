extends RefCounted
class_name EnemySpawnEffect

## Handles enemy spawn dissolve animation
## Applies shader material and tweens dissolve_progress from 1.0 (invisible) to 0.0 (visible)

const SPAWN_DURATION = 0.6  # Seconds for full spawn animation
const EDGE_GLOW_COLOR = Color(0.0, 1.0, 1.0, 1.0)  # Cyan edge glow

static var _spawn_material: ShaderMaterial = null
static var _noise_texture: NoiseTexture2D = null

## Initialize shared resources (call once at game start)
static func initialize() -> void:
	if _spawn_material:
		return  # Already initialized

	# Create procedural noise texture
	_noise_texture = _create_noise_texture()

	# Load spawn dissolve shader
	var shader = load("res://shaders/enemy_spawn_dissolve.gdshader") as Shader
	if not shader:
		Logger.warn("Failed to load enemy spawn dissolve shader", "effects")
		return

	# Create material with shader
	_spawn_material = ShaderMaterial.new()
	_spawn_material.shader = shader
	_spawn_material.set_shader_parameter("noise_texture", _noise_texture)
	_spawn_material.set_shader_parameter("edge_color", EDGE_GLOW_COLOR)
	_spawn_material.set_shader_parameter("edge_width", 0.08)
	_spawn_material.set_shader_parameter("noise_scale", 2.0)
	_spawn_material.set_shader_parameter("dissolve_progress", 1.0)  # Start invisible

	Logger.info("EnemySpawnEffect initialized", "effects")

## Apply spawn effect to an enemy sprite
## Returns the tween for external tracking if needed
static func apply_spawn_effect(sprite: AnimatedSprite2D, scene_tree: SceneTree) -> Tween:
	if not _spawn_material:
		Logger.warn("EnemySpawnEffect not initialized, call initialize() first", "effects")
		return null

	if not sprite or not is_instance_valid(sprite):
		return null

	# Save original material
	var original_material = sprite.material
	sprite.set_meta("_enemy_original_material", original_material)

	# Apply spawn dissolve material
	var material_instance = _spawn_material.duplicate() as ShaderMaterial

	# Check if sprite already has modulate applied (e.g., breach enemies)
	if sprite.modulate != Color.WHITE:
		material_instance.set_shader_parameter("modulate_tint", sprite.modulate)
		Logger.debug("Applied sprite modulate to shader: %s" % sprite.modulate, "events")

	sprite.material = material_instance

	# Tween dissolve from 1.0 (invisible) to 0.0 (fully visible)
	var tween = scene_tree.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Use sprite.material directly instead of capturing material_instance
	tween.tween_method(
		func(value: float):
			if is_instance_valid(sprite) and sprite.material:
				sprite.material.set_shader_parameter("dissolve_progress", value),
		1.0,  # Start fully dissolved (invisible)
		0.0,  # End fully materialized (visible)
		SPAWN_DURATION
	)

	# Restore original material after spawn completes
	tween.finished.connect(func():
		if is_instance_valid(sprite):
			var orig = sprite.get_meta("_enemy_original_material", null)
			sprite.material = orig
			Logger.debug("Enemy spawn effect completed", "effects")
	)

	return tween

## Create procedural noise texture for dissolve pattern
static func _create_noise_texture() -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	var noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.width = 256
	noise_texture.height = 256
	noise_texture.seamless = true
	noise_texture.normalize = true

	return noise_texture
