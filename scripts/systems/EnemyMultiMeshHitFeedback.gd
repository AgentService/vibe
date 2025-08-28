extends Node

## Hit feedback system for MultiMesh-rendered enemies.
## Handles flash effects and knockback for enemies rendered via MultiMesh instances.

class_name EnemyMultiMeshHitFeedback

# Reference to Arena's MultiMesh instances
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

# Reference to WaveDirector (injected by Arena)
var wave_director: WaveDirector

# Reference to EnemyRenderTier (injected by Arena)
var enemy_render_tier: EnemyRenderTier

# Visual feedback configuration
var visual_config: VisualFeedbackConfig

# Flash effect tracking
var flash_effects: Dictionary = {}  # entity_id -> flash_data
var knockback_effects: Dictionary = {}  # entity_id -> knockback_data

# Enemy tier mapping for MultiMesh access !without vibe folder!!!
const EnemyRenderTier_Type = preload("res://scripts/systems/EnemyRenderTier.gd")

func _ready() -> void:
	# Load visual feedback configuration
	visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		Logger.warn("Failed to load visual feedback config, using defaults", "enemies")
		visual_config = VisualFeedbackConfig.new()
		# Set enhanced flash values for better visibility
		visual_config.flash_duration = 0.18
		visual_config.flash_intensity = 4.0  # Much brighter
		visual_config.flash_color = Color(3.0, 3.0, 3.0, 1.0)  # Pure bright white
		visual_config.knockback_duration = 0.25
	
	# Subscribe to damage events
	EventBus.damage_applied.connect(_on_damage_applied)
	
	# Add periodic cleanup timer to prevent accumulation over time
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 30.0  # Clean up every 30 seconds
	cleanup_timer.timeout.connect(_periodic_cleanup)
	add_child(cleanup_timer)
	cleanup_timer.start()
	
	Logger.info("EnemyMultiMeshHitFeedback initialized with periodic cleanup", "enemies")

func setup_multimesh_references(swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D) -> void:
	mm_enemies_swarm = swarm
	mm_enemies_regular = regular
	mm_enemies_elite = elite
	mm_enemies_boss = boss
	Logger.debug("MultiMesh references set up for hit feedback", "enemies")

func set_wave_director(injected_wave_director: WaveDirector) -> void:
	wave_director = injected_wave_director
	Logger.debug("WaveDirector reference set for hit feedback", "enemies")

func set_enemy_render_tier(injected_enemy_render_tier: EnemyRenderTier) -> void:
	enemy_render_tier = injected_enemy_render_tier
	Logger.debug("EnemyRenderTier reference set for hit feedback", "enemies")

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	var target_id: String = str(payload.target_id)
	
	# Only handle enemy entities
	if payload.target_id.type != EntityId.Type.ENEMY:
		return
	
	Logger.debug("Processing hit feedback for entity: " + target_id, "enemies")
	
	# Start flash effect
	_start_flash_effect(target_id)
	
	# Start knockback effect if knockback distance > 0
	if payload.knockback_distance > 0.0:
		_start_knockback_effect(target_id, payload.source_position, payload.knockback_distance)

func _start_flash_effect(entity_id: String) -> void:
	var flash_data := {
		"timer": 0.0,
		"duration": visual_config.flash_duration,
		"original_color": Color.WHITE,
		"flash_color": visual_config.flash_color
	}
	
	Logger.debug("Flash effect config - Duration: %s, Flash color: %s, Original: %s" % [flash_data.duration, flash_data.flash_color, flash_data.original_color], "visual")
	
	flash_effects[entity_id] = flash_data
	Logger.debug("Started flash effect for " + entity_id, "enemies")

func _start_knockback_effect(entity_id: String, source_pos: Vector2, knockback_distance: float) -> void:
	# Clean up any existing knockback effect for this entity first
	if knockback_effects.has(entity_id):
		knockback_effects.erase(entity_id)
	
	# Get enemy position from WaveDirector
	var enemy_pos: Vector2 = _get_enemy_position(entity_id)
	if enemy_pos == Vector2.ZERO:
		Logger.warn("Could not find enemy position for knockback: " + entity_id, "enemies")
		return
	
	# Calculate knockback direction with better fallback handling
	var direction_vector = enemy_pos - source_pos
	var knockback_dir: Vector2
	
	if direction_vector.length() < 0.1:
		# If source and target are too close, use a random direction
		var angle = randf() * TAU
		knockback_dir = Vector2(cos(angle), sin(angle))
	else:
		knockback_dir = direction_vector.normalized()
	
	# Enhanced organic knockback system with distance-based scaling
	var knockback_force = knockback_distance * 2.0  # Reduced multiplier for better control
	var initial_velocity = knockback_dir * knockback_force
	
	# Cap maximum velocity to prevent extreme knockback
	if initial_velocity.length() > 150:
		initial_velocity = initial_velocity.normalized() * 150
	
	var knockback_data := {
		"timer": 0.0,
		"duration": visual_config.knockback_duration * 2.0,  # Longer for organic decay
		"start_pos": enemy_pos,
		"current_pos": enemy_pos,
		"velocity": initial_velocity,
		"entity_id": entity_id,
		"hit_stop_duration": 0.05,  # Brief hit-stop for enemies
		"hit_stop_timer": 0.0
	}
	
	knockback_effects[entity_id] = knockback_data
	Logger.debug("Started organic knockback for " + entity_id + " force: " + str(knockback_force) + ", direction: " + str(knockback_dir), "enemies")

func _get_enemy_position(entity_id: String) -> Vector2:
	# Extract enemy index from entity_id (format: "ENEMY:X")
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return Vector2.ZERO
	
	var enemy_index: int = parts[1].to_int()
	
	# Get position from injected WaveDirector
	if not wave_director:
		Logger.warn("WaveDirector not injected for hit feedback", "enemies")
		return Vector2.ZERO
	
	# Direct lookup by enemy index (more reliable)
	if enemy_index >= 0 and enemy_index < wave_director.enemies.size():
		var enemy: EnemyEntity = wave_director.enemies[enemy_index]
		if enemy.alive:
			return enemy.pos
	
	return Vector2.ZERO

func _get_enemy_index_from_array(target_enemy: EnemyEntity, enemies: Array[EnemyEntity]) -> int:
	for i in range(enemies.size()):
		if enemies[i] == target_enemy:
			return i
	return -1

func _process(delta: float) -> void:
	_update_flash_effects(delta)
	_update_knockback_effects(delta)

func _update_flash_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in flash_effects.keys():
		var flash_data: Dictionary = flash_effects[entity_id]
		flash_data.timer += delta
		
		var progress: float = flash_data.timer / flash_data.duration
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# Apply flash effect to MultiMesh instance
		_apply_flash_to_multimesh(entity_id, progress, flash_data)
	
	# Clean up completed effects
	for entity_id in completed_effects:
		_reset_enemy_color(entity_id)
		flash_effects.erase(entity_id)

func _update_knockback_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	var invalid_effects: Array[String] = []
	
	for entity_id in knockback_effects.keys():
		# Validate effect data exists
		if not knockback_effects.has(entity_id):
			invalid_effects.append(entity_id)
			continue
			
		var knockback_data: Dictionary = knockback_effects[entity_id]
		
		# Validate enemy still exists and is alive
		if not _is_enemy_still_valid(entity_id):
			Logger.debug("Cleaning up knockback for dead/invalid enemy: " + entity_id, "enemies")
			invalid_effects.append(entity_id)
			continue
		
		# Additional validation: check if enemy moved too far from start (indicates respawn/reuse)
		var current_enemy_pos = _get_enemy_position(entity_id)
		if current_enemy_pos != Vector2.ZERO:
			var distance_from_start = current_enemy_pos.distance_to(knockback_data.start_pos)
			if distance_from_start > 500:  # Enemy was likely respawned/reused
				Logger.debug("Enemy " + entity_id + " moved too far from knockback start, cleaning up", "enemies")
				invalid_effects.append(entity_id)
				continue
		
		knockback_data.timer += delta
		var progress: float = knockback_data.timer / knockback_data.duration
		
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# Apply knockback position to enemy
		_apply_knockback_position(entity_id, progress, knockback_data)
	
	# Clean up completed and invalid effects
	for entity_id in completed_effects:
		knockback_effects.erase(entity_id)
	for entity_id in invalid_effects:
		knockback_effects.erase(entity_id)
	
	# Safety cleanup: limit max concurrent effects to prevent memory issues
	if knockback_effects.size() > 500:
		Logger.warn("Knockback effects exceeded 500, performing emergency cleanup", "performance")
		_cleanup_oldest_effects()

func _apply_flash_to_multimesh(entity_id: String, progress: float, flash_data: Dictionary) -> void:
	# Find enemy in MultiMesh and apply color
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# Calculate flash color using curve - invert for proper flash effect
	var curve_value: float = visual_config.flash_curve.sample(progress) if visual_config.flash_curve else (1.0 - progress)
	var flash_intensity: float = curve_value * visual_config.flash_intensity
	
	# Additive flash effect for maximum visibility
	var base_color: Color = flash_data.original_color
	var flash_color: Color = flash_data.flash_color
	var current_color: Color = base_color + (flash_color * flash_intensity)
	
	# Debug color application
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Flash progress %s: curve_value=%s, intensity=%s, color=%s" % [progress, curve_value, flash_intensity, current_color], "visual")
	
	# Apply color to MultiMesh instance
	mm_instance.multimesh.set_instance_color(instance_index, current_color)

func _apply_knockback_position(entity_id: String, progress: float, knockback_data: Dictionary) -> void:
	# Hit-stop effect for impact feel
	if knockback_data.hit_stop_timer < knockback_data.hit_stop_duration:
		knockback_data.hit_stop_timer += get_process_delta_time()
		return  # Don't move during hit-stop
	
	# Organic velocity-based knockback with decay
	var decay_factor = 0.92  # Slower decay for enemies (92% retained)
	var min_velocity_threshold = 5.0  # Lower threshold for lighter enemies
	
	# Apply velocity decay
	knockback_data.velocity *= decay_factor
	
	# Stop if velocity is too small
	if knockback_data.velocity.length() < min_velocity_threshold:
		knockback_data.velocity = Vector2.ZERO
		return  # Exit early if no movement needed
	
	# Update position based on current velocity
	var delta = get_process_delta_time()
	var new_pos = knockback_data.current_pos + knockback_data.velocity * delta
	
	# Validate the new position is reasonable
	if new_pos.distance_to(knockback_data.current_pos) > 100:
		Logger.warn("Excessive knockback velocity detected for " + entity_id + ": " + str(knockback_data.velocity), "enemies")
		knockback_data.velocity *= 0.1  # Emergency velocity reduction
		new_pos = knockback_data.current_pos + knockback_data.velocity * delta
	
	knockback_data.current_pos = new_pos
	
	# Update enemy position in WaveDirector
	_update_enemy_position(entity_id, knockback_data.current_pos)

func _update_enemy_position(entity_id: String, new_pos: Vector2) -> void:
	# Extract enemy index from entity_id
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return
	
	var enemy_index: int = parts[1].to_int()
	
	# Update position in injected WaveDirector
	if not wave_director:
		Logger.warn("WaveDirector not injected for position update", "enemies")
		return
	
	# Validate enemy still exists and is alive before updating position
	if enemy_index >= 0 and enemy_index < wave_director.enemies.size():
		var enemy: EnemyEntity = wave_director.enemies[enemy_index]
		if enemy.alive:
			# Clamp position to reasonable arena bounds to prevent infinite knockback
			var clamped_pos = Vector2(
				clampf(new_pos.x, -2000, 2000),
				clampf(new_pos.y, -2000, 2000)
			)
			enemy.pos = clamped_pos
			
			# Debug position updates for problematic enemies
			if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
				if new_pos.distance_to(clamped_pos) > 10:
					Logger.debug("Enemy " + entity_id + " position clamped: " + str(new_pos) + " -> " + str(clamped_pos), "enemies")
	else:
		# Enemy no longer exists, remove knockback effect
		knockback_effects.erase(entity_id)
		Logger.debug("Removing knockback for dead/invalid enemy: " + entity_id, "enemies")

func _find_enemy_in_multimesh(entity_id: String) -> Dictionary:
	# Get current alive enemies and group by tier
	if not wave_director:
		Logger.warn("WaveDirector not injected for MultiMesh lookup", "enemies")
		return {}
	
	if not enemy_render_tier:
		Logger.warn("EnemyRenderTier not injected for MultiMesh lookup", "enemies")
		return {}
	
	var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
	
	var tier_groups: Dictionary = enemy_render_tier.group_enemies_by_tier(alive_enemies)
	
	# Extract enemy index from entity_id
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return {}
	
	var target_enemy_index: int = parts[1].to_int()
	
	# Find the enemy in the appropriate tier
	var current_index: int = 0
	
	# Check SWARM tier
	var swarm_enemies: Array[Dictionary] = tier_groups[EnemyRenderTier_Type.Tier.SWARM]
	for i in range(swarm_enemies.size()):
		if _get_enemy_original_index(swarm_enemies[i]) == target_enemy_index:
			return {"multimesh": mm_enemies_swarm, "index": i}
	
	# Check REGULAR tier
	var regular_enemies: Array[Dictionary] = tier_groups[EnemyRenderTier_Type.Tier.REGULAR]
	for i in range(regular_enemies.size()):
		if _get_enemy_original_index(regular_enemies[i]) == target_enemy_index:
			return {"multimesh": mm_enemies_regular, "index": i}
	
	# Check ELITE tier
	var elite_enemies: Array[Dictionary] = tier_groups[EnemyRenderTier_Type.Tier.ELITE]
	for i in range(elite_enemies.size()):
		if _get_enemy_original_index(elite_enemies[i]) == target_enemy_index:
			return {"multimesh": mm_enemies_elite, "index": i}
	
	# Check BOSS tier
	var boss_enemies: Array[Dictionary] = tier_groups[EnemyRenderTier_Type.Tier.BOSS]
	for i in range(boss_enemies.size()):
		if _get_enemy_original_index(boss_enemies[i]) == target_enemy_index:
			return {"multimesh": mm_enemies_boss, "index": i}
	
	return {}

func _get_enemy_original_index(enemy_dict: Dictionary) -> int:
	# This is tricky - we need to map back to the original enemy index
	# For now, we'll use a simple approach based on position matching
	if not wave_director:
		Logger.warn("WaveDirector not injected for enemy index lookup", "enemies")
		return -1
	
	var enemy_pos: Vector2 = enemy_dict.get("pos", Vector2.ZERO)
	
	for i in range(wave_director.enemies.size()):
		var enemy: EnemyEntity = wave_director.enemies[i]
		if enemy.alive and enemy.pos.distance_to(enemy_pos) < 1.0:
			return i
	
	return -1

func _reset_enemy_color(entity_id: String) -> void:
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# Reset to original color (white for default tinting)
	mm_instance.multimesh.set_instance_color(instance_index, Color.WHITE)

func _is_enemy_still_valid(entity_id: String) -> bool:
	"""Check if enemy still exists and is alive"""
	if not wave_director:
		return false
	
	# Extract enemy index from entity_id
	var parts: PackedStringArray = entity_id.split(":")
	if parts.size() < 2:
		return false
	
	var enemy_index: int = parts[1].to_int()
	
	# Check if enemy exists and is alive
	if enemy_index >= 0 and enemy_index < wave_director.enemies.size():
		var enemy: EnemyEntity = wave_director.enemies[enemy_index]
		return enemy.alive
	
	return false

func _cleanup_oldest_effects() -> void:
	"""Emergency cleanup of oldest effects to prevent memory issues"""
	var effect_ages: Array = []
	
	# Collect effect ages
	for entity_id in knockback_effects.keys():
		var effect_data = knockback_effects[entity_id]
		if effect_data.has("timer"):
			effect_ages.append({"id": entity_id, "age": effect_data.timer})
	
	# Sort by age (oldest first)
	effect_ages.sort_custom(func(a, b): return a.age > b.age)
	
	# Remove oldest 50 effects
	var remove_count = min(50, effect_ages.size())
	for i in range(remove_count):
		var entity_id = effect_ages[i].id
		knockback_effects.erase(entity_id)
		flash_effects.erase(entity_id)  # Also clean up flash effects
	
	Logger.warn("Emergency cleanup removed " + str(remove_count) + " oldest effects", "performance")

func cleanup_all_effects() -> void:
	"""Public method to force cleanup of all effects"""
	flash_effects.clear()
	knockback_effects.clear()
	Logger.info("All hit feedback effects cleared", "enemies")

func _periodic_cleanup() -> void:
	"""Periodic cleanup to prevent gradual accumulation of stale effects"""
	var cleaned_flash = 0
	var cleaned_knockback = 0
	
	# Clean up flash effects for invalid enemies
	var flash_to_remove: Array[String] = []
	for entity_id in flash_effects.keys():
		if not _is_enemy_still_valid(entity_id):
			flash_to_remove.append(entity_id)
			cleaned_flash += 1
	
	for entity_id in flash_to_remove:
		flash_effects.erase(entity_id)
	
	# Clean up knockback effects for invalid enemies
	var knockback_to_remove: Array[String] = []
	for entity_id in knockback_effects.keys():
		if not _is_enemy_still_valid(entity_id):
			knockback_to_remove.append(entity_id)
			cleaned_knockback += 1
	
	for entity_id in knockback_to_remove:
		knockback_effects.erase(entity_id)
	
	if cleaned_flash > 0 or cleaned_knockback > 0:
		Logger.debug("Periodic cleanup: removed " + str(cleaned_flash) + " flash effects, " + str(cleaned_knockback) + " knockback effects", "performance")

func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)
