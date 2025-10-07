extends BaseBoss

## Ancient Slime Boss - Inherits from BaseBoss with poison-themed stats and attack behavior

class_name AncientSlime

# Wake-up mechanic properties
var has_woken_up: bool = false
var is_aggroed: bool = false

func _ready() -> void:
	# Set custom ancient slime stats
	max_health = 500.0
	current_health = 500.0
	damage = 40.0
	# speed will be set by BaseBoss from SpawnConfig - no override needed
	attack_damage = 40.0
	attack_cooldown = 1.0  # Slightly slower attacks
	attack_range = 125.0
	# chase_range = 320.0  # Using BaseBoss default (5500.0)

	# Prevent BaseBoss from auto-playing directional animations before wake-up
	animation_prefix = ""  # Will be set to "walking" after wake-up completes

	# Shadow is handled by BossShadow scene instance in the .tscn file

	# Call parent _ready() to handle all base initialization (including shadow setup)
	super._ready()

	# Apply spawn dissolve effect
	if animated_sprite:
		EnemySpawnEffect.apply_spawn_effect(animated_sprite, get_tree())
		Logger.debug("AncientSlime spawn dissolve effect applied", "bosses")

	# Setup wake-up animation - pause on first frame until player approaches
	if animated_sprite and animated_sprite.sprite_frames:
		# Check if wake_up animation exists, otherwise use first available animation
		if animated_sprite.sprite_frames.has_animation("wake_up"):
			animated_sprite.play("wake_up")
			animated_sprite.pause()  # Stay on first frame until aggroed
			animated_sprite.connect("animation_finished", _on_animation_finished)
		else:
			# Fall back to first available animation and pause it
			var anim_names = animated_sprite.sprite_frames.get_animation_names()
			if anim_names.size() > 0:
				animated_sprite.play(anim_names[0])
				animated_sprite.pause()
				has_woken_up = false  # Will wake up on aggro

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

# Override AI to implement wake-up mechanic
func _update_ai(_dt: float) -> void:
	if ai_paused:
		return
	if not PlayerState.has_player_reference():
		return

	target_position = PlayerState.position
	var distance_to_player = global_position.distance_to(target_position)

	# Trigger aggro when player gets close
	if distance_to_player <= chase_range and not is_aggroed:
		_aggro()
		return

	# Only move after fully waking up
	if not has_woken_up:
		return

	# Call base AI (handles chase, movement, directional animations)
	super._update_ai(_dt)

	# Future: Add slime-specific behaviors here
	# - Poison pools when health < 50%
	# - Slime split ability
	# - Slower movement when damaged

# Trigger wake-up animation when player approaches
func _aggro() -> void:
	if is_aggroed:
		return
	is_aggroed = true

	# Check if wake_up animation exists
	if animated_sprite.sprite_frames.has_animation("wake_up"):
		animated_sprite.play("wake_up")
	else:
		# No wake_up animation - just unpause current animation and wake up immediately
		animation_prefix = "walking"  # Enable directional animations
		animated_sprite.play()  # Resume current animation
		has_woken_up = true

# Complete wake-up and transition to default animation
func _on_animation_finished() -> void:
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		animation_prefix = "walking"  # Enable directional animations after wake-up
		animated_sprite.play("default")
