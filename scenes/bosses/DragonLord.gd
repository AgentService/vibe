extends BaseBoss

## DragonLord special boss - example scene-based enemy
## Demonstrates hybrid spawning system with complex boss behavior
## Now inherits from BaseBoss for unified systems support

class_name DragonLord

func _ready() -> void:
	# Stats are set by setup_from_spawn_config() from template data (dragon_lord.tres)
	# Only override attack-specific values not in template
	attack_cooldown = 2.0
	attack_range = 90.0

	# Call parent _ready() to handle base initialization (spawn effect + animation)
	super._ready()
	# Note: Wake-up animation (if present) plays during spawn dissolve (0.5s)

func get_boss_name() -> String:
	return "DragonLord"

# Override parent attack with DragonLord-specific fire attack
func _perform_attack() -> void:
	Logger.debug("DragonLord breathes fire for %.1f damage!" % attack_damage, "bosses")
	
	# Apply fire damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_dragon_lord"
		var damage_tags = ["fire", "boss"]  # Fire damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# Override AI for DragonLord-specific behavior (optional)
func _update_ai(_dt: float) -> void:
	# IMPORTANT: Check spawn state first (from BaseBoss)
	if _is_spawning or ai_paused or _is_dying:
		return

	# Call parent AI behavior for standard movement and attacks
	super._update_ai(_dt)
