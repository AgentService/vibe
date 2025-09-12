extends BaseBoss

## Ancient Slime Boss - Inherits from BaseBoss with poison-themed stats and attack behavior

class_name AncientSlime

func _ready() -> void:
	# Set custom ancient slime stats
	max_health = 500.0
	current_health = 500.0
	damage = 40.0
	speed = 60.0  # Slower than demon overlord (slime physics)
	attack_damage = 40.0
	attack_cooldown = 2.5  # Slightly slower attacks
	attack_range = 85.0
	chase_range = 320.0
	animation_prefix = "walking"  # Uses walking_north, walking_south, etc.
	
	# Shadow is handled by BossShadow scene instance in the .tscn file
	
	# Call parent _ready() to handle all base initialization (including shadow setup)
	super._ready()

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
		Logger.debug(get_boss_name() + " attack animation: " + attack_anim, "bosses")

# Optional: Override AI for custom slime behavior
func _update_ai(dt: float) -> void:
	# Call base AI first (handles chase, movement, directional animations)
	super._update_ai(dt)
	
	# Future: Add slime-specific behaviors here
	# - Poison pools when health < 50%
	# - Slime split ability 
	# - Slower movement when damaged
