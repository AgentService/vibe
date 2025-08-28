extends Node

## Alternative visual feedback methods for better hit feedback visibility
## Provides scaling, particle, and shader-based alternatives to color modulation

class_name AlternativeVisualFeedback

# Scaling effect for hit feedback (scale pulse)
static func create_scale_pulse_effect(target_node: Node2D, duration: float = 0.2, scale_factor: float = 1.3) -> Tween:
	var tween = target_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	# Scale up quickly, then back down
	tween.parallel().tween_property(target_node, "scale", Vector2.ONE * scale_factor, duration * 0.3)
	tween.tween_property(target_node, "scale", Vector2.ONE, duration * 0.7)
	
	return tween

# Rotation shake effect for hit feedback
static func create_rotation_shake_effect(target_node: Node2D, duration: float = 0.15, shake_angle: float = 15.0) -> Tween:
	var original_rotation = target_node.rotation_degrees
	var tween = target_node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Shake left and right, then return
	tween.tween_property(target_node, "rotation_degrees", original_rotation + shake_angle, duration * 0.2)
	tween.tween_property(target_node, "rotation_degrees", original_rotation - shake_angle, duration * 0.3)
	tween.tween_property(target_node, "rotation_degrees", original_rotation, duration * 0.5)
	
	return tween

# Create particle burst effect for hits
static func create_particle_burst(parent: Node2D, position: Vector2, color: Color = Color.WHITE) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.position = position
	
	# Create particle material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 150.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 0.5
	material.scale_max = 1.5
	material.color = color
	
	particles.process_material = material
	parent.add_child(particles)
	
	# Auto-remove after lifetime
	particles.finished.connect(func(): particles.queue_free())
	
	return particles

# MultiMesh visibility enhancement using brightness instead of color
static func enhance_multimesh_visibility(mm_instance: MultiMeshInstance2D, instance_index: int, intensity: float = 2.0):
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# Use bright colors that multiply well with sprites
	var bright_color = Color(intensity, intensity, intensity, 1.0)
	mm_instance.multimesh.set_instance_color(instance_index, bright_color)

# Create floating damage number (alternative to just color flash)
static func create_damage_number(parent: Node2D, position: Vector2, damage: float, is_crit: bool = false) -> Label:
	var label = Label.new()
	label.text = str(int(damage))
	label.position = position
	label.z_index = 100
	
	# Styling
	if is_crit:
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.scale = Vector2(1.5, 1.5)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
	
	parent.add_child(label)
	
	# Animate floating up and fading
	var tween = label.create_tween()
	tween.parallel().tween_property(label, "position", position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	
	tween.tween_callback(func(): label.queue_free())
	
	return label

# Screen shake effect for impactful hits
static func create_screen_shake(camera: Camera2D, intensity: float = 5.0, duration: float = 0.1):
	if not camera:
		return
	
	var original_offset = camera.offset
	var tween = camera.create_tween()
	
	# Multiple quick shakes
	var shake_count = 6
	for i in shake_count:
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", original_offset + random_offset, duration / shake_count)
	
	# Return to original position
	tween.tween_property(camera, "offset", original_offset, duration * 0.2)

# Create temporary overlay effect for dramatic hits
static func create_flash_overlay(parent: CanvasLayer, color: Color = Color(1, 1, 1, 0.3), duration: float = 0.1):
	var overlay = ColorRect.new()
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.z_index = 1000
	
	parent.add_child(overlay)
	
	# Fade out
	var tween = overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)
	tween.tween_callback(func(): overlay.queue_free())
	
	return overlay