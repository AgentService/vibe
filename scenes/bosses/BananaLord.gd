extends BaseBoss

## Banana Lord Boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Now inherits from BaseBoss for unified systems support

class_name BananaLord

# BananaLord specific properties
var is_taking_damage: bool = false

func _ready() -> void:
	# Stats are set by setup_from_spawn_config() from template data (banana_lord.tres)
	# Only override attack-specific values not in template
	attack_cooldown = 1.5
	attack_range = 60.0

	# Call parent _ready() to handle base initialization (spawn effect + animation)
	super._ready()
	# Note: Wake-up animation (if present) plays during spawn dissolve (0.5s)

	# Connect animation finished for damage animation
	if animated_sprite:
		animated_sprite.connect("animation_finished", _on_animation_finished)

func get_boss_name() -> String:
	return "BananaLord"

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

# Override parent AI for BananaLord-specific behavior (optional)
func _update_ai(_dt: float) -> void:
	# IMPORTANT: Check spawn state first (from BaseBoss)
	if _is_spawning or ai_paused or _is_dying:
		return

	# Call parent AI behavior for standard movement and attacks
	super._update_ai(_dt)

	# Add BananaLord specific behavior here if needed

# Override parent attack with BananaLord-specific attack
func _perform_attack() -> void:
	# BananaLord attacks for damage
	
	# Apply physical damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_banana_lord"
		var damage_tags = ["physical", "boss"]  # Physical damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# BananaLord specific methods

func _on_animation_finished() -> void:
	# Handle damage animation completion
	if animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		animated_sprite.play("default")

func _trigger_damage_animation() -> void:
	# Trigger damage animation if not already playing
	if not is_taking_damage:
		is_taking_damage = true
		animated_sprite.play("damage_taken")
