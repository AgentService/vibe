extends BaseBoss

## Ancient Slime Boss - Inherits from BaseBoss with poison-themed stats and attack behavior

class_name AncientSlime

func _ready() -> void:
	# Stats are set by setup_from_spawn_config() from template data (ancient_slime.tres)
	# Only override attack-specific values not in template
	attack_cooldown = 2.5  # Slightly slower attacks
	attack_range = 85.0
	animation_prefix = "walking"  # Uses walking_north, walking_south, etc.

	# Shadow is handled by BossShadow scene instance in the .tscn file

	# Call parent _ready() to handle all base initialization (spawn effect + animation)
	super._ready()
	# Note: Wake-up animation (if present) plays during spawn dissolve (0.5s)

func get_boss_name() -> String:
	return "AncientSlime"

# Required: Implement slime's poison attack behavior
func _perform_attack() -> void:
	Logger.debug("AncientSlime unleashes toxic ooze for %.1f poison damage!" % attack_damage, "bosses")
	
	# Apply poison/acid damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_ancient_slime"
		var damage_tags = ["poison", "boss", "acid"]  # Thematic slime damage
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)
		
		# Play attack animation if available
		_play_attack_animation()

# Custom animation system for 4-directional slime (no diagonals)
func _play_attack_animation() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	var attack_anim: String = "attack_south"  # Default fallback
	
	# Convert movement direction to closest cardinal direction for attack
	if abs(current_direction.x) > abs(current_direction.y):
		# Horizontal movement dominates
		if current_direction.x > 0:
			attack_anim = "attack_east"
		else:
			attack_anim = "attack_west"
	else:
		# Vertical movement dominates  
		if current_direction.y > 0:
			attack_anim = "attack_south"
		else:
			attack_anim = "attack_north"
	
	# Play attack animation if it exists
	if animated_sprite.sprite_frames.has_animation(attack_anim):
		animated_sprite.play(attack_anim)

# Override AI for slime-specific behavior (optional)
func _update_ai(_dt: float) -> void:
	# IMPORTANT: Check spawn state first (from BaseBoss)
	if _is_spawning or ai_paused or _is_dying:
		return

	# Call base AI (handles chase, movement, directional animations)
	super._update_ai(_dt)

	# Future: Add slime-specific behaviors here
	# - Poison pools when health < 50%
	# - Slime split ability
	# - Slower movement when damaged
