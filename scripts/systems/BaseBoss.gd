extends CharacterBody2D

## Unified boss base class for AnimatedSprite2D scene-based bosses
## Provides common functionality: health management, damage integration, deterministic AI
## Emits typed signals for decoupled UI updates per .clinerules

class_name BaseBoss

# Damage visual feedback mode
enum DamageVisualMode {
	ANIMATION,  ## Use damage_taken animation if it exists (default)
	SHADER      ## Use shader-based white flash effect
}

# Typed signals for decoupled communication
signal health_changed(current: float, max: float)
signal died(entity_id: String)

# Visual feedback configuration
@export_group("Damage Visual Feedback")
@export var damage_visual_mode: DamageVisualMode = DamageVisualMode.ANIMATION
@export_range(0.1, 1.0) var flash_duration: float = 0.2
@export_range(0.1, 2.0) var flash_intensity: float = 1.0

# Core stats
var entity_id: String = ""
var max_health: float = 200.0
var current_health: float = 200.0
var damage: float = 25.0
var speed: float = 60.0
var attack_damage: float = 25.0
var attack_cooldown: float = 1.5
var last_attack_time: float = 0.0

# AI state
var target_position: Vector2
var attack_range: float = 60.0
var chase_range: float = 300.0

# Animation state
var has_woken_up: bool = false
var is_taking_damage: bool = false
var is_aggroed: bool = false

# Shader flash state
var flash_material: ShaderMaterial
var original_material: Material
var flash_tween: Tween

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	Logger.info("BaseBoss ready: " + str(get_script().get_global_name()), "bosses")
	
	# Connect to combat step for deterministic behavior
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
	
	# Initialize animation state - start dormant
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("wake_up")
		animated_sprite.pause()  # Stay on first frame until aggroed
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.connect("animation_finished", _on_animation_finished)
		Logger.debug("Boss spawned in dormant state", "bosses")
	
	# Setup shader flash if in SHADER mode
	if damage_visual_mode == DamageVisualMode.SHADER:
		_setup_shader_flash()
		Logger.info("Boss configured for SHADER damage feedback, intensity: " + str(flash_intensity), "bosses")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	
	# Unregister from DamageService
	if not entity_id.is_empty():
		DamageService.unregister_entity(entity_id)
		Logger.debug("BaseBoss unregistered: " + entity_id, "bosses")
	
	# Clean up flash tween
	if flash_tween:
		flash_tween.kill()
		flash_tween = null

## Setup boss from SpawnConfig with stable entity ID
func setup_from_spawn_config(config: SpawnConfig) -> void:
	# Extract stats from config
	max_health = config.health
	current_health = config.health
	damage = config.damage  
	speed = config.speed
	attack_damage = config.damage
	
	# Set position and visual properties
	global_position = config.position
	scale = Vector2.ONE * config.size_scale
	
	# Set stable entity ID from SpawnConfig
	if config.has_method("get_entity_id") and not config.get_entity_id().is_empty():
		entity_id = config.get_entity_id()
	else:
		# Fallback to template-based ID if SpawnConfig doesn't have entity_id yet
		entity_id = "boss:" + str(config.template_id) + ":" + str(get_instance_id())
		Logger.warn("SpawnConfig missing entity_id, using fallback: " + entity_id, "bosses")
	
	# Register with DamageService using stable ID
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": current_health,
		"max_hp": max_health,
		"alive": true,
		"pos": global_position,
		"node_reference": self  # Store reference for sync_damage_to_game_entity
	}
	DamageService.register_entity(entity_id, entity_data)
	
	# Emit initial health state (BossHealthBar will receive this)
	health_changed.emit(current_health, max_health)
	
	Logger.info("BaseBoss configured: ID=%s HP=%.1f DMG=%.1f SPD=%.1f" % [entity_id, max_health, damage, speed], "bosses")

func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	_update_ai(dt)
	last_attack_time += dt

func _update_ai(dt: float) -> void:
	# Get player position from PlayerState
	if not PlayerState.has_player_reference():
		return
		
	target_position = PlayerState.position
	var distance_to_player: float = global_position.distance_to(target_position)
	
	# Trigger aggro when player gets close
	if distance_to_player <= chase_range and not is_aggroed:
		_aggro()
		return
	
	# Only move after fully waking up
	if not has_woken_up:
		return
	
	# Custom AI can override this behavior
	if _update_custom_ai(dt, distance_to_player):
		return
	
	# Default chase behavior when player is in range
	if distance_to_player <= chase_range:
		if distance_to_player > attack_range:
			# Move toward player
			var direction: Vector2 = (target_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			# In attack range - stop and attack
			velocity = Vector2.ZERO
			if last_attack_time >= attack_cooldown:
				_perform_attack()
				last_attack_time = 0.0

## Override point for custom boss AI behavior
## @return bool: true if custom AI handled the behavior, false to use default
func _update_custom_ai(dt: float, distance: float) -> bool:
	return false  # Default: use base AI

func _perform_attack() -> void:
	Logger.debug("BaseBoss attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Route attack through DamageService (unified pipeline)
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		# Check if player is registered with DamageService
		if DamageService.is_entity_alive("player"):
			var damage_applied = DamageService.apply_damage("player", attack_damage, entity_id, ["boss", "melee"])
			Logger.debug("Boss attack result: " + str(damage_applied), "bosses")
		else:
			# Player not registered - this is expected in current implementation
			Logger.debug("Player not registered with damage system - skipping boss attack", "bosses")
	
	# Custom attack behavior can be added in derived classes
	_perform_custom_attack()

## Override point for custom attack behavior
func _perform_custom_attack() -> void:
	pass  # Default: no custom behavior

## Called by DamageService when this boss takes damage
func set_current_health(new_health: float) -> void:
	var old_health = current_health
	current_health = new_health
	
	# Emit health change signal for UI updates (BossHealthBar subscribes to this)
	health_changed.emit(current_health, max_health)
	
	# Play damage visual feedback if health decreased
	if new_health < old_health and has_woken_up:
		_play_damage_feedback()
	
	# Check for death
	if current_health <= 0.0 and is_alive():
		_die()

## Public health interface
func get_current_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

func is_alive() -> bool:
	return current_health > 0.0

func _die() -> void:
	Logger.info("BaseBoss defeated: " + entity_id, "bosses")
	
	# Immediately unregister from DamageService to prevent dead entity warnings
	if not entity_id.is_empty():
		DamageService.unregister_entity(entity_id)
		Logger.debug("BaseBoss unregistered on death: " + entity_id, "bosses")
	
	died.emit(entity_id)
	# Use call_deferred to ensure signal is processed before freeing
	call_deferred("queue_free")

func _aggro() -> void:
	if is_aggroed:
		return
	is_aggroed = true
	Logger.debug("BaseBoss aggroed - beginning wake up sequence!", "bosses")
	if animated_sprite:
		animated_sprite.play("wake_up")  # Resume/restart the wake up animation

func _on_animation_finished() -> void:
	if not animated_sprite:
		return
		
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")
		Logger.debug("BaseBoss fully awakened", "bosses")
	elif animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

## Setup animations - override point for custom animation setup
func _setup_animations() -> void:
	pass  # Override in derived classes

## Play animation safely - checks if animation exists
func _play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		Logger.warn("Animation not found: " + anim_name, "bosses")

## Setup shader flash material for SHADER damage mode
func _setup_shader_flash() -> void:
	if not animated_sprite:
		Logger.warn("No AnimatedSprite2D found for shader flash setup", "bosses")
		return
	
	# Store original material
	original_material = animated_sprite.material
	
	# Load and setup flash material
	var base_material = load("res://shaders/boss_flash_material.tres") as ShaderMaterial
	if base_material:
		# Create a unique instance for this boss
		flash_material = base_material.duplicate() as ShaderMaterial
		Logger.debug("Shader flash material loaded successfully", "bosses")
	else:
		Logger.warn("Failed to load boss flash shader material", "bosses")

## Play damage feedback based on configured mode
func _play_damage_feedback() -> void:
	if is_taking_damage:
		return  # Already playing damage feedback
		
	is_taking_damage = true
	
	match damage_visual_mode:
		DamageVisualMode.ANIMATION:
			_play_animation_feedback()
		DamageVisualMode.SHADER:
			_play_shader_feedback()

## Play animation-based damage feedback
func _play_animation_feedback() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("damage_taken"):
		animated_sprite.play("damage_taken")
		Logger.debug("Playing damage_taken animation", "bosses")
	else:
		# Fallback: no animation available, end damage state immediately
		is_taking_damage = false
		Logger.debug("No damage_taken animation available, using instant feedback", "bosses")

## Play shader-based damage feedback
func _play_shader_feedback() -> void:
	if not flash_material or not animated_sprite:
		is_taking_damage = false
		Logger.warn("Shader flash not available - flash_material: " + str(flash_material != null) + ", animated_sprite: " + str(animated_sprite != null), "bosses")
		return
	
	# Apply flash material
	animated_sprite.material = flash_material
	Logger.info("Applied shader material to sprite", "bosses")
	
	# Create tween for flash effect
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween()
	flash_tween.set_ease(Tween.EASE_OUT)
	flash_tween.set_trans(Tween.TRANS_QUART)
	
	# Flash bright then fade out
	flash_material.set_shader_parameter("flash_modifier", flash_intensity)
	flash_tween.tween_method(_update_flash_intensity, flash_intensity, 0.0, flash_duration)
	flash_tween.tween_callback(_end_shader_feedback)
	
	Logger.info("Started shader flash feedback with intensity: " + str(flash_intensity) + ", duration: " + str(flash_duration), "bosses")

## Update flash intensity during tween
func _update_flash_intensity(intensity: float) -> void:
	if flash_material:
		flash_material.set_shader_parameter("flash_modifier", intensity)

## End shader feedback and restore original material
func _end_shader_feedback() -> void:
	if animated_sprite:
		animated_sprite.material = original_material
	is_taking_damage = false
	Logger.debug("Ended shader flash feedback", "bosses")
