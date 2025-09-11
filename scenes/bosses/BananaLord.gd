extends BaseBoss

## Banana Lord Boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Now inherits from BaseBoss for unified systems support

class_name BananaLord

# BananaLord specific properties
var has_woken_up: bool = false
var is_taking_damage: bool = false
var is_aggroed: bool = false

func _ready() -> void:
	# Set BananaLord specific stats (override BaseBoss defaults)
	max_health = 200.0
	current_health = 200.0
	damage = 25.0
	speed = 60.0
	attack_damage = 25.0
	attack_cooldown = 1.5
	attack_range = 60.0
	chase_range = 300.0
	
	# Call parent _ready() to handle base initialization
	super._ready()
	
	# BananaLord specific setup after base initialization
	_setup_banana_lord_behavior()

func get_boss_name() -> String:
	return "BananaLord"

# BananaLord specific setup after BaseBoss initialization
func _setup_banana_lord_behavior() -> void:
	# Start with wake_up animation and pause it on first frame  
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("wake_up")
		animated_sprite.pause()  # Stay on first frame until aggroed
		animated_sprite.connect("animation_finished", _on_animation_finished)
		Logger.debug("BananaLord spawned in dormant state", "bosses")

# Override _exit_tree to call parent cleanup
func _exit_tree() -> void:
	super._exit_tree()

# Override setup_from_spawn_config to call parent and add specific behavior
func setup_from_spawn_config(config: SpawnConfig) -> void:
	# Call parent setup first
	super.setup_from_spawn_config(config)
	
	# BananaLord specific spawn config handling
	Logger.info("BananaLord boss spawned: HP=%.1f DMG=%.1f SPD=%.1f Scale=%.2fx" % [max_health, damage, speed, config.size_scale], "bosses")
	
	# Note: Scaling is handled by unified scaling system in parent - no additional calls needed

# Override parent AI with BananaLord-specific wake-up behavior
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
	
	# Add BananaLord specific behavior here if needed

# Override parent attack with BananaLord-specific attack
func _perform_attack() -> void:
	Logger.debug("BananaLord attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Apply physical damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_banana_lord"
		var damage_tags = ["physical", "boss"]  # Physical damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# BananaLord specific methods

func _aggro() -> void:
	if is_aggroed:
		return
	is_aggroed = true
	Logger.debug("BananaLord aggroed - beginning wake up sequence!", "bosses")
	animated_sprite.play("wake_up")  # Resume/restart the wake up animation

func _on_animation_finished() -> void:
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		animated_sprite.play("default")
		Logger.debug("BananaLord fully awakened", "bosses")
	elif animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		animated_sprite.play("default")

func _trigger_damage_animation() -> void:
	# Trigger damage animation if not already playing and boss is awake
	if not is_taking_damage and has_woken_up:
		is_taking_damage = true
		animated_sprite.play("damage_taken")
