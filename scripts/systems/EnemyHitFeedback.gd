extends Node

## Enemy hit feedback component - handles flash and knockback effects
## Subscribes to EventBus damage signals and applies visual feedback
## Isolated, reusable component with no AI coupling

class_name EnemyHitFeedback

@export var feedback_config: VisualFeedbackConfig
@export var target_sprite: Sprite2D
@export var target_body: CharacterBody2D

var original_modulate: Color
var flash_tween: Tween
var knockback_tween: Tween
var knockback_velocity: Vector2 = Vector2.ZERO

# Entity tracking
var entity_id: String = ""
var is_scene_boss: bool = false

func _ready() -> void:
	# Load default config if not provided
	if not feedback_config:
		feedback_config = preload("res://data/balance/visual-feedback.tres")
	
	# Store original sprite color
	if target_sprite:
		original_modulate = target_sprite.modulate
	
	# Connect to damage signals
	EventBus.damage_applied.connect(_on_damage_applied)
	
	if Logger.is_debug():
		Logger.debug("EnemyHitFeedback initialized for entity: " + entity_id, "visual")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)
	
	# Clean up tweens
	if flash_tween:
		flash_tween.kill()
	if knockback_tween:
		knockback_tween.kill()
	
	if Logger.is_debug():
		Logger.debug("EnemyHitFeedback cleaned up for entity: " + entity_id, "visual")

func setup(entity_identifier: String, sprite: Sprite2D, body: CharacterBody2D = null, is_boss: bool = false) -> void:
	"""Setup the hit feedback component with target references"""
	entity_id = entity_identifier
	target_sprite = sprite
	target_body = body
	is_scene_boss = is_boss
	
	if target_sprite:
		original_modulate = target_sprite.modulate
	
	if Logger.is_debug():
		Logger.debug("EnemyHitFeedback setup for: " + entity_id, "visual")

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	"""Handle damage applied signal and trigger appropriate feedback"""
	# Check if this damage is for our entity
	var target_entity_id: String = str(payload.target_id)
	if target_entity_id != entity_id:
		return
	
	if Logger.is_debug():
		Logger.debug("Hit feedback triggered for: " + entity_id + " (damage: " + str(payload.final_damage) + ")", "visual")
	
	# Trigger flash effect
	_trigger_flash_effect(payload.is_crit)
	
	# Trigger knockback effect if knockback distance > 0
	if payload.knockback_distance > 0.0:
		_trigger_knockback_effect(payload.knockback_distance, payload.source_position)

func _trigger_flash_effect(is_critical: bool = false) -> void:
	"""Trigger white flash effect on the sprite"""
	if not target_sprite or not feedback_config:
		return
	
	# Kill existing flash tween
	if flash_tween:
		flash_tween.kill()
	
	# Create new tween
	flash_tween = create_tween()
	flash_tween.set_ease(Tween.EASE_OUT)
	flash_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Flash intensity (higher for crits)
	var flash_intensity: float = feedback_config.flash_intensity
	if is_critical:
		flash_intensity *= 1.5
	
	# Flash to white
	var flash_color = Color(1.0 + flash_intensity, 1.0 + flash_intensity, 1.0 + flash_intensity, original_modulate.a)
	target_sprite.modulate = flash_color
	
	# Tween back to original color
	var total_duration = feedback_config.flash_duration + feedback_config.flash_fade_duration
	flash_tween.tween_method(_update_flash_color, 1.0, 0.0, total_duration)
	
	# Ensure we end at original color
	flash_tween.tween_callback(_reset_sprite_color)

func _update_flash_color(progress: float) -> void:
	"""Update flash color during tween"""
	if not target_sprite:
		return
	
	# Use curve if available, otherwise linear interpolation
	var curve_value: float = progress
	if feedback_config.flash_curve:
		curve_value = feedback_config.flash_curve.sample(1.0 - progress)
	else:
		curve_value = 1.0 - progress
	
	# Interpolate between flash color and original
	var flash_intensity = feedback_config.flash_intensity * curve_value
	var current_color = Color(
		original_modulate.r + flash_intensity,
		original_modulate.g + flash_intensity,
		original_modulate.b + flash_intensity,
		original_modulate.a
	)
	
	target_sprite.modulate = current_color

func _reset_sprite_color() -> void:
	"""Reset sprite to original color"""
	if target_sprite:
		target_sprite.modulate = original_modulate

func _trigger_knockback_effect(knockback_distance: float, source_position: Vector2) -> void:
	"""Trigger knockback effect on the entity"""
	if not target_body and not is_scene_boss:
		Logger.warn("No target body for knockback on entity: " + entity_id, "visual")
		return
	
	# Calculate knockback direction
	var entity_position: Vector2
	if target_body:
		entity_position = target_body.global_position
	elif target_sprite:
		entity_position = target_sprite.global_position
	else:
		Logger.warn("No position reference for knockback on entity: " + entity_id, "visual")
		return
	
	var knockback_direction = (entity_position - source_position).normalized()
	if knockback_direction.length() < 0.1:
		# Fallback to random direction if positions are too close
		knockback_direction = Vector2(RNG.randf_range("knockback", -1.0, 1.0), RNG.randf_range("knockback", -1.0, 1.0)).normalized()
	
	# Calculate knockback velocity
	var knockback_force = knockback_distance / feedback_config.knockback_duration
	knockback_velocity = knockback_direction * knockback_force
	
	# Kill existing knockback tween
	if knockback_tween:
		knockback_tween.kill()
	
	# Create knockback tween
	knockback_tween = create_tween()
	knockback_tween.set_ease(Tween.EASE_OUT)
	knockback_tween.set_trans(Tween.TRANS_QUAD)
	
	# Tween knockback velocity to zero
	knockback_tween.tween_method(_apply_knockback, 1.0, 0.0, feedback_config.knockback_duration)
	knockback_tween.tween_callback(_reset_knockback)
	
	if Logger.is_debug():
		Logger.debug("Knockback applied to " + entity_id + ": " + str(knockback_distance) + " pixels", "visual")

func _apply_knockback(intensity: float) -> void:
	"""Apply knockback movement during tween"""
	if not target_body and not is_scene_boss:
		return
	
	# Use curve if available
	var curve_value: float = intensity
	if feedback_config.knockback_curve:
		curve_value = feedback_config.knockback_curve.sample(intensity)
	
	var current_velocity = knockback_velocity * curve_value
	
	# Apply to scene boss (CharacterBody2D)
	if is_scene_boss and target_body:
		target_body.velocity += current_velocity * get_process_delta_time()
	
	# For pooled enemies, we need to update their position in the WaveDirector
	# This will be handled by the WaveDirector integration

func _reset_knockback() -> void:
	"""Reset knockback state"""
	knockback_velocity = Vector2.ZERO
	if Logger.is_debug():
		Logger.debug("Knockback reset for entity: " + entity_id, "visual")

func get_knockback_velocity() -> Vector2:
	"""Get current knockback velocity for external systems"""
	return knockback_velocity

func is_being_knocked_back() -> bool:
	"""Check if entity is currently being knocked back"""
	return knockback_tween != null and knockback_tween.is_valid()
