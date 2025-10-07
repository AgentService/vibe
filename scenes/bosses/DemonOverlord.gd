extends BaseBoss

## Demon Overlord Boss - Inherits from BaseBoss with custom stats and attack behavior

class_name DemonOverlord

func _ready() -> void:
	# Stats are set by setup_from_spawn_config() from template data (demon_overlord.tres)
	# Only override attack-specific values not in template
	attack_cooldown = 1.8
	attack_range = 90.0
	animation_prefix = "scary_walk"  # Uses scary_walk_north, scary_walk_south, etc.

	# Call parent _ready() to handle all base initialization (spawn effect + animation)
	super._ready()
	# Note: Wake-up animation (if present) plays during spawn dissolve (0.5s)

func get_boss_name() -> String:
	return "DemonOverlord"

func _perform_attack() -> void:
	Logger.debug("DemonOverlord unleashes demonic fury for %.1f damage!" % attack_damage, "bosses")
	
	# Apply fire/demon damage to player
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_demon_overlord"
		var damage_tags = ["fire", "boss", "demon"]
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# Override AI for DemonOverlord-specific behavior (optional)
func _update_ai(_dt: float) -> void:
	# IMPORTANT: Check spawn state first (from BaseBoss)
	if _is_spawning or ai_paused or _is_dying:
		return

	# Call base AI (handles chase, movement, directional animations)
	super._update_ai(_dt)

	# Add any custom demon overlord AI behavior here
	# For example: special attacks, phase changes, etc.
