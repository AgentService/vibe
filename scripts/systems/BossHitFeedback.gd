extends Node

## Hit feedback system for scene-based boss entities.
## Handles flash effects and knockback for CharacterBody2D bosses.

class_name BossHitFeedback

# Visual feedback configuration (shared with MultiMesh system)
var visual_config: VisualFeedbackConfig

# Shader material for boss flash effects
var boss_flash_material: ShaderMaterial

# Editor-configurable boss knockback settings
@export_group("Boss Knockback")
@export var knockback_force_multiplier: float = 1.0  ## Multiplier for knockback force (higher = stronger knockback)
@export var knockback_duration_multiplier: float = 2.0  ## Duration multiplier for knockback effect
@export var hit_stop_duration: float = 0.15  ## Brief freeze time on impact (seconds)
@export var velocity_decay_factor: float = 0.82  ## How quickly velocity decreases (0.0-1.0, higher = longer knockback)
@export var min_velocity_threshold: float = 30.0  ## Minimum speed before stopping knockback

@export_group("Boss Flash")
@export var flash_duration_override: float = 0.2  ## Flash duration for bosses (0 = use config file)
@export var flash_intensity_override: float = 15.0  ## Flash intensity for bosses (0 = use config file)

# Flash effect tracking: boss_instance_id -> flash_data
var boss_flash_effects: Dictionary = {}
var boss_knockback_effects: Dictionary = {}

# Boss references by instance ID
var registered_bosses: Dictionary = {}

func _ready() -> void:
	# Load visual feedback configuration  
	visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		Logger.warn("Failed to load visual feedback config for bosses, using defaults", "bosses")
		visual_config = VisualFeedbackConfig.new()
		# Set enhanced flash values for better visibility on AnimatedSprite2D bosses
		visual_config.flash_duration = flash_duration_override if flash_duration_override > 0 else 0.2
		visual_config.flash_intensity = flash_intensity_override if flash_intensity_override > 0 else 15.0
		visual_config.flash_color = Color(4.0, 4.0, 4.0, 1.0)  # Very bright white for AnimatedSprite2D
		visual_config.knockback_duration = 0.3  # Base duration (multiplied by knockback_duration_multiplier)
	
	# Load boss flash shader material
	boss_flash_material = load("res://shaders/boss_flash_material.tres") as ShaderMaterial
	if not boss_flash_material:
		Logger.warn("Failed to load boss flash shader material", "bosses")
	
	# Subscribe to damage events
	EventBus.damage_applied.connect(_on_damage_applied)
	
	# Start a timer to periodically scan for new bosses
	var boss_scanner = Timer.new()
	boss_scanner.wait_time = 1.0  # Check every second
	boss_scanner.timeout.connect(_scan_for_bosses)
	add_child(boss_scanner)
	boss_scanner.start()
	
	Logger.info("BossHitFeedback initialized", "bosses")

func _is_valid_boss(node: Node) -> bool:
	"""Check if a node has the required boss interface"""
	return (node.has_method("get_current_health") and 
			node.has_signal("died") and
			node is CharacterBody2D)

func register_boss(boss: Node) -> void:
	"""Register a boss for hit feedback tracking"""
	if not boss.has_method("get_current_health") or not boss.has_signal("died"):
		Logger.warn("Boss " + boss.name + " doesn't have required interface for hit feedback", "bosses")
		return
	
	var instance_id = boss.get_instance_id()
	registered_bosses[instance_id] = boss
	Logger.debug("Boss " + boss.name + " registered for hit feedback (ID: " + str(instance_id) + ")", "bosses")

func unregister_boss(boss: Node) -> void:
	"""Unregister a boss from hit feedback tracking"""
	var instance_id = boss.get_instance_id()
	registered_bosses.erase(instance_id)
	boss_flash_effects.erase(instance_id)
	boss_knockback_effects.erase(instance_id)
	Logger.debug("Boss " + boss.name + " unregistered from hit feedback", "bosses")

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	var target_id_str = str(payload.target_id)
	
	# Debug all damage events to see what we're getting
	Logger.debug("BossHitFeedback received damage event for: " + target_id_str, "bosses")
	
	# FIXED: Bosses have EntityId.Type.ENEMY with large instance IDs (not -1)
	# Boss EntityIds are created from "boss_12345" where 12345 is the instance ID
	var is_boss_target = false
	var instance_id: int = 0
	
	if payload.target_id.type == EntityId.Type.ENEMY:
		# Boss instance IDs are typically large (> 1000), regular enemies are small indices
		if payload.target_id.index > 1000:  # Likely a boss instance ID
			instance_id = payload.target_id.index
			is_boss_target = true
			Logger.debug("Detected potential boss with instance ID: " + str(instance_id), "bosses")
	
	if not is_boss_target:
		return
	
	Logger.debug("Processing boss hit feedback for instance ID: " + str(instance_id), "bosses")
	
	# Try to find boss in registered bosses first
	var boss: Node = registered_bosses.get(instance_id, null)
	
	# If not registered, try to find it by instance ID
	if not boss or not is_instance_valid(boss):
		boss = instance_from_id(instance_id)
		if boss and _is_valid_boss(boss):
			# Auto-register this boss
			register_boss(boss)
			Logger.debug("Auto-registered boss: " + boss.name, "bosses")
		else:
			boss = null
	
	if not boss or not is_instance_valid(boss):
		Logger.warn("Could not find boss for instance ID: " + str(instance_id) + ". Registered bosses: " + str(registered_bosses.keys()), "bosses")
		return
	
	# Start flash effect
	_start_boss_flash_effect(instance_id, boss)
	
	# Start knockback effect if knockback distance > 0
	if payload.knockback_distance > 0.0:
		_start_boss_knockback_effect(instance_id, boss, payload.source_position, payload.knockback_distance)

func _start_boss_flash_effect(instance_id: int, boss: Node) -> void:
	# Find the AnimatedSprite2D within the boss structure
	var animated_sprite = _find_animated_sprite(boss)
	
	# Use editor overrides if specified, otherwise use config values
	var duration = flash_duration_override if flash_duration_override > 0 else visual_config.flash_duration
	var intensity = flash_intensity_override if flash_intensity_override > 0 else visual_config.flash_intensity
	
	# Store original material BEFORE applying shader (modulate stays untouched)
	var original_material = animated_sprite.material if animated_sprite else null
	
	# Create a unique shader material instance for this boss
	var material_instance: ShaderMaterial = null
	if boss_flash_material and animated_sprite:
		material_instance = boss_flash_material.duplicate() as ShaderMaterial
		animated_sprite.material = material_instance
	
	var flash_data := {
		"timer": 0.0,
		"duration": duration,
		"flash_intensity": intensity,
		"boss": boss,
		"animated_sprite": animated_sprite,
		"shader_material": material_instance,
		"original_material": original_material
	}
	
	boss_flash_effects[instance_id] = flash_data
	Logger.debug("Started boss flash effect for " + boss.name + " (sprite found: " + str(animated_sprite != null) + ")", "bosses")

func _find_animated_sprite(boss: Node) -> AnimatedSprite2D:
	"""Find the AnimatedSprite2D node within the boss hierarchy"""
	# Check common paths for boss structure
	var possible_paths = [
		"CollisionShape2D/AnimatedSprite2D",  # AncientLich structure
		"CollisionShape/AnimatedSprite2D",    # DragonLord structure
		"AnimatedSprite2D",                   # Direct child
		"Sprite/AnimatedSprite2D",            # Alternative structure
	]
	
	for path in possible_paths:
		var sprite = boss.get_node_or_null(path)
		if sprite and sprite is AnimatedSprite2D:
			return sprite
	
	# Recursive search as fallback
	return _find_animated_sprite_recursive(boss)

func _find_animated_sprite_recursive(node: Node) -> AnimatedSprite2D:
	"""Recursively search for AnimatedSprite2D in the node tree"""
	if node is AnimatedSprite2D:
		return node
	
	for child in node.get_children():
		var result = _find_animated_sprite_recursive(child)
		if result:
			return result
	
	return null

func _start_boss_knockback_effect(instance_id: int, boss: Node, source_pos: Vector2, knockback_distance: float) -> void:
	# Calculate knockback direction
	var boss_pos: Vector2 = boss.global_position
	var knockback_dir: Vector2 = (boss_pos - source_pos).normalized()
	if knockback_dir.length() < 0.1:
		knockback_dir = Vector2(1, 0)  # Fallback direction
	
	# Enhanced knockback with editor-configurable force calculation
	var knockback_force = knockback_distance * knockback_force_multiplier
	var knockback_velocity = knockback_dir * knockback_force
	
	var knockback_data := {
		"timer": 0.0,
		"duration": visual_config.knockback_duration * knockback_duration_multiplier,
		"initial_velocity": knockback_velocity,
		"current_velocity": knockback_velocity,
		"boss": boss,
		"hit_stop_duration": hit_stop_duration,
		"hit_stop_timer": 0.0
	}
	
	boss_knockback_effects[instance_id] = knockback_data
	Logger.debug("Started boss knockback effect for " + boss.name + " force: " + str(knockback_force), "bosses")

func _process(delta: float) -> void:
	_update_boss_flash_effects(delta)
	_update_boss_knockback_effects(delta)

func _update_boss_flash_effects(delta: float) -> void:
	var completed_effects: Array[int] = []
	
	for instance_id in boss_flash_effects.keys():
		var flash_data: Dictionary = boss_flash_effects[instance_id]
		var boss = flash_data.boss
		
		if not is_instance_valid(boss):
			completed_effects.append(instance_id)
			continue
		
		flash_data.timer += delta
		var progress: float = flash_data.timer / flash_data.duration
		
		if progress >= 1.0:
			completed_effects.append(instance_id)
			continue
		
		# Apply flash effect to boss modulate
		_apply_boss_flash_effect(flash_data, progress)
	
	# Clean up completed effects
	for instance_id in completed_effects:
		_reset_boss_color(instance_id)
		boss_flash_effects.erase(instance_id)

func _update_boss_knockback_effects(delta: float) -> void:
	var completed_effects: Array[int] = []
	var invalid_effects: Array[int] = []
	
	for instance_id in boss_knockback_effects.keys():
		# Validate effect data exists
		if not boss_knockback_effects.has(instance_id):
			invalid_effects.append(instance_id)
			continue
			
		var knockback_data: Dictionary = boss_knockback_effects[instance_id]
		var boss = knockback_data.boss
		
		# Validate boss still exists
		if not is_instance_valid(boss):
			Logger.debug("Cleaning up knockback for invalid boss instance: " + str(instance_id), "bosses")
			invalid_effects.append(instance_id)
			continue
		
		# Additional check: ensure boss is still registered
		if not registered_bosses.has(instance_id):
			Logger.debug("Cleaning up knockback for unregistered boss: " + str(instance_id), "bosses")
			invalid_effects.append(instance_id)
			continue
		
		knockback_data.timer += delta
		var progress: float = knockback_data.timer / knockback_data.duration
		
		if progress >= 1.0:
			completed_effects.append(instance_id)
			continue
		
		# Apply knockback velocity to boss
		_apply_boss_knockback_effect(knockback_data, progress)
	
	# Clean up completed and invalid effects
	for instance_id in completed_effects:
		boss_knockback_effects.erase(instance_id)
	for instance_id in invalid_effects:
		boss_knockback_effects.erase(instance_id)
	
	# Safety cleanup: limit max concurrent effects
	if boss_knockback_effects.size() > 50:  # Lower limit for bosses
		Logger.warn("Boss knockback effects exceeded 50, performing cleanup", "performance")
		_cleanup_oldest_boss_effects()

func _apply_boss_flash_effect(flash_data: Dictionary, progress: float) -> void:
	var shader_material = flash_data.shader_material as ShaderMaterial
	
	if not shader_material:
		return  # No shader material available
	
	# Calculate flash intensity using curve - inverted for proper flash effect
	var curve_value: float = visual_config.flash_curve.sample(progress) if visual_config.flash_curve else (1.0 - progress)
	var flash_intensity: float = curve_value * flash_data.flash_intensity
	
	# Normalize flash intensity to 0.0-1.0 range for shader
	var normalized_intensity = clampf(flash_intensity / 10.0, 0.0, 1.0)  # Assuming max intensity is around 10
	
	# Set shader parameters for white flash
	shader_material.set_shader_parameter("flash_color", Color.WHITE)
	shader_material.set_shader_parameter("flash_modifier", normalized_intensity)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Boss flash progress " + str(progress) + ": intensity=" + str(normalized_intensity), "bosses")

func _apply_boss_knockback_effect(knockback_data: Dictionary, progress: float) -> void:
	var boss = knockback_data.boss
	
	# Hit-stop effect for impact feel
	if knockback_data.hit_stop_timer < knockback_data.hit_stop_duration:
		knockback_data.hit_stop_timer += get_process_delta_time()
		# During hit-stop, freeze the boss briefly
		if boss.has_method("move_and_slide"):
			boss.velocity = Vector2.ZERO
		return
	
	# Organic velocity decay using editor-configurable values
	# Update current velocity with decay
	knockback_data.current_velocity *= velocity_decay_factor
	
	# Stop if velocity is too small
	if knockback_data.current_velocity.length() < min_velocity_threshold:
		knockback_data.current_velocity = Vector2.ZERO
	
	# Apply velocity if boss is CharacterBody2D
	if boss.has_method("move_and_slide"):
		# Replace boss velocity entirely during knockback for organic feel
		boss.velocity = knockback_data.current_velocity
		boss.move_and_slide()
		
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("Boss knockback velocity: " + str(knockback_data.current_velocity.length()), "bosses")

func _reset_boss_color(instance_id: int) -> void:
	var flash_data = boss_flash_effects.get(instance_id, {})
	if flash_data.has("boss") and is_instance_valid(flash_data.boss):
		# Reset AnimatedSprite2D material to original (modulate stays unchanged)
		if flash_data.has("animated_sprite") and flash_data.animated_sprite:
			flash_data.animated_sprite.material = flash_data.get("original_material", null)
		
		Logger.debug("Boss flash shader reset for " + flash_data.boss.name + " (modulate preserved)", "bosses")

func _scan_for_bosses() -> void:
	"""Automatically find and register boss entities in the scene tree"""
	_scan_node_for_bosses(get_tree().root)

func _scan_node_for_bosses(node: Node) -> void:
	"""Recursively scan a node and its children for boss entities"""
	# Check if this node is a boss
	if node.has_method("get_current_health") and node.has_signal("died"):
		# Check if it's likely a boss (has boss in class name or is in bosses group)
		var is_boss = (node.get_class().to_lower().contains("boss") or 
					  node.name.to_lower().contains("boss") or
					  node.name.to_lower().contains("lich") or
					  node.name.to_lower().contains("dragon"))
		
		if is_boss:
			var instance_id = node.get_instance_id()
			if not registered_bosses.has(instance_id):
				register_boss(node)
	
	# Recursively check children
	for child in node.get_children():
		_scan_node_for_bosses(child)

func _cleanup_oldest_boss_effects() -> void:
	"""Emergency cleanup of oldest boss effects"""
	var effect_ages: Array = []
	
	# Collect effect ages
	for instance_id in boss_knockback_effects.keys():
		var effect_data = boss_knockback_effects[instance_id]
		if effect_data.has("timer"):
			effect_ages.append({"id": instance_id, "age": effect_data.timer})
	
	# Sort by age (oldest first)
	effect_ages.sort_custom(func(a, b): return a.age > b.age)
	
	# Remove oldest 10 effects
	var remove_count = min(10, effect_ages.size())
	for i in range(remove_count):
		var instance_id = effect_ages[i].id
		boss_knockback_effects.erase(instance_id)
		boss_flash_effects.erase(instance_id)
	
	Logger.warn("Boss emergency cleanup removed " + str(remove_count) + " oldest effects", "performance")

func cleanup_all_boss_effects() -> void:
	"""Public method to force cleanup of all boss effects"""
	boss_flash_effects.clear()
	boss_knockback_effects.clear()
	Logger.info("All boss hit feedback effects cleared", "bosses")

func cleanup_boss_effects_for_instance(instance_id: int) -> void:
	"""Clean up all effects for a specific boss instance"""
	boss_flash_effects.erase(instance_id)
	boss_knockback_effects.erase(instance_id)
	Logger.debug("Cleaned up effects for boss instance: " + str(instance_id), "bosses")

func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage_applied):
		EventBus.damage_applied.disconnect(_on_damage_applied)
