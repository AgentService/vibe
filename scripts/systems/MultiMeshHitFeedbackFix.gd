extends Node
class_name MultiMeshHitFeedbackFix

## FIXED MultiMesh Hit Feedback System
## Addresses color modulation, material requirements, and visibility issues

# Reference to Arena's MultiMesh instances
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

# Fixed visual feedback configuration
var visual_config: VisualFeedbackConfig

# Active flash effects
var flash_effects: Dictionary = {}

func _ready() -> void:
	# Load corrected visual feedback config
	visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		Logger.warn("Failed to load visual feedback config", "visual")
		return
	
	EventBus.damage_applied.connect(_on_damage_applied)
	Logger.info("Enhanced MultiMesh hit feedback initialized", "visual")

func setup_multimesh_references(swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D) -> void:
	mm_enemies_swarm = swarm
	mm_enemies_regular = regular
	mm_enemies_elite = elite
	mm_enemies_boss = boss
	
	# CRITICAL FIX: Enable color usage on all MultiMesh instances
	_configure_multimesh_for_colors(swarm)
	_configure_multimesh_for_colors(regular)
	_configure_multimesh_for_colors(elite)
	_configure_multimesh_for_colors(boss)
	
	Logger.info("MultiMesh references configured with color support", "visual")

func _configure_multimesh_for_colors(mm_instance: MultiMeshInstance2D) -> void:
	if not mm_instance or not mm_instance.multimesh:
		Logger.warn("MultiMesh instance null during color configuration", "visual")
		return
	
	# CRITICAL: Enable per-instance colors
	mm_instance.multimesh.use_colors = true
	
	# Initialize all instances to white (for proper color multiplication)
	for i in range(mm_instance.multimesh.instance_count):
		mm_instance.multimesh.set_instance_color(i, Color.WHITE)
	
	Logger.debug("Configured MultiMesh for color support: %d instances" % mm_instance.multimesh.instance_count, "visual")

func _on_damage_applied(payload: DamageAppliedPayload) -> void:
	if payload.target_id.type != EntityId.Type.ENEMY:
		return
	
	var entity_id: String = str(payload.target_id)
	Logger.debug("Hit feedback for %s - damage: %s, crit: %s" % [entity_id, payload.final_damage, payload.is_crit], "visual")
	
	# Apply enhanced flash with better visibility
	_start_enhanced_flash_effect(entity_id, payload.is_crit)

func _start_enhanced_flash_effect(entity_id: String, is_crit: bool = false) -> void:
	var flash_data := {
		"timer": 0.0,
		"duration": visual_config.flash_duration * (1.5 if is_crit else 1.0),
		"flash_color": _get_flash_color(is_crit),
		"entity_id": entity_id
	}
	
	flash_effects[entity_id] = flash_data
	Logger.debug("Enhanced flash started: %s (color: %s)" % [entity_id, flash_data.flash_color], "visual")

func _get_flash_color(is_crit: bool) -> Color:
	if is_crit:
		# Bright orange/yellow for critical hits
		return Color(3.0, 2.0, 0.5, 1.0)
	else:
		# Use config color (bright red/white)
		return visual_config.flash_color

func _process(delta: float) -> void:
	_update_flash_effects(delta)

func _update_flash_effects(delta: float) -> void:
	var completed_effects: Array[String] = []
	
	for entity_id in flash_effects.keys():
		var flash_data: Dictionary = flash_effects[entity_id]
		flash_data.timer += delta
		
		var progress: float = flash_data.timer / flash_data.duration
		if progress >= 1.0:
			completed_effects.append(entity_id)
			continue
		
		# Apply flash with ENHANCED visibility
		_apply_enhanced_flash_color(entity_id, flash_data, progress)
	
	# Clean up completed effects
	for entity_id in completed_effects:
		_reset_enemy_color(entity_id)
		flash_effects.erase(entity_id)

func _apply_enhanced_flash_color(entity_id: String, flash_data: Dictionary, progress: float) -> void:
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	if not mm_instance or not mm_instance.multimesh:
		return
	
	# ENHANCED COLOR CALCULATION for maximum visibility
	var flash_color: Color = flash_data.flash_color
	
	# Use exponential decay for dramatic flash
	var intensity: float = exp(-progress * 3.0)  # Faster decay, more dramatic
	
	# ADDITIVE color blending for bright flash
	var current_color: Color = Color.WHITE + (flash_color * intensity)
	
	# Debug output for verification
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Flash update: %s, progress=%.2f, intensity=%.2f, color=%s" % [entity_id, progress, intensity, current_color], "visual")
	
	# Apply the enhanced color
	mm_instance.multimesh.set_instance_color(instance_index, current_color)

func _find_enemy_in_multimesh(entity_id: String) -> Dictionary:
	# SIMPLIFIED lookup for debugging
	# In production, this would use the proper enemy index mapping
	
	# For now, return first available instance for testing
	if mm_enemies_swarm and mm_enemies_swarm.multimesh and mm_enemies_swarm.multimesh.instance_count > 0:
		return {"multimesh": mm_enemies_swarm, "index": 0}
	
	if mm_enemies_regular and mm_enemies_regular.multimesh and mm_enemies_regular.multimesh.instance_count > 0:
		return {"multimesh": mm_enemies_regular, "index": 0}
	
	return {}

func _reset_enemy_color(entity_id: String) -> void:
	var enemy_info: Dictionary = _find_enemy_in_multimesh(entity_id)
	if enemy_info.is_empty():
		return
	
	var mm_instance: MultiMeshInstance2D = enemy_info.multimesh
	var instance_index: int = enemy_info.index
	
	# Reset to white for proper color multiplication
	mm_instance.multimesh.set_instance_color(instance_index, Color.WHITE)
	Logger.debug("Reset color for entity: %s" % entity_id, "visual")

## DEBUG METHODS ##

func test_color_visibility() -> void:
	"""Test method to verify color changes are visible"""
	Logger.info("=== TESTING MULTIMESH COLOR VISIBILITY ===", "visual")
	
	var test_colors: Array[Color] = [
		Color.RED,                    # Basic red
		Color.YELLOW,                 # Basic yellow  
		Color(2.0, 2.0, 2.0, 1.0),   # Bright white
		Color(3.0, 1.0, 1.0, 1.0),   # Bright red
		Color(1.0, 3.0, 1.0, 1.0),   # Bright green
	]
	
	if mm_enemies_swarm and mm_enemies_swarm.multimesh:
		Logger.info("Testing colors on swarm MultiMesh...", "visual")
		for i in range(min(test_colors.size(), mm_enemies_swarm.multimesh.instance_count)):
			mm_enemies_swarm.multimesh.set_instance_color(i, test_colors[i])
			Logger.info("Instance %d: %s" % [i, test_colors[i]], "visual")

func get_debug_info() -> String:
	var info: String = "=== MultiMesh Hit Feedback Debug Info ===\n"
	info += "Visual Config Loaded: %s\n" % (visual_config != null)
	if visual_config:
		info += "Flash Duration: %ss\n" % visual_config.flash_duration
		info += "Flash Color: %s\n" % visual_config.flash_color
		info += "Flash Intensity: %s\n" % visual_config.flash_intensity
	
	info += "Active Flash Effects: %d\n" % flash_effects.size()
	
	var mm_info: Array[String] = []
	if mm_enemies_swarm and mm_enemies_swarm.multimesh:
		mm_info.append("Swarm: %d instances, colors=%s" % [mm_enemies_swarm.multimesh.instance_count, mm_enemies_swarm.multimesh.use_colors])
	if mm_enemies_regular and mm_enemies_regular.multimesh:
		mm_info.append("Regular: %d instances, colors=%s" % [mm_enemies_regular.multimesh.instance_count, mm_enemies_regular.multimesh.use_colors])
	
	info += "MultiMesh Status: " + ", ".join(mm_info) + "\n"
	
	return info