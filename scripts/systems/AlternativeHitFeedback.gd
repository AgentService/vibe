extends Node
class_name AlternativeHitFeedback

## Alternative visual feedback methods when MultiMesh color modulation fails
## Uses transform scaling, particles, and screen effects for hit feedback

var wave_director: WaveDirector
var camera: Camera2D

# Effect tracking
var scale_effects: Dictionary = {}
var particle_pool: Array[GPUParticles2D] = []
var available_particles: Array[GPUParticles2D] = []

func _ready() -> void:
	EventBus.damage_applied.connect(_on_damage_applied)
	_create_particle_pool()
	Logger.info("Alternative hit feedback system initialized", "visual")

func setup_references(injected_wave_director: WaveDirector, injected_camera: Camera2D = null) -> void:
	wave_director = injected_wave_director
	camera = injected_camera

func _create_particle_pool() -> void:
	# Pre-create particle systems for hit effects
	for i in range(50):  # Pool of 50 particle systems
		var particles: GPUParticles2D = _create_hit_particle_system()
		particle_pool.append(particles)
		available_particles.append(particles)
		add_child(particles)

func _create_hit_particle_system() -> GPUParticles2D:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.emitting = false
	particles.amount = 15
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.z_index = 100
	
	# Create simple hit particle material
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.angular_velocity_min = -90.0
	material.angular_velocity_max = 90.0
	material.gravity = Vector3(0, 100, 0)
	material.scale_min = 0.3
	material.scale_max = 0.8
	material.color = Color.WHITE
	
	particles.process_material = material
	return particles

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	if payload.target_id.type != EntityId.Type.ENEMY:
		return
	
	var entity_id: String = str(payload.target_id)
	
	# Multiple alternative feedback methods
	_apply_scale_pulse_feedback(entity_id, payload.is_crit)
	_apply_particle_hit_effect(entity_id, payload.is_crit)
	
	# Screen shake for significant hits
	if payload.is_crit or payload.final_damage > 50:
		_apply_screen_shake(payload.final_damage, payload.is_crit)

## SCALE PULSE FEEDBACK ##
func _apply_scale_pulse_feedback(entity_id: String, is_crit: bool) -> void:
	var enemy_pos: Vector2 = _get_enemy_position(entity_id)
	if enemy_pos == Vector2.ZERO:
		return
	
	var scale_factor: float = 1.4 if is_crit else 1.2
	var duration: float = 0.3 if is_crit else 0.2
	
	var scale_data := {
		"timer": 0.0,
		"duration": duration,
		"position": enemy_pos,
		"scale_factor": scale_factor,
		"entity_id": entity_id
	}
	
	scale_effects[entity_id] = scale_data

## PARTICLE HIT EFFECTS ##
func _apply_particle_hit_effect(entity_id: String, is_crit: bool) -> void:
	var enemy_pos: Vector2 = _get_enemy_position(entity_id)
	if enemy_pos == Vector2.ZERO:
		return
	
	var particles: GPUParticles2D = _get_available_particle_system()
	if not particles:
		return
	
	particles.position = enemy_pos
	
	# Customize for crit vs normal hit
	var material: ParticleProcessMaterial = particles.process_material
	if is_crit:
		material.color = Color.YELLOW
		material.scale_max = 1.2
		particles.amount = 25
	else:
		material.color = Color.WHITE
		material.scale_max = 0.8
		particles.amount = 15
	
	particles.emitting = true
	particles.restart()
	
	# Return to pool after effect
	await particles.finished
	_return_particle_to_pool(particles)

func _get_available_particle_system() -> GPUParticles2D:
	if available_particles.is_empty():
		return null
	
	return available_particles.pop_back()

func _return_particle_to_pool(particles: GPUParticles2D) -> void:
	particles.emitting = false
	available_particles.append(particles)

## SCREEN SHAKE ##
func _apply_screen_shake(damage: float, is_crit: bool) -> void:
	if not camera:
		return
	
	var intensity: float = min(damage * 0.05, 8.0)
	if is_crit:
		intensity *= 1.8
	
	var duration: float = 0.12 if is_crit else 0.08
	_create_camera_shake(intensity, duration)

func _create_camera_shake(intensity: float, duration: float) -> void:
	var original_offset: Vector2 = camera.offset
	var tween: Tween = camera.create_tween()
	
	# Multiple quick shakes
	var shake_count: int = 5
	for i in shake_count:
		var random_offset: Vector2 = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", original_offset + random_offset, duration / shake_count)
	
	# Return to original
	tween.tween_property(camera, "offset", original_offset, duration * 0.2)

func _process(delta: float) -> void:
	_update_scale_effects(delta)

func _update_scale_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in scale_effects.keys():
		var scale_data: Dictionary = scale_effects[entity_id]
		scale_data.timer += delta
		
		var progress: float = scale_data.timer / scale_data.duration
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# This would apply visual scaling if we had direct enemy sprite access
		# For MultiMesh, we'd need to modify the transform via set_instance_transform_2d
		_apply_visual_scale_effect(scale_data, progress)
	
	# Clean up
	for entity_id in completed_effects:
		scale_effects.erase(entity_id)

func _apply_visual_scale_effect(scale_data: Dictionary, progress: float) -> void:
	# Placeholder - would need MultiMesh transform access
	# Real implementation would modify enemy transforms directly
	pass

## FLOATING DAMAGE NUMBERS ##
func create_damage_number(position: Vector2, damage: float, is_crit: bool = false) -> void:
	var label: Label = Label.new()
	label.text = str(int(damage))
	label.position = position
	label.z_index = 200
	
	# Style the damage number
	if is_crit:
		label.add_theme_color_override("font_color", Color.ORANGE)
		label.scale = Vector2(1.8, 1.8)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.scale = Vector2(1.2, 1.2)
	
	get_parent().add_child(label)
	
	# Animate floating upward and fade
	var tween: Tween = label.create_tween()
	tween.parallel().tween_property(label, "position", position + Vector2(0, -60), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): label.queue_free())

## UTILITY METHODS ##
func _get_enemy_position(entity_id: String) -> Vector2:
	if not wave_director:
		return Vector2.ZERO
	
	# Extract enemy index from entity_id
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return Vector2.ZERO
	
	var enemy_index: int = parts[1].to_int()
	var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
	
	if enemy_index >= 0 and enemy_index < alive_enemies.size():
		return alive_enemies[enemy_index].pos
	
	return Vector2.ZERO

func get_debug_info() -> String:
	var info: String = "=== Alternative Hit Feedback Debug ===\n"
	info += "Active Scale Effects: %d\n" % scale_effects.size()
	info += "Available Particles: %d/%d\n" % [available_particles.size(), particle_pool.size()]
	info += "Camera Reference: %s\n" % (camera != null)
	info += "Wave Director Reference: %s\n" % (wave_director != null)
	return info