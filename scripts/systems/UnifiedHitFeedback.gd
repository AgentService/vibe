extends Node

## Unified Hit Feedback System
## Handles visual feedback for all entity types:
## - MultiMesh enemies: flash and knockback via MultiMesh color manipulation
## - Scene-based bosses: knockback only (visual feedback handled by BaseBoss itself)

class_name UnifiedHitFeedback

# MultiMesh references (injected by Arena)
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

# System references (injected by Arena)
var wave_director: WaveDirector
var enemy_render_tier: EnemyRenderTier

# Visual feedback configuration
var visual_config: VisualFeedbackConfig

# Effect tracking
var multimesh_flash_effects: Dictionary = {}  # entity_id -> flash_data
var boss_knockback_effects: Dictionary = {}  # instance_id -> knockback_data  
var enemy_knockback_effects: Dictionary = {}  # enemy_index -> knockback_data
var _initialized: bool = false

func _enter_tree() -> void:
	# Strongest guarantee this runs when added to Arena
	Logger.info("KNOCKBACK DEBUG: UnifiedHitFeedback._enter_tree()", "feedback")
	# Ensure config is loaded even if _ready timing is off
	_ensure_config_loaded()
	# Defer signal connection to after current frame to avoid any ordering edge cases
	call_deferred("_deferred_connect_signals")

func _deferred_connect_signals() -> void:
	if not is_inside_tree():
		return
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		Logger.debug("KNOCKBACK: damage_applied already connected", "feedback")
	else:
		EventBus.damage_applied.connect(_on_damage_applied)
		Logger.info("KNOCKBACK: Connected to EventBus.damage_applied in _enter_tree (deferred)", "feedback")

func _ensure_config_loaded() -> void:
	if visual_config:
		return
	Logger.info("KNOCKBACK DEBUG: Ensuring feedback config is loaded (from _enter_tree)", "feedback")
	visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		visual_config = VisualFeedbackConfig.new()
		visual_config.flash_duration = 0.18
		visual_config.flash_intensity = 4.0
		visual_config.flash_color = Color(3.0, 3.0, 3.0, 1.0)
		visual_config.knockback_duration = 0.25

func _ready() -> void:
	Logger.info("KNOCKBACK DEBUG: UnifiedHitFeedback._ready() called!", "feedback")
	
	# Load visual feedback configuration
	Logger.info("KNOCKBACK DEBUG: Loading feedback config...", "feedback")
	visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		Logger.warn("Failed to load visual feedback config, using defaults", "feedback")
		visual_config = VisualFeedbackConfig.new()
		# Set default values
		visual_config.flash_duration = 0.18
		visual_config.flash_intensity = 4.0
		visual_config.flash_color = Color(3.0, 3.0, 3.0, 1.0)
		visual_config.knockback_duration = 0.25
	else:
		Logger.info("KNOCKBACK DEBUG: Visual feedback config loaded successfully!", "feedback")
	
	# Periodic cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 30.0
	cleanup_timer.timeout.connect(_periodic_cleanup)
	add_child(cleanup_timer)
	cleanup_timer.start()
	
	Logger.info("KNOCKBACK DEBUG: UnifiedHitFeedback initialization complete!", "feedback")

func _exit_tree() -> void:
	Logger.info("KNOCKBACK DEBUG: UnifiedHitFeedback._exit_tree()", "feedback")
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)

## Setup MultiMesh references (called by Arena)
func setup_multimesh_references(swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D) -> void:
	mm_enemies_swarm = swarm
	mm_enemies_regular = regular
	mm_enemies_elite = elite
	mm_enemies_boss = boss
	Logger.debug("UnifiedHitFeedback MultiMesh references configured", "feedback")

## Set WaveDirector reference (called by Arena)
func set_wave_director(wd: WaveDirector) -> void:
	wave_director = wd

## Set EnemyRenderTier reference (called by Arena)
func set_enemy_render_tier(ert: EnemyRenderTier) -> void:
	enemy_render_tier = ert

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	var target_id_str = str(payload.target_id)
	Logger.info("KNOCKBACK SUCCESS: UnifiedHitFeedback received damage event - EntityId: " + str(payload.target_id.index) + " knockback: " + str(payload.knockback_distance), "feedback")
	Logger.info("KNOCKBACK SUCCESS: Event received by UnifiedHitFeedback! Connection working!", "feedback")
	
	# Determine entity type and apply appropriate feedback
	if payload.target_id.type == EntityId.Type.ENEMY:
		if payload.target_id.index > 1000:
			# Likely a scene-based boss (large instance ID)
			_apply_boss_feedback(payload.target_id.index, payload)
		else:
			# MultiMesh pooled enemy
			_apply_multimesh_feedback(payload.target_id.index, payload)

## Apply feedback to MultiMesh enemies (flash + knockback via color manipulation)
func _apply_multimesh_feedback(enemy_index: int, payload: DamageAppliedPayload) -> void:
	if not wave_director or not enemy_render_tier:
		Logger.warn("Wave director or render tier not available for MultiMesh feedback", "feedback")
		return
	
	# Get enemy from WaveDirector to determine tier
	if enemy_index >= wave_director.enemies.size():
		Logger.debug("Enemy index out of bounds for feedback: " + str(enemy_index), "feedback")
		return
	
	var enemy = wave_director.enemies[enemy_index]
	if not enemy.alive:
		Logger.debug("Enemy is dead, skipping feedback: " + str(enemy_index), "feedback")
		return
	
	# Determine tier from type_id string for feedback purposes
	# Boss types contain "boss" or "lich" in their type_id
	var enemy_tier = 0  # Default to SWARM (0)
	var type_id_lower = enemy.type_id.to_lower()
	if "boss" in type_id_lower or "lich" in type_id_lower or "dragon" in type_id_lower:
		enemy_tier = 3  # BOSS tier
	elif "elite" in type_id_lower or "champion" in type_id_lower:
		enemy_tier = 2  # ELITE tier  
	elif "regular" in type_id_lower or "grunt" in type_id_lower or "soldier" in type_id_lower:
		enemy_tier = 1  # REGULAR tier
	var multimesh_instance: MultiMeshInstance2D
	
	match enemy_tier:
		0: multimesh_instance = mm_enemies_swarm    # SWARM
		1: multimesh_instance = mm_enemies_regular  # REGULAR
		2: multimesh_instance = mm_enemies_elite    # ELITE
		3: multimesh_instance = mm_enemies_boss     # BOSS (MultiMesh, not scene-based)
		_:
			Logger.warn("Unknown enemy tier for feedback: " + str(enemy_tier), "feedback")
			return
	
	if not multimesh_instance:
		Logger.warn("MultiMesh instance not available for tier " + str(enemy_tier), "feedback")
		return
	
	# Find enemy in MultiMesh using entity_id (similar to existing feedback system)
	var entity_id = "enemy_" + str(enemy_index)
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		Logger.debug("Enemy " + str(enemy_index) + " not found in MultiMesh", "feedback")
		return
	
	var actual_multimesh_instance: MultiMeshInstance2D = enemy_info.multimesh
	var multimesh_index: int = enemy_info.index
	
	# Override the tier-based multimesh_instance with the actual one found
	multimesh_instance = actual_multimesh_instance
	
	# Start flash effect (reuse entity_id from above)
	var flash_data := {
		"timer": 0.0,
		"duration": visual_config.flash_duration,
		"multimesh_instance": multimesh_instance,
		"multimesh_index": multimesh_index,
		"original_color": Color.WHITE,  # Will be updated when we get the actual color
		"flash_color": visual_config.flash_color,
		"flash_intensity": visual_config.flash_intensity
	}
	
	# Get and store original color
	var original_color = multimesh_instance.multimesh.get_instance_color(multimesh_index)
	flash_data.original_color = original_color
	
	multimesh_flash_effects[entity_id] = flash_data
	Logger.debug("Started MultiMesh flash for enemy " + str(enemy_index), "feedback")
	
	# Apply knockback if requested
	if payload.knockback_distance > 0.0:
		Logger.info("KNOCKBACK: Starting enemy knockback for index " + str(enemy_index), "feedback")
		_apply_enemy_knockback(enemy_index, payload)
	else:
		Logger.warn("KNOCKBACK: No knockback requested for enemy " + str(enemy_index), "feedback")

## Apply feedback to scene-based bosses (knockback only, visual handled by BaseBoss)
func _apply_boss_feedback(instance_id: int, payload: DamageAppliedPayload) -> void:
	Logger.info("KNOCKBACK: _apply_boss_feedback called for instance " + str(instance_id) + " with knockback " + str(payload.knockback_distance), "feedback")
	
	# Skip if no knockback requested
	if payload.knockback_distance <= 0.0:
		Logger.warn("KNOCKBACK: No knockback requested for boss " + str(instance_id), "feedback")
		return
	
	# Find boss by instance ID
	var boss = instance_from_id(instance_id)
	if not boss or not is_instance_valid(boss):
		Logger.debug("Boss not found for knockback: " + str(instance_id), "feedback")
		return
	
	# Verify it's a boss with required interface
	if not (boss.has_method("move_and_slide") and boss is CharacterBody2D):
		Logger.debug("Entity is not a valid boss for knockback: " + str(instance_id), "feedback")
		return
	
	# Calculate knockback direction
	var boss_pos: Vector2 = boss.global_position
	var knockback_dir: Vector2 = (boss_pos - payload.source_position).normalized()
	if knockback_dir.length() < 0.1:
		knockback_dir = Vector2(1, 0)  # Fallback direction
	
	# Create knockback data
	var knockback_velocity = knockback_dir * payload.knockback_distance
	var knockback_data := {
		"timer": 0.0,
		"duration": visual_config.knockback_duration,
		"initial_velocity": knockback_velocity,
		"current_velocity": knockback_velocity,
		"boss": boss,
		"decay_factor": 0.85  # How quickly velocity decreases
	}
	
	boss_knockback_effects[instance_id] = knockback_data
	Logger.debug("Started boss knockback for instance " + str(instance_id), "feedback")

## Apply knockback to pooled enemies
func _apply_enemy_knockback(enemy_index: int, payload: DamageAppliedPayload) -> void:
	if not wave_director or enemy_index >= wave_director.enemies.size():
		Logger.debug("Enemy index out of bounds for knockback: " + str(enemy_index), "feedback")
		return
	
	var enemy = wave_director.enemies[enemy_index]
	if not enemy.alive:
		Logger.debug("Enemy is dead, skipping knockback: " + str(enemy_index), "feedback")
		return
	
	# Calculate knockback direction
	var enemy_pos: Vector2 = enemy.pos
	var knockback_dir: Vector2 = (enemy_pos - payload.source_position).normalized()
	if knockback_dir.length() < 0.1:
		knockback_dir = Vector2(1, 0)  # Fallback direction
	
	# Apply knockback resistance (TODO: get from enemy template when available)
	var knockback_resistance: float = 0.0  # Default: no resistance
	var effective_knockback = payload.knockback_distance * (1.0 - knockback_resistance)
	
	# Create knockback data
	var knockback_velocity = knockback_dir * effective_knockback
	var knockback_data := {
		"timer": 0.0,
		"duration": visual_config.knockback_duration,
		"initial_velocity": knockback_velocity,
		"current_velocity": knockback_velocity,
		"enemy_index": enemy_index,
		"decay_factor": 0.80  # Slightly faster decay than bosses
	}
	
	enemy_knockback_effects[enemy_index] = knockback_data
	Logger.debug("Started enemy knockback for index " + str(enemy_index) + " with distance " + str(effective_knockback), "feedback")

func _process(delta: float) -> void:
	_update_multimesh_flash_effects(delta)
	_update_boss_knockback_effects(delta)
	_update_enemy_knockback_effects(delta)

func _update_multimesh_flash_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in multimesh_flash_effects.keys():
		var flash_data: Dictionary = multimesh_flash_effects[entity_id]
		flash_data.timer += delta
		var progress: float = flash_data.timer / flash_data.duration
		
		if progress >= 1.0:
			# Restore original color and mark for cleanup
			var multimesh_instance = flash_data.multimesh_instance
			var multimesh_index = flash_data.multimesh_index
			if multimesh_instance and multimesh_instance.multimesh:
				multimesh_instance.multimesh.set_instance_color(multimesh_index, flash_data.original_color)
			completed_effects.append(entity_id)
			continue
		
		# Apply flash color interpolation
		_apply_multimesh_flash_effect(flash_data, progress)
	
	# Clean up completed effects
	for entity_id in completed_effects:
		multimesh_flash_effects.erase(entity_id)

func _update_boss_knockback_effects(delta: float) -> void:
	var completed_effects: Array[int] = []
	
	for instance_id in boss_knockback_effects.keys():
		var knockback_data: Dictionary = boss_knockback_effects[instance_id]
		var boss = knockback_data.boss
		
		# Check if boss still valid
		if not is_instance_valid(boss):
			completed_effects.append(instance_id)
			continue
		
		knockback_data.timer += delta
		var progress: float = knockback_data.timer / knockback_data.duration
		
		if progress >= 1.0:
			completed_effects.append(instance_id)
			continue
		
		# Apply knockback with decay
		knockback_data.current_velocity *= knockback_data.decay_factor
		
		# Apply velocity to boss
		if knockback_data.current_velocity.length() > 10.0:  # Minimum threshold
			boss.velocity = knockback_data.current_velocity
			boss.move_and_slide()
	
	# Clean up completed effects
	for instance_id in completed_effects:
		boss_knockback_effects.erase(instance_id)

func _update_enemy_knockback_effects(delta: float) -> void:
	var completed_effects: Array[int] = []
	
	for enemy_index in enemy_knockback_effects.keys():
		var knockback_data: Dictionary = enemy_knockback_effects[enemy_index]
		
		# Check if enemy still exists and is alive
		if not wave_director or enemy_index >= wave_director.enemies.size():
			completed_effects.append(enemy_index)
			continue
			
		var enemy = wave_director.enemies[enemy_index]
		if not enemy.alive:
			completed_effects.append(enemy_index)
			continue
		
		knockback_data.timer += delta
		var progress: float = knockback_data.timer / knockback_data.duration
		
		if progress >= 1.0:
			completed_effects.append(enemy_index)
			continue
		
		# Apply knockback with decay
		knockback_data.current_velocity *= knockback_data.decay_factor
		
		# Apply velocity to enemy position if velocity is significant
		if knockback_data.current_velocity.length() > 10.0:  # Minimum threshold
			enemy.pos += knockback_data.current_velocity * delta
			# Mark WaveDirector cache as dirty so rendered positions update
			wave_director._cache_dirty = true
	
	# Clean up completed effects
	for enemy_index in completed_effects:
		enemy_knockback_effects.erase(enemy_index)

func _apply_multimesh_flash_effect(flash_data: Dictionary, progress: float) -> void:
	var multimesh_instance = flash_data.multimesh_instance
	var multimesh_index = flash_data.multimesh_index
	
	if not multimesh_instance or not multimesh_instance.multimesh:
		return
	
	# Calculate flash intensity using curve (bright at start, fade to original)
	var curve_value: float = visual_config.flash_curve.sample(progress) if visual_config.flash_curve else (1.0 - progress)
	var flash_amount: float = curve_value
	
	# Interpolate between original color and flash color
	var current_color = flash_data.original_color.lerp(flash_data.flash_color, flash_amount)
	multimesh_instance.multimesh.set_instance_color(multimesh_index, current_color)

func _periodic_cleanup() -> void:
	# Clean up any stale effects
	var cleanup_count = 0
	
	# Clean up MultiMesh effects for dead enemies
	var stale_multimesh: Array[String] = []
	for entity_id in multimesh_flash_effects.keys():
		var enemy_index = int(entity_id.replace("enemy_", ""))
		if wave_director and (enemy_index >= wave_director.enemies.size() or not wave_director.enemies[enemy_index].alive):
			stale_multimesh.append(entity_id)
	
	for entity_id in stale_multimesh:
		multimesh_flash_effects.erase(entity_id)
		cleanup_count += 1
	
	# Clean up boss effects for invalid bosses
	var stale_bosses: Array[int] = []
	for instance_id in boss_knockback_effects.keys():
		var boss = instance_from_id(instance_id)
		if not boss or not is_instance_valid(boss):
			stale_bosses.append(instance_id)
	
	for instance_id in stale_bosses:
		boss_knockback_effects.erase(instance_id)
		cleanup_count += 1
	
	# Clean up enemy knockback effects for dead enemies
	var stale_enemy_knockbacks: Array[int] = []
	for enemy_index in enemy_knockback_effects.keys():
		if not wave_director or enemy_index >= wave_director.enemies.size() or not wave_director.enemies[enemy_index].alive:
			stale_enemy_knockbacks.append(enemy_index)
	
	for enemy_index in stale_enemy_knockbacks:
		enemy_knockback_effects.erase(enemy_index)
		cleanup_count += 1
	
	if cleanup_count > 0:
		Logger.debug("Cleaned up " + str(cleanup_count) + " stale feedback effects", "feedback")

## Find enemy in MultiMesh system by pool index - IMPROVED VERSION
func _find_enemy_in_multimesh(entity_id: String) -> Dictionary:
	# Get current alive enemies and group by tier
	if not wave_director:
		Logger.warn("WaveDirector not injected for MultiMesh lookup", "feedback")
		return {}
	
	if not enemy_render_tier:
		Logger.warn("EnemyRenderTier not injected for MultiMesh lookup", "feedback")
		return {}
	
	# Extract enemy pool index from entity_id
	var parts: PackedStringArray = entity_id.split("_")
	if parts.size() < 2:
		return {}
	
	var target_enemy_index: int = parts[1].to_int()
	
	# Get the enemy directly from the pool using the index
	if target_enemy_index >= wave_director.enemies.size():
		Logger.debug("Enemy index out of bounds for feedback lookup: " + str(target_enemy_index), "feedback")
		return {}
	
	var target_enemy: EnemyEntity = wave_director.enemies[target_enemy_index]
	if not target_enemy.alive:
		Logger.debug("Enemy is dead, skipping feedback lookup: " + str(target_enemy_index), "feedback")
		return {}
	
	# Group all alive enemies by tier to find visual index
	var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
	var tier_groups: Dictionary = enemy_render_tier.group_enemies_by_tier(alive_enemies)
	
	# Determine target enemy's tier
	var target_tier = _get_enemy_tier(target_enemy)
	var tier_enemies: Array[Dictionary]
	var multimesh_instance: MultiMeshInstance2D
	
	match target_tier:
		EnemyRenderTier.Tier.SWARM:
			tier_enemies = tier_groups[EnemyRenderTier.Tier.SWARM]
			multimesh_instance = mm_enemies_swarm
		EnemyRenderTier.Tier.REGULAR:
			tier_enemies = tier_groups[EnemyRenderTier.Tier.REGULAR]
			multimesh_instance = mm_enemies_regular
		EnemyRenderTier.Tier.ELITE:
			tier_enemies = tier_groups[EnemyRenderTier.Tier.ELITE]
			multimesh_instance = mm_enemies_elite
		EnemyRenderTier.Tier.BOSS:
			tier_enemies = tier_groups[EnemyRenderTier.Tier.BOSS]
			multimesh_instance = mm_enemies_boss
		_:
			Logger.warn("Unknown enemy tier for feedback", "feedback")
			return {}
	
	# Find the enemy in the tier group using improved matching
	for i in range(tier_enemies.size()):
		var enemy_dict = tier_enemies[i]
		# Use multiple criteria for more reliable matching
		var enemy_pos: Vector2 = enemy_dict.get("pos", Vector2.ZERO)
		var enemy_type: String = enemy_dict.get("type_id", "")
		
		# Check if this is our target enemy using position + type matching
		if target_enemy.pos.distance_to(enemy_pos) < 5.0 and target_enemy.type_id == enemy_type:
			return {"multimesh": multimesh_instance, "index": i}
	
	return {}

## Get enemy tier for more reliable matching
func _get_enemy_tier(enemy: EnemyEntity) -> EnemyRenderTier.Tier:
	if not enemy_render_tier:
		return EnemyRenderTier.Tier.REGULAR
	
	# Use the same logic as EnemyRenderTier to determine tier from type_id
	var type_id_lower = enemy.type_id.to_lower()
	if "boss" in type_id_lower or "lich" in type_id_lower or "dragon" in type_id_lower:
		return EnemyRenderTier.Tier.BOSS
	elif "elite" in type_id_lower or "champion" in type_id_lower:
		return EnemyRenderTier.Tier.ELITE
	elif "regular" in type_id_lower or "grunt" in type_id_lower or "soldier" in type_id_lower:
		return EnemyRenderTier.Tier.REGULAR
	else:
		return EnemyRenderTier.Tier.SWARM  # Default to swarm
