extends BaseBoss

## Ancient Lich Boss - V2 Enemy System Integration  
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Now inherits from BaseBoss for automatic shadow and unified systems support

class_name AncientLich

# AncientLich specific properties
var has_woken_up: bool = false
var is_taking_damage: bool = false
var is_aggroed: bool = false

func _ready() -> void:
	# Set AncientLich specific stats (override BaseBoss defaults)
	max_health = 200.0
	current_health = 200.0
	damage = 25.0
	speed = 60.0
	attack_damage = 25.0
	attack_cooldown = 1.5
	attack_range = 60.0
	chase_range = 300.0
	
	# Configure shadow (larger shadow for DragonLord)
	shadow_enabled = true
	# shadow_size_multiplier = 4.2  # Dragon-specific override: bigger shadow
	# shadow_opacity = 0.8         # Uncomment for darker shadow
	# shadow_offset_y = 0.0         # Dragon-specific override: much lower shadow
	
	# Call parent _ready() to handle base initialization (damage system, shadow setup, etc.)
	super._ready()
	
	# AncientLich specific setup after base initialization
	_setup_ancient_lich_specific_behavior()

func get_boss_name() -> String:
	return "AncientLich"

func _setup_ancient_lich_specific_behavior() -> void:
	# Start with wake_up animation and pause it on first frame
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("wake_up")
		animated_sprite.pause()  # Stay on first frame until aggroed
		animated_sprite.connect("animation_finished", _on_animation_finished)
		Logger.debug("AncientLich spawned in dormant state", "bosses")

# Override _exit_tree to call parent cleanup
func _exit_tree() -> void:
	super._exit_tree()

# Override setup_from_spawn_config to call parent and add specific behavior
func setup_from_spawn_config(config: SpawnConfig) -> void:
	# Call parent setup first
	super.setup_from_spawn_config(config)
	
	# AncientLich specific spawn config handling
	Logger.info("AncientLich boss spawned: HP=%.1f DMG=%.1f SPD=%.1f Scale=%.2fx" % [max_health, damage, speed, config.size_scale], "bosses")
	
	# Note: Scaling is handled by unified scaling system in parent - no additional calls needed

# Override parent _on_damage_entity_sync to add AncientLich specific damage handling
func _on_damage_entity_sync(payload: Dictionary) -> void:
	# Call parent damage sync handling first
	super._on_damage_entity_sync(payload)
	
	# Add AncientLich specific damage response
	var entity_id: String = payload.get("entity_id", "")
	var expected_entity_id = "boss_" + str(get_instance_id())
	if entity_id == expected_entity_id and not payload.get("is_death", false):
		_trigger_damage_animation()

# Override parent AI with AncientLich-specific wake-up behavior
func _update_ai(_dt: float) -> void:
	# Skip AI updates if paused by debug system
	if ai_paused:
		return
		
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
	
	# Call parent AI behavior for standard movement and attacks
	super._update_ai(_dt)
	
	# Add AncientLich specific behavior here if needed

# Override parent attack with AncientLich-specific magic damage
func _perform_attack() -> void:
	Logger.debug("AncientLich attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Apply magic damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_ancient_lich"
		var damage_tags = ["magic", "boss"]  # Magic damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# AncientLich specific methods

func _aggro() -> void:
	if is_aggroed:
		return
	is_aggroed = true
	Logger.debug("AncientLich aggroed - beginning wake up sequence!", "bosses")
	animated_sprite.play("wake_up")  # Resume/restart the wake up animation

func _on_animation_finished() -> void:
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		animated_sprite.play("default")
		Logger.debug("AncientLich fully awakened", "bosses")
	elif animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		animated_sprite.play("default")

func _trigger_damage_animation() -> void:
	# Trigger damage animation if not already playing and boss is awake
	if not is_taking_damage and has_woken_up:
		is_taking_damage = true
		animated_sprite.play("damage_taken")
