extends Node

## Enhanced Enemy Hit Feedback System
## Combines multiple visual feedback techniques for maximum visibility and impact
## Addresses color modulation issues with alternative approaches

class_name EnhancedEnemyHitFeedback

# Reference to Arena's MultiMesh instances
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

# Reference to WaveDirector and camera
var wave_director: WaveDirector
var camera: Camera2D

# Visual feedback configuration
var visual_config: VisualFeedbackConfig

# Effect tracking
var flash_effects: Dictionary = {}
var scale_effects: Dictionary = {}

const EnemyRenderTier_Type = preload("res://scripts/systems/EnemyRenderTier.gd")
const AlternativeVisualFeedback = preload("res://scripts/systems/AlternativeVisualFeedback.gd")

func _ready() -> void:
	# Load enhanced visual feedback configuration
	visual_config = load("res://data/balance/visual-feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		Logger.warn("Failed to load visual feedback config, using defaults", "visual")
		visual_config = VisualFeedbackConfig.new()
	
	# Subscribe to damage events
	EventBus.damage_applied.connect(_on_damage_applied)
	
	Logger.info("Enhanced EnemyHitFeedback initialized with improved visibility", "visual")

func setup_references(swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D, injected_camera: Camera2D = null) -> void:
	mm_enemies_swarm = swarm
	mm_enemies_regular = regular
	mm_enemies_elite = elite
	mm_enemies_boss = boss
	camera = injected_camera
	Logger.debug("Enhanced hit feedback references set up", "visual")

func set_wave_director(injected_wave_director: WaveDirector) -> void:
	wave_director = injected_wave_director
	Logger.debug("WaveDirector reference set for enhanced hit feedback", "visual")

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	var target_id: String = str(payload.target_id)
	
	# Only handle enemy entities
	if payload.target_id.type != EntityId.Type.ENEMY:
		return
	
	Logger.debug("Enhanced hit feedback for entity: " + target_id + " (damage: %s)" % payload.final_damage, "visual")
	
	# Multiple feedback techniques for maximum visibility
	_apply_enhanced_flash_effect(target_id, payload.is_crit)
	_apply_scale_pulse_effect(target_id, payload.is_crit)
	_apply_particle_burst_effect(target_id, payload.is_crit)
	
	# Screen shake for critical hits or high damage
	if payload.is_crit or payload.final_damage > 100:
		_apply_screen_shake_effect(payload.final_damage, payload.is_crit)
	
	# Knockback effect
	if payload.knockback_distance > 0.0:
		_apply_knockback_effect(target_id, payload.source_position, payload.knockback_distance)

func _apply_enhanced_flash_effect(entity_id: String, is_crit: bool = false) -> void:
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# Use bright additive colors for high visibility
	var flash_intensity = visual_config.flash_intensity * (2.0 if is_crit else 1.0)
	var flash_color: Color
	
	if is_crit:
		flash_color = Color(3.0, 1.5, 0.5, 1.0)  # Bright orange for crits
	else:
		flash_color = Color(2.5, 2.5, 2.5, 1.0)  # Bright white for normal hits
	
	var flash_data := {
		"timer": 0.0,
		"duration": visual_config.flash_duration * (1.5 if is_crit else 1.0),
		"original_color": Color.WHITE,
		"flash_color": flash_color,
		"mm_instance": mm_instance,
		"instance_index": instance_index
	}
	
	flash_effects[entity_id] = flash_data
	Logger.debug("Enhanced flash started for %s with color %s" % [entity_id, flash_color], "visual")

func _apply_scale_pulse_effect(entity_id: String, is_crit: bool = false) -> void:
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# Scale pulse effect using MultiMesh transform
	var scale_factor = 1.4 if is_crit else 1.2
	var duration = 0.25 if is_crit else 0.18
	
	var scale_data := {
		"timer": 0.0,
		"duration": duration,
		"original_transform": mm_instance.multimesh.get_instance_transform_2d(instance_index),
		"scale_factor": scale_factor,
		"mm_instance": mm_instance,
		"instance_index": instance_index
	}
	
	scale_effects[entity_id] = scale_data

func _apply_particle_burst_effect(entity_id: String, is_crit: bool = false) -> void:
	var enemy_pos = _get_enemy_position(entity_id)
	if enemy_pos == Vector2.ZERO:
		return
	
	var parent = get_parent()
	if not parent:
		return
	
	var color = Color.YELLOW if is_crit else Color.WHITE
	AlternativeVisualFeedback.create_particle_burst(parent, enemy_pos, color)

func _apply_screen_shake_effect(damage: float, is_crit: bool = false) -> void:
	if not camera:
		return
	
	var intensity = min(damage * 0.1, 10.0)  # Scale with damage
	if is_crit:
		intensity *= 1.5
	
	var duration = 0.15 if is_crit else 0.08
	AlternativeVisualFeedback.create_screen_shake(camera, intensity, duration)

func _apply_knockback_effect(entity_id: String, source_pos: Vector2, knockback_distance: float) -> void:
	# This would integrate with the existing knockback system
	# Implementation similar to original but with enhanced visual feedback
	pass

func _process(delta: float) -> void:
	_update_flash_effects(delta)
	_update_scale_effects(delta)

func _update_flash_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in flash_effects.keys():
		var flash_data: Dictionary = flash_effects[entity_id]
		flash_data.timer += delta
		
		var progress: float = flash_data.timer / flash_data.duration
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# Apply enhanced flash with better visibility
		_apply_enhanced_flash_color(flash_data, progress)
	
	# Clean up completed effects
	for entity_id in completed_effects:
		_reset_flash_effect(entity_id)
		flash_effects.erase(entity_id)

func _update_scale_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in scale_effects.keys():
		var scale_data: Dictionary = scale_effects[entity_id]
		scale_data.timer += delta
		
		var progress: float = scale_data.timer / scale_data.duration
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# Apply scale pulse effect
		_apply_scale_transform(scale_data, progress)
	
	# Clean up completed effects
	for entity_id in completed_effects:
		_reset_scale_effect(entity_id)
		scale_effects.erase(entity_id)

func _apply_enhanced_flash_color(flash_data: Dictionary, progress: float) -> void:
	var mm_instance: MultiMeshInstance2D = flash_data.mm_instance
	var instance_index: int = flash_data.instance_index
	
	# Use exponential decay for more dramatic flash
	var intensity = exp(-progress * 4.0)  # Fast fade with exponential curve
	var current_color = Color.WHITE.lerp(flash_data.flash_color, intensity)
	
	mm_instance.multimesh.set_instance_color(instance_index, current_color)

func _apply_scale_transform(scale_data: Dictionary, progress: float) -> void:
	var mm_instance: MultiMeshInstance2D = scale_data.mm_instance
	var instance_index: int = scale_data.instance_index
	var original_transform: Transform2D = scale_data.original_transform
	
	# Elastic scale effect: quick scale up, then bounce back
	var scale_progress: float
	if progress < 0.3:
		scale_progress = progress / 0.3  # Scale up phase
	else:
		scale_progress = 1.0 - ((progress - 0.3) / 0.7)  # Scale down phase
	
	var current_scale = lerp(1.0, scale_data.scale_factor, scale_progress)
	var scaled_transform = original_transform.scaled(Vector2(current_scale, current_scale))
	
	mm_instance.multimesh.set_instance_transform_2d(instance_index, scaled_transform)

func _reset_flash_effect(entity_id: String) -> void:
	var flash_data: Dictionary = flash_effects.get(entity_id, {})
	if flash_data.has("mm_instance"):
		var mm_instance: MultiMeshInstance2D = flash_data.mm_instance
		var instance_index: int = flash_data.instance_index
		mm_instance.multimesh.set_instance_color(instance_index, Color.WHITE)

func _reset_scale_effect(entity_id: String) -> void:
	var scale_data: Dictionary = scale_effects.get(entity_id, {})
	if scale_data.has("mm_instance"):
		var mm_instance: MultiMeshInstance2D = scale_data.mm_instance
		var instance_index: int = scale_data.instance_index
		mm_instance.multimesh.set_instance_transform_2d(instance_index, scale_data.original_transform)

# Helper functions (similar to original implementation)
func _find_enemy_in_multimesh(entity_id: String) -> Dictionary:
	# Implementation similar to original EnemyMultiMeshHitFeedback
	if not wave_director:
		return {}
	
	var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
	# Note: This system needs EnemyRenderTier injection - using fallback for now
	var enemy_render_tier: EnemyRenderTier = null
	if get_parent() and get_parent().has_method("get_enemy_render_tier"):
		enemy_render_tier = get_parent().get_enemy_render_tier()
	if not enemy_render_tier:
		return {}
	
	var tier_groups: Dictionary = enemy_render_tier.group_enemies_by_tier(alive_enemies)
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return {}
	
	var target_enemy_index: int = parts[1].to_int()
	
	# Check each tier (implementation similar to original)
	var swarm_enemies: Array[Dictionary] = tier_groups[EnemyRenderTier_Type.Tier.SWARM]
	for i in range(swarm_enemies.size()):
		if _get_enemy_original_index(swarm_enemies[i]) == target_enemy_index:
			return {"multimesh": mm_enemies_swarm, "index": i}
	
	# Similar checks for other tiers...
	
	return {}

func _get_enemy_original_index(enemy_dict: Dictionary) -> int:
	# Implementation similar to original
	if not wave_director:
		return -1
	
	var enemy_pos: Vector2 = enemy_dict.get("pos", Vector2.ZERO)
	for i in range(wave_director.enemies.size()):
		var enemy: EnemyEntity = wave_director.enemies[i]
		if enemy.alive and enemy.pos.distance_to(enemy_pos) < 1.0:
			return i
	
	return -1

func _get_enemy_position(entity_id: String) -> Vector2:
	# Implementation similar to original
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return Vector2.ZERO
	
	var enemy_index: int = parts[1].to_int()
	if not wave_director:
		return Vector2.ZERO
	
	var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
	for enemy in alive_enemies:
		if enemy.alive and _get_enemy_index_from_array(enemy, alive_enemies) == enemy_index:
			return enemy.pos
	
	return Vector2.ZERO

func _get_enemy_index_from_array(target_enemy: EnemyEntity, enemies: Array[EnemyEntity]) -> int:
	for i in range(enemies.size()):
		if enemies[i] == target_enemy:
			return i
	return -1

func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)