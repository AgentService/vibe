extends CharacterBody2D

## BaseBoss - Base class for all scene-based bosses
## Provides unified damage integration, performance optimization, and directional animation logic

class_name BaseBoss

signal died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: BossHealthBar = $BossHealthBar

# Entity ID for damage system integration
var entity_id: String = ""

# Boss configuration (override in child classes)
var spawn_config: SpawnConfig
var max_health: float = 300.0
var current_health: float = 300.0
var damage: float = 40.0
var speed: float = 100.0
var attack_damage: float = 40.0
var attack_cooldown: float = 2.0
var last_attack_time: float = 0.0

# AI configuration (override in child classes)
var target_position: Vector2
var attack_range: float = 80.0
var chase_range: float = 5500.0
var ai_paused: bool = false
var _is_dying: bool = false  # Flag to prevent AI updates during death/removal
var _is_spawning: bool = true  # Flag to pause AI during spawn animation

# DUAL COLLISION SYSTEM: Signal-based boss spacing via PersonalSpaceArea
const PERSONAL_SPACE_ENABLED: bool = false  # Enable enemy spacing to prevent overlapping
const PERSONAL_SPACE_STRENGTH: float = 2.5  # Increased spacing force for better enemy separation
var nearby_bosses: Array[CharacterBody2D] = []  # Bosses currently in personal space
var personal_space_area: Area2D = null  # Reference to PersonalSpaceArea child node

# PERFORMANCE FLAGS: High enemy count optimizations (500+ enemies)
const SKIP_SPAWN_ANIMATION: bool = true  # Skip 0.5s spawn dissolve effect (cyan edge glow)
const SKIP_WAKEUP_CHECK: bool = true  # Skip wake_up → default animation transition check

# Animation configuration
var current_direction: Vector2 = Vector2.DOWN
var animation_prefix: String = "walk"  # Override in child classes (e.g., "scary_walk")

# SPAWN/DEATH BEHAVIOR CONFIGURATION (future extensibility)
# NOTE: Currently all enemies use "dissolve" spawn (0.5s) + no death effect
# Future: Add EnemyType.spawn_behavior enum to customize per-enemy
# Possible values: "immediate", "dissolve", "dramatic" (longer dissolve), "wake_up" (boss-specific)
# Death effects: Follow same pattern as spawn with EnemyDeathEffect.gd

# Child classes should override these methods
func get_boss_name() -> String:
	return "BaseBoss"

func _perform_attack() -> void:
	Logger.debug(get_boss_name() + " attacks for %.1f damage!" % attack_damage, "bosses")
	# Child classes should implement specific attack behavior

func _ready() -> void:
	# SPAWN SYSTEM: Start in spawning group (not targetable yet)
	add_to_group("spawning")
	add_to_group("enemies")  # Functional group for all enemies

	# PERFORMANCE: Disable enemy-to-enemy collision for high entity counts
	# Layer 2 (Bosses): Enemy exists on this layer (so projectiles/player can hit them)
	# Mask 1 (Terrain): Enemy only collides with terrain (enemies pass through each other)
	collision_layer = 2  # Exist on Layer 2
	collision_mask = 1   # Collide with Layer 1 only (terrain)

	# Setup personal space area BEFORE spawn animation (needed for _on_spawn_animation_complete)
	if PERSONAL_SPACE_ENABLED:
		_setup_personal_space_area()
		# Disable monitoring during spawn, re-enabled in _on_spawn_animation_complete()
		if personal_space_area:
			personal_space_area.monitoring = false

	# FUTURE EXTENSIBILITY: Customize spawn behavior per-enemy
	# Example with spawn_config.spawn_behavior enum:
	#   match spawn_config.spawn_behavior:
	#       "immediate": _on_spawn_animation_complete()  # Skip effect
	#       "dissolve": _apply_dissolve_spawn()          # Current default
	#       "dramatic": _apply_dissolve_spawn(1.5)       # Longer duration
	#       "wake_up": _apply_wake_up_spawn()            # Boss-specific

	# SPAWN ANIMATION: Play wake_up animation during spawn if available, otherwise default
	# This ensures consistent 0.5s spawn timing regardless of animation presence
	# Performance: Can be disabled via SKIP_SPAWN_ANIMATION for high enemy counts
	if not SKIP_SPAWN_ANIMATION and animated_sprite and animated_sprite.sprite_frames:
		# Try wake_up animation first (plays during spawn dissolve)
		if animated_sprite.sprite_frames.has_animation("wake_up"):
			animated_sprite.play("wake_up")
		else:
			# Fallback to default directional animation
			var default_anim = animation_prefix + "_south"
			if animated_sprite.sprite_frames.has_animation(default_anim):
				animated_sprite.play(default_anim)

		# Apply spawn dissolve effect (0.5s animation) - runs alongside animation
		var spawn_tween = EnemySpawnEffect.apply_spawn_effect(animated_sprite, get_tree())
		if spawn_tween:
			spawn_tween.finished.connect(_on_spawn_animation_complete)
		else:
			# Fallback if effect system not initialized
			Logger.warn("EnemySpawnEffect failed for %s - immediately targetable" % get_boss_name(), "spawn")
			_on_spawn_animation_complete()
	else:
		# Skip spawn animation for performance or no sprite available
		_on_spawn_animation_complete()

	# BOSS PERFORMANCE V2: Register with centralized BossUpdateManager
	var boss_id = "boss_" + str(get_instance_id())
	BossUpdateManager.register_boss(self, boss_id)
	Logger.debug(get_boss_name() + " registered with BossUpdateManager as " + boss_id, "performance")

	# Connect to signals
	if EventBus:
		# DAMAGE V3: Listen for unified damage sync events
		EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
		# DEBUG: Listen for cheat toggles (AI pause)
		EventBus.cheat_toggled.connect(_on_cheat_toggled)
		# LIFECYCLE: Stop AI when player dies to prevent physics errors
		EventBus.player_died.connect(_on_player_died)

	# DAMAGE V3: Register with both DamageService and EntityTracker
	entity_id = "boss_" + str(get_instance_id())  # Store in property for external access
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": current_health,
		"max_hp": max_health,
		"alive": true,
		"pos": global_position
	}

	# Register with both systems for unified damage V3
	DamageService.register_entity(entity_id, entity_data)
	EntityTracker.register_entity(entity_id, entity_data)

	# Initialize health bar
	_update_health_bar()


func _exit_tree() -> void:
	# BOSS PERFORMANCE V2: Unregister from BossUpdateManager
	var boss_id = "boss_" + str(get_instance_id())
	BossUpdateManager.unregister_boss(boss_id)

	# Clean up signal connections
	if EventBus and EventBus.damage_entity_sync.is_connected(_on_damage_entity_sync):
		EventBus.damage_entity_sync.disconnect(_on_damage_entity_sync)
	if EventBus and EventBus.cheat_toggled.is_connected(_on_cheat_toggled):
		EventBus.cheat_toggled.disconnect(_on_cheat_toggled)

	# DAMAGE V3: Unregister from both systems
	var entity_id = "boss_" + str(get_instance_id())
	DamageService.unregister_entity(entity_id)
	EntityTracker.unregister_entity(entity_id)

## SPAWN SYSTEM: Called when spawn animation completes - makes enemy targetable and resumes AI
func _on_spawn_animation_complete() -> void:
	_is_spawning = false  # Resume AI
	remove_from_group("spawning")
	add_to_group("targetable")

	# Enable personal space detection now that spawn is complete
	if PERSONAL_SPACE_ENABLED and personal_space_area:
		personal_space_area.monitoring = true

	# Ensure default animation is playing after spawn (in case wake_up animation was used)
	# Performance: Can be disabled via SKIP_WAKEUP_CHECK to avoid expensive animation queries
	if not SKIP_WAKEUP_CHECK and animated_sprite and animated_sprite.sprite_frames:
		# If wake_up was playing, switch to default
		if animated_sprite.animation == "wake_up":
			var default_anim = animation_prefix + "_south"
			if animated_sprite.sprite_frames.has_animation(default_anim):
				animated_sprite.play(default_anim)

func setup_from_spawn_config(config: SpawnConfig) -> void:
	spawn_config = config
	max_health = config.health
	current_health = config.health
	damage = config.damage
	# speed = config.speed  # Use BaseBoss.gd default instead (line 21: speed = 100.0)
	attack_damage = config.damage
	
	# Set position
	global_position = config.position
	
	# Apply unified scaling system
	var scale_factor = config.size_scale
	apply_unified_scaling(scale_factor)
	
	
## UNIFIED SCALING SYSTEM: Apply consistent scaling to all boss components
func apply_unified_scaling(scale_factor: float) -> void:

	# Step 1: Scale sprite (visual component) - always defer to ensure node readiness
	call_deferred("_apply_sprite_scaling", scale_factor)
	
	# Step 2: Scale collision shape (physics/movement)
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		var old_scale = collision_shape.scale
		collision_shape.scale = Vector2.ONE * scale_factor
	else:
		Logger.warn("CollisionShape2D not found for scaling", "debug")
	
	# Step 3: Scale hitbox (combat detection) - only parent Area2D, child inherits
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		var old_scale = hitbox.scale
		hitbox.scale = Vector2.ONE * scale_factor
	else:
		Logger.warn("HitBox not found for scaling", "debug")
	
	# Step 4: Notify all scalable components after scaling changes
	call_deferred("_notify_components_scaled", scale_factor)
	
## COMPONENT SCALING NOTIFICATION: Notify all components that boss has been scaled
func _notify_components_scaled(scale_factor: float) -> void:
	
	# Notify health bar to readjust
	var health_bar = get_node_or_null("BossHealthBar")
	if health_bar and health_bar.has_method("auto_adjust_to_hitbox"):
		health_bar.auto_adjust_to_hitbox()
	
	# Future: Add other scalable components here
	# Example: if weapon_effect: weapon_effect.on_boss_scaled(scale_factor)

## BOSS PERFORMANCE V2: Batch AI interface called by BossUpdateManager
func _update_ai_batch(dt: float) -> void:
	_update_ai(dt)
	last_attack_time += dt

## STAGGERED AI: Physics process runs EVERY frame (30Hz) even when AI is staggered
## This ensures smooth movement - AI calculates velocity every 20 frames, physics applies it every frame
func _physics_process(delta: float) -> void:
	# Always apply movement if we have velocity (even when AI doesn't update)
	if velocity.length_squared() > 0.01:
		move_and_slide()

## Base AI logic - simple every-frame updates
## Child classes can override or extend
func _update_ai(dt: float) -> void:
	# Skip AI updates if dying, paused, spawning, or being removed
	if _is_dying or ai_paused or _is_spawning:
		return

	# Skip if boss is being removed or not in tree
	if not is_inside_tree() or is_queued_for_deletion():
		return

	# Get player position from PlayerState
	if not PlayerState.has_player_reference():
		return

	target_position = PlayerState.position
	var distance_to_player: float = global_position.distance_to(target_position)

	# Chase behavior when player is in range
	if distance_to_player <= chase_range:
		if distance_to_player > attack_range:
			# Move toward player - simple velocity calculation
			var direction: Vector2 = (target_position - global_position).normalized()
			velocity = direction * speed

			# DUAL COLLISION SYSTEM: Add personal space forces from nearby bosses
			if PERSONAL_SPACE_ENABLED:
				var spacing_force = apply_personal_space_forces()
				if spacing_force.length_squared() > 0.1:
					Logger.debug("%s applying personal space force: %.1f px/s" % [get_boss_name(), spacing_force.length()], "collision")
				velocity += spacing_force

			# Safety check before physics update
			if not is_inside_tree() or is_queued_for_deletion():
				return

			# STAGGERED AI: Don't call move_and_slide() here - handled in _physics_process()
			# This allows AI to update every 20 frames while physics runs every frame

			# Update directional animation automatically
			_update_directional_animation(direction)
			current_direction = direction

			# Update position in damage system
			DamageService.update_entity_position(entity_id, global_position)
		else:
			# In attack range - stop and attack
			velocity = Vector2.ZERO

			# Update facing direction for attacks (but don't override attack animations)
			var direction_to_player: Vector2 = (target_position - global_position).normalized()
			current_direction = direction_to_player

			if last_attack_time >= attack_cooldown:
				_perform_attack()
				last_attack_time = 0.0
			# Note: Don't play walking animations during attack cooldown
			# Let the attack animation from _perform_attack() play uninterrupted

## DIRECTIONAL ANIMATION SYSTEM
## Automatically converts movement direction to appropriate 8-directional animation
## Falls back to sprite flipping if directional animations don't exist
func _update_directional_animation(direction: Vector2) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	# Try 8-directional animations
	if _try_directional_animation(direction):
		return

	# Fallback: Use basic sprite flipping for non-directional sprites
	_apply_sprite_flipping(direction)

## Try to use 8-directional animations
func _try_directional_animation(direction: Vector2) -> bool:
	# Convert direction to 8-directional animation
	var angle = direction.angle()
	var animation_name = animation_prefix + "_"

	# Convert angle to 8 directions
	if angle >= -PI/8 and angle < PI/8:
		animation_name += "east"
	elif angle >= PI/8 and angle < 3*PI/8:
		animation_name += "south_east"
	elif angle >= 3*PI/8 and angle < 5*PI/8:
		animation_name += "south"
	elif angle >= 5*PI/8 and angle < 7*PI/8:
		animation_name += "south_west"
	elif angle >= 7*PI/8 or angle < -7*PI/8:
		animation_name += "west"
	elif angle >= -7*PI/8 and angle < -5*PI/8:
		animation_name += "north_west"
	elif angle >= -5*PI/8 and angle < -3*PI/8:
		animation_name += "north"
	else:  # -3*PI/8 to -PI/8
		animation_name += "north_east"

	# Check if the directional animation exists
	if animated_sprite.sprite_frames.has_animation(animation_name):
		# Only change animation if it's different
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
		return true  # Return true because directional animation exists (whether we changed it or not)

	# Fallback: Try cardinal direction if diagonal doesn't exist (for 4-directional sprites)
	var fallback_name = animation_prefix + "_"
	if abs(direction.x) > abs(direction.y):
		# Horizontal movement dominates
		fallback_name += "east" if direction.x > 0 else "west"
	else:
		# Vertical movement dominates
		fallback_name += "south" if direction.y > 0 else "north"

	# Check if cardinal fallback exists
	if animated_sprite.sprite_frames.has_animation(fallback_name):
		# Only change animation if it's different
		if animated_sprite.animation != fallback_name:
			animated_sprite.play(fallback_name)
		return true  # Return true because we found a fallback animation

	return false  # No directional animation exists

## Apply basic sprite flipping when directional animations aren't available
func _apply_sprite_flipping(direction: Vector2) -> void:
	if not animated_sprite:
		return

	# Use simple left/right flipping based on horizontal movement
	if abs(direction.x) > 0.1:  # Only flip if there's significant horizontal movement
		animated_sprite.flip_h = direction.x < 0  # Flip when moving left

	# Ensure the boss is playing some animation (use default if available)
	if animated_sprite.sprite_frames and not animated_sprite.is_playing():
		if animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")
		elif animated_sprite.sprite_frames.has_animation(animation_prefix):
			animated_sprite.play(animation_prefix)

# OLD SEPARATION SYSTEM REMOVED - Now using PersonalSpaceArea + collision layers

## DAMAGE V3: Handle unified damage sync events for scene bosses
func _on_damage_entity_sync(payload: Dictionary) -> void:
	var entity_id: String = payload.get("entity_id", "")
	var entity_type: String = payload.get("entity_type", "")
	var new_hp: float = payload.get("new_hp", 0.0)
	var is_death: bool = payload.get("is_death", false)
	
	# Only handle boss entities matching this instance
	if entity_type != "boss":
		return
	
	var expected_entity_id = "boss_" + str(get_instance_id())
	if entity_id != expected_entity_id:
		return
	
	# Update boss HP
	current_health = new_hp
	_update_health_bar()
	
	# Handle death
	if is_death:
		Logger.info("V3: Boss %s killed via damage sync" % [entity_id], "combat")
		_die()
	else:
		# Update EntityTracker health data
		var tracker_data = EntityTracker.get_entity(entity_id)
		if tracker_data.has("id"):
			tracker_data["hp"] = new_hp

func _die() -> void:
	_is_dying = true  # Prevent any further AI updates

	# FUTURE: Add death dissolve effect (reverse of spawn)
	# Example: EnemyDeathEffect.apply_death_effect(animated_sprite, 0.4)
	#   - Reverse progress: 0.0 → 1.0 (visible → invisible)
	#   - Keep enemy alive during effect, queue_free() after tween
	#   - Delay XP orb spawn until effect completes
	# Current: Instant death, no effect

	died.emit()
	queue_free()

# Public interface for damage system integration
func get_max_health() -> float:
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(new_health: float) -> void:
	var old_health = current_health
	current_health = new_health
	_update_health_bar()
	
	# Check for death
	if current_health <= 0.0 and is_alive():
		_die()

func is_alive() -> bool:
	return current_health > 0.0

func _update_health_bar() -> void:
	if health_bar:
		health_bar.update_health(current_health, max_health)


func _on_cheat_toggled(payload: CheatTogglePayload) -> void:
	# Handle AI pause/unpause cheat toggle
	if payload.cheat_name == "ai_paused":
		ai_paused = payload.enabled

func _on_player_died() -> void:
	# Immediately stop AI when player dies to prevent physics errors during cleanup
	_is_dying = true
	Logger.debug("%s: Player died, stopping AI" % get_boss_name(), "bosses")

## Setup PersonalSpaceArea for signal-based boss spacing control
func _setup_personal_space_area() -> void:
	personal_space_area = get_node("PersonalSpaceArea") as Area2D
	if not personal_space_area:
		Logger.debug("%s: No PersonalSpaceArea found - boss spacing disabled" % get_boss_name(), "collision")
		return

	# Connect to area signals for boss detection
	personal_space_area.body_entered.connect(_on_boss_entered_personal_space)
	personal_space_area.body_exited.connect(_on_boss_exited_personal_space)
	Logger.debug("%s: Personal space area configured for boss spacing" % get_boss_name(), "collision")

	# Enable debug visualization if both debug mode and personal space circles are enabled
	if DebugManager and DebugManager.debug_enabled:
		var debug_config = load("res://config/debug.tres") as DebugConfig
		if debug_config and debug_config.show_personal_space_circles:
			_setup_personal_space_debug_visual()

## Handle boss entering personal space - add to nearby list
func _on_boss_entered_personal_space(body: Node2D) -> void:
	var boss = body as CharacterBody2D
	if boss and boss != self and boss.has_method("get_boss_name"):
		nearby_bosses.append(boss)
		Logger.debug("%s: %s entered personal space (%d nearby)" % [get_boss_name(), boss.get_boss_name(), nearby_bosses.size()], "collision")

## Handle boss leaving personal space - remove from nearby list
func _on_boss_exited_personal_space(body: Node2D) -> void:
	var boss = body as CharacterBody2D
	if boss and boss != self and boss.has_method("get_boss_name"):
		nearby_bosses.erase(boss)
		Logger.debug("%s: %s left personal space (%d nearby)" % [get_boss_name(), boss.get_boss_name(), nearby_bosses.size()], "collision")

## Calculate spacing force to maintain personal space from other bosses
func apply_personal_space_forces() -> Vector2:
	if nearby_bosses.is_empty():
		return Vector2.ZERO

	var spacing_force = Vector2.ZERO
	var my_position = global_position
	var personal_space_radius = _get_personal_space_radius()

	for boss in nearby_bosses:
		if not is_instance_valid(boss):
			continue

		var other_position = boss.global_position
		var direction = (my_position - other_position)
		var distance = direction.length()

		if distance > 0.1:  # Avoid division by zero
			# Normalize direction and apply gentle force
			direction = direction.normalized()
			var force_strength = PERSONAL_SPACE_STRENGTH * (1.0 - min(distance / personal_space_radius, 1.0))  # Stronger when closer
			spacing_force += direction * force_strength

	return spacing_force

## DEBUG: Apply only personal space forces (for testing)
func apply_only_personal_space_movement(delta: float) -> void:
	if ai_paused:
		return

	var spacing_force = apply_personal_space_forces()
	if spacing_force.length_squared() > 0.1:
		velocity = spacing_force
		move_and_slide()
		Logger.debug("%s: Pure personal space movement: %.1f px/s" % [get_boss_name(), spacing_force.length()], "collision")

## DEBUG: Print current personal space status
func debug_personal_space_status() -> void:
	Logger.info("%s Personal Space Status:" % get_boss_name(), "collision")
	Logger.info("  - Radius: %.1f px" % _get_personal_space_radius(), "collision")
	Logger.info("  - Nearby bosses: %d" % nearby_bosses.size(), "collision")
	for boss in nearby_bosses:
		if boss and is_instance_valid(boss):
			var distance = global_position.distance_to(boss.global_position)
			Logger.info("    * %s at %.1f px distance" % [boss.get_boss_name(), distance], "collision")

## Get the actual radius from PersonalSpaceArea's CircleShape2D
func _get_personal_space_radius() -> float:
	if not personal_space_area:
		Logger.debug("%s: No personal_space_area - using fallback 32.0" % get_boss_name(), "collision")
		return 32.0  # Default fallback

	var collision_shape = personal_space_area.get_child(0) as CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		Logger.debug("%s: No collision shape or shape - using fallback 32.0" % get_boss_name(), "collision")
		return 32.0  # Default fallback

	var circle_shape = collision_shape.shape as CircleShape2D
	if circle_shape:
		var radius = circle_shape.radius
		Logger.debug("%s: PersonalSpaceArea radius from editor: %.1f" % [get_boss_name(), radius], "collision")
		return radius

	Logger.debug("%s: Shape is not CircleShape2D - using fallback 32.0" % get_boss_name(), "collision")
	return 32.0  # Default fallback

## Setup visual debug circle for PersonalSpaceArea
func _setup_personal_space_debug_visual() -> void:
	if not personal_space_area:
		return

	# Create a visual circle to show the PersonalSpaceArea radius
	var debug_circle = ColorRect.new()
	debug_circle.name = "DebugPersonalSpaceCircle"
	debug_circle.color = Color(1.0, 0.0, 1.0, 0.2)  # Magenta with transparency
	debug_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Get the radius for sizing
	var radius = _get_personal_space_radius()
	var diameter = radius * 2

	# Size and position the visual circle
	debug_circle.size = Vector2(diameter, diameter)
	debug_circle.position = Vector2(-radius, -radius)  # Center on boss

	# Add to the boss so it moves with the boss
	add_child(debug_circle)

	Logger.debug("%s: PersonalSpaceArea debug visual created (radius: %.1f)" % [get_boss_name(), radius], "collision")

## SPRITE SCALING SYSTEM: Dedicated method for proper sprite scaling
func _apply_sprite_scaling(scale_factor: float) -> void:
	if not animated_sprite:
		# Only log if this is unexpected (after deferred call, sprite should exist)
		Logger.warn("Cannot apply sprite scaling: AnimatedSprite2D not found for %s" % get_boss_name(), "bosses")
		return
	
	# Store original position offset to preserve it during scaling
	var original_position = animated_sprite.position
	
	# Apply absolute scaling (not multiplicative)
	animated_sprite.scale = Vector2.ONE * scale_factor
	
	# Preserve original position offset (important for sprites with positioning)
	animated_sprite.position = original_position
	
	# Validate scaling was applied correctly
	_validate_sprite_scaling(scale_factor)

## SCALING VALIDATION: Verify sprite scaling matches expected scale
func _validate_sprite_scaling(expected_scale: float) -> void:
	if not animated_sprite:
		return
	
	var actual_scale = animated_sprite.scale.x  # Assume uniform scaling
	var scale_tolerance = 0.01  # Allow small floating point differences
	
	if abs(actual_scale - expected_scale) > scale_tolerance:
		Logger.warn("Sprite scaling mismatch for %s: expected %.2f, got %.2f" % [get_boss_name(), expected_scale, actual_scale], "bosses")

## DEBUG TOOLS: Get comprehensive scaling information for debugging
func get_scaling_debug_info() -> Dictionary:
	var info = {
		"boss_name": get_boss_name(),
		"sprite_scale": Vector2.ZERO,
		"sprite_position": Vector2.ZERO,
		"collision_scale": Vector2.ZERO,
		"hitbox_scale": Vector2.ZERO,
		"has_sprite": false,
		"has_collision": false,
		"has_hitbox": false,
	}
	
	# Get sprite info
	if animated_sprite:
		info.sprite_scale = animated_sprite.scale
		info.sprite_position = animated_sprite.position
		info.has_sprite = true
	
	# Get collision info
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		info.collision_scale = collision_shape.scale
		info.has_collision = true
	
	# Get hitbox info
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		info.hitbox_scale = hitbox.scale
		info.has_hitbox = true
	
	
	return info

## DEBUG TOOLS: Print scaling debug info to console
func debug_print_scaling_info() -> void:
	var info = get_scaling_debug_info()
	Logger.info("=== SCALING DEBUG: %s ===" % info.boss_name, "debug")
	Logger.info("Sprite: scale=%v position=%v (present: %s)" % [info.sprite_scale, info.sprite_position, info.has_sprite], "debug")
	Logger.info("Collision: scale=%v (present: %s)" % [info.collision_scale, info.has_collision], "debug")
	Logger.info("HitBox: scale=%v (present: %s)" % [info.hitbox_scale, info.has_hitbox], "debug")
	
	# HitBoxShape inherits scaling from parent HitBox Area2D (no separate scaling needed)
	
	Logger.info("=== UNIFIED SCALING DEBUG END ===", "debug")

# REMOVED: Old fragmented health bar scaling fix - now handled by unified component notification system
