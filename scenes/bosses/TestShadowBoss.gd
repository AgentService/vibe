extends BaseBoss

## Test Boss - Demonstrates shadow system integration with BaseBoss
## Simple boss for testing shadow functionality

class_name TestShadowBoss

# Wake-up mechanic properties
var has_woken_up: bool = false
var is_aggroed: bool = false

func _ready() -> void:
	# Call parent _ready() to handle all base initialization (stats applied via SpawnConfig)
	super._ready()

	# Apply spawn dissolve effect
	if animated_sprite:
		EnemySpawnEffect.apply_spawn_effect(animated_sprite, get_tree())
		Logger.debug("TestShadowBoss spawn dissolve effect applied", "bosses")

	# Setup wake-up animation - pause on first frame until player approaches
	if animated_sprite and animated_sprite.sprite_frames:
		# CRITICAL: Stop any animation set in scene file
		animated_sprite.stop()

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
	return "TestShadowBoss"

# Required: Implement boss's attack behavior
func _perform_attack() -> void:
	Logger.debug("TestShadowBoss attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Apply damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_test_shadow"
		var damage_tags = ["physical", "boss", "test"]
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

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

	super._update_ai(_dt)

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
		animated_sprite.play()  # Resume current animation
		has_woken_up = true

# Complete wake-up and transition to default animation
func _on_animation_finished() -> void:
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		animated_sprite.play("default")
