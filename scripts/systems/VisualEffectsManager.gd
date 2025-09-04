class_name VisualEffectsManager
extends Node

# Centralizes visual feedback systems for enemies and bosses
# Manages hit feedback, knockback effects, and flash animations

var enemy_hit_feedback: EnemyMultiMeshHitFeedback
var boss_hit_feedback: BossHitFeedback

# Configuration properties from Arena export vars
var boss_knockback_force: float = 1.0
var boss_knockback_duration: float = 1.0
var boss_hit_stop_duration: float = 0.1
var boss_velocity_decay: float = 1.0
var boss_flash_duration: float = 0.2
var boss_flash_intensity: float = 5.0

func setup_hit_feedback_systems() -> void:
	# Create enemy hit feedback system
	enemy_hit_feedback = EnemyMultiMeshHitFeedback.new()
	add_child(enemy_hit_feedback)

	# Create boss hit feedback system
	boss_hit_feedback = BossHitFeedback.new()
	# Apply configuration settings to the boss hit feedback system
	boss_hit_feedback.knockback_force_multiplier = boss_knockback_force
	boss_hit_feedback.knockback_duration_multiplier = boss_knockback_duration
	boss_hit_feedback.hit_stop_duration = boss_hit_stop_duration
	boss_hit_feedback.velocity_decay_factor = boss_velocity_decay
	boss_hit_feedback.flash_duration_override = boss_flash_duration
	boss_hit_feedback.flash_intensity_override = boss_flash_intensity
	add_child(boss_hit_feedback)
	
	Logger.info("VisualEffectsManager initialized with hit feedback systems", "effects")

func setup_enemy_feedback_references(swarm_mm: MultiMeshInstance2D, regular_mm: MultiMeshInstance2D, elite_mm: MultiMeshInstance2D, boss_mm: MultiMeshInstance2D) -> void:
	if enemy_hit_feedback:
		enemy_hit_feedback.setup_multimesh_references(swarm_mm, regular_mm, elite_mm, boss_mm)
		Logger.debug("Enemy hit feedback MultiMesh references configured", "effects")

func configure_enemy_feedback_dependencies(enemy_render_tier: EnemyRenderTier, wave_director: WaveDirector) -> void:
	if enemy_hit_feedback:
		if enemy_render_tier:
			enemy_hit_feedback.set_enemy_render_tier(enemy_render_tier)
		if wave_director:
			enemy_hit_feedback.set_wave_director(wave_director)
		Logger.debug("Enemy hit feedback dependencies configured", "effects")

func get_boss_hit_feedback() -> BossHitFeedback:
	return boss_hit_feedback

func get_enemy_hit_feedback() -> EnemyMultiMeshHitFeedback:
	return enemy_hit_feedback

# Configuration property setters (for Arena export var integration)
func set_boss_knockback_force(value: float) -> void:
	boss_knockback_force = value
	if boss_hit_feedback:
		boss_hit_feedback.knockback_force_multiplier = value

func set_boss_knockback_duration(value: float) -> void:
	boss_knockback_duration = value
	if boss_hit_feedback:
		boss_hit_feedback.knockback_duration_multiplier = value

func set_boss_hit_stop_duration(value: float) -> void:
	boss_hit_stop_duration = value
	if boss_hit_feedback:
		boss_hit_feedback.hit_stop_duration = value

func set_boss_velocity_decay(value: float) -> void:
	boss_velocity_decay = value
	if boss_hit_feedback:
		boss_hit_feedback.velocity_decay_factor = value

func set_boss_flash_duration(value: float) -> void:
	boss_flash_duration = value
	if boss_hit_feedback:
		boss_hit_feedback.flash_duration_override = value

func set_boss_flash_intensity(value: float) -> void:
	boss_flash_intensity = value
	if boss_hit_feedback:
		boss_hit_feedback.flash_intensity_override = value