extends Node2D

## BaseBoss - Base class for all scene-based bosses (Node2D-based for physics-free movement)
## Provides unified damage integration, performance optimization, and directional animation logic
## HitBox child handles damage detection (Area2D), root node is pure movement/positioning

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
var velocity: Vector2 = Vector2.ZERO  # Area2D doesn't have built-in velocity, declare manually
var attack_damage: float = 40.0
var attack_cooldown: float = 2.0
var last_attack_time: float = 0.0

# AI configuration (override in child classes)
var target_position: Vector2
var attack_range: float = 80.0
var chase_range: float = 5555.0
var ai_paused: bool = false
var _is_dying: bool = false  # Flag to prevent AI updates during death/removal
var _is_spawning: bool = true  # Flag to pause AI during spawn animation

# MANUAL SPACING SYSTEM: EntityTracker-based distance checks (no Area2D collision overhead)
const MANUAL_SPACING_ENABLED: bool = true  # Enable manual distance-based spacing
const MANUAL_SPACING_RADIUS: float = 500.0  # Detection radius for nearby enemies
const MANUAL_SPACING_MIN_DISTANCE: float = 10.0  # Enemies within this distance to PLAYER don't space (allows dense clustering)
const MANUAL_SPACING_RESPECT_MIN_DISTANCE: bool = false  # Whether to skip spacing for enemies close to player (false = always apply spacing)
const MANUAL_SPACING_CHECK_INTERVAL: float = 5.0  # Check every 500ms (not every frame)
const MANUAL_SPACING_STRENGTH: float = 1.0   # Push force when too close
const MANUAL_SPACING_LATERAL_BIAS: float = 0.1 # Radial weight (0.0 = pure sideways, 1.0 = no bias)
var _spacing_check_timer: float = 0.0  # Timer for spacing checks

# KNOCKBACK SYSTEM: Impulse-based separation (VS clone pattern)
var spacing_knockback: Vector2 = Vector2.ZERO  # Current knockback velocity
const KNOCKBACK_DECAY: float = 5.0  # Decay rate in pixels per second (like move_toward resistance)

# PERFORMANCE CACHING: Cache expensive calculations across multiple frames
var _cached_distance_to_player: float = 0.0
var _distance_cache_timer: float = 0.0
const DISTANCE_CACHE_INTERVAL: float = 0.2  # Update distance every 200ms (6 frames @ 30Hz)
var _position_update_counter: int = 0
const POSITION_UPDATE_INTERVAL: int = 2  # Update EntityTracker position every 2 frames

# DIRECTION CACHING: Separate from animation for responsive movement
var _direction_update_counter: int = 0
const DIRECTION_UPDATE_INTERVAL: int = 1  # Update direction every 2 frames (66ms @ 30Hz) - constant for all enemy counts

# PERFORMANCE FLAGS: High enemy count optimizations (500+ enemies)
const SKIP_SPAWN_ANIMATION: bool = false  # Skip 0.5s spawn dissolve effect (cyan edge glow)
const SKIP_WAKEUP_CHECK: bool = false  # Skip wake_up → default animation transition check

# Animation configuration
var current_direction: Vector2 = Vector2.DOWN
var animation_prefix: String = "walk"  # Override in child classes (e.g., "scary_walk")
var _animation_update_counter: int = 0  # Frame counter for throttled animation updates
var _animation_update_offset: int = 0  # Staggered offset per enemy

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

	# NODE2D MIGRATION: Root node is now Node2D for physics-free movement
	# HitBox child (Area2D) handles damage detection on Layer 2
	# No collision properties needed on root node - pure positioning entity

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
	# Logger.debug(get_boss_name() + " registered with BossUpdateManager as " + boss_id, "performance")

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

	# MANUAL SPACING: Stagger spacing check timers to prevent all enemies checking simultaneously
	# Random offset between 0 and check interval spreads checks across multiple frames
	if MANUAL_SPACING_ENABLED:
		var spawn_rng = RNG.stream("spawn")
		_spacing_check_timer = spawn_rng.randf() * MANUAL_SPACING_CHECK_INTERVAL

	# ANIMATION THROTTLING: Stagger animation updates to prevent all enemies updating same frame
	# Offset matches max throttle interval (12 frames @ high enemy count)
	_animation_update_offset = randi() % 12  # Random offset 0-11 for staggered updates

	# Initialize health bar
	_update_health_bar()


func _exit_tree() -> void:
	# BOSS PERFORMANCE V2: Unregister from BossUpdateManager
	var boss_id = "boss_" + str(get_instance_id())
	# Logger.debug("🗑️  %s exiting tree (boss_id: %s)" % [get_boss_name(), boss_id], "performance")
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

## PERFORMANCE OPTIMIZED AI: Minimal AI update with cached values from BossUpdateManager
## Called by BossUpdateManager with cached player_pos and enemy_count
## Implements distance caching, direction caching, and throttled updates
func _update_ai_minimal(dt: float, player_pos: Vector2, enemy_count: int) -> void:
	# Skip AI updates if dying, paused, spawning, or being removed
	if _is_dying or ai_paused or _is_spawning:
		return

	# Skip if boss is being removed or not in tree
	if not is_inside_tree() or is_queued_for_deletion():
		return

	target_position = player_pos  # Use cached player position from BossUpdateManager

	# DISTANCE CACHING: Update distance periodically (not every frame)
	# Reduces distance_to() calls by 83% (every 6 frames vs every frame @ 30Hz)
	_distance_cache_timer += dt
	if _distance_cache_timer >= DISTANCE_CACHE_INTERVAL:
		_distance_cache_timer = 0.0
		_cached_distance_to_player = global_position.distance_to(target_position)

	# Use cached distance for all checks
	if _cached_distance_to_player <= chase_range:
		if _cached_distance_to_player > attack_range:
			# KNOCKBACK DECAY: Reduce knockback velocity over time (VS clone pattern)
			spacing_knockback = spacing_knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)

			# DIRECTION CACHING: Update direction every 2 frames for responsive movement (66ms @ 30Hz)
			# CONSTANT INTERVAL: Does not change with enemy count - movement feel prioritized
			# DECOUPLED from animation updates for independent control
			var direction: Vector2
			_direction_update_counter += 1

			if _direction_update_counter >= DIRECTION_UPDATE_INTERVAL:
				_direction_update_counter = 0
				# Calculate fresh direction (every 2 frames = 66ms @ 30Hz)
				direction = (target_position - global_position).normalized()
				current_direction = direction  # Cache for next frames
			else:
				# Reuse cached direction (reduces normalize() calls by 50%)
				direction = current_direction

			# Move toward player using cached/fresh direction
			velocity = direction * speed

			# ADD KNOCKBACK: Apply knockback to velocity (additive, like VS clone)
			velocity += spacing_knockback

			# ANIMATION THROTTLING: Independent from direction updates for better performance
			# Updates every 6-12 frames (200-400ms) based on enemy count
			_animation_update_counter += 1
			var animation_throttle = 6 if enemy_count < 300 else 12  # Adaptive based on cached enemy_count!

			if (_animation_update_counter + _animation_update_offset) % animation_throttle == 0:
				# Update animation using current direction
				_update_directional_animation(current_direction)

			# MANUAL SPACING: Check nearby enemies periodically (not every frame)
			if MANUAL_SPACING_ENABLED:
				_spacing_check_timer += dt
				if _spacing_check_timer >= MANUAL_SPACING_CHECK_INTERVAL:
					_spacing_check_timer = 0.0
					_apply_manual_spacing()

			# Safety check before physics update
			if not is_inside_tree() or is_queued_for_deletion():
				return

			# THROTTLED POSITION UPDATES: Update EntityTracker every 2 frames (not every frame)
			# Reduces EntityTracker updates by 50% (15/sec vs 30/sec @ 30Hz)
			_position_update_counter += 1
			if _position_update_counter >= POSITION_UPDATE_INTERVAL:
				_position_update_counter = 0
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

	# Update attack cooldown
	last_attack_time += dt

## NODE2D MOVEMENT: Physics-free movement runs EVERY frame (30Hz)
## This ensures smooth movement - AI calculates velocity every 20 frames, physics applies it every frame
func _physics_process(delta: float) -> void:
	# Skip physics if dying, spawning, or no velocity
	if _is_dying or _is_spawning:
		return

	# Apply Node2D movement (physics-free, no collision resolution)
	if velocity.length_squared() > 0.01:
		# Direct position update (Node2D has no built-in physics)
		global_position += velocity * delta

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
			# KNOCKBACK DECAY: Reduce knockback velocity over time (VS clone pattern)
			# Uses move_toward() for smooth organic decay
			spacing_knockback = spacing_knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * dt)

			# Move toward player - simple velocity calculation
			var direction: Vector2 = (target_position - global_position).normalized()
			velocity = direction * speed

			# ADD KNOCKBACK: Apply knockback to velocity (additive, like VS clone)
			# This separates enemies while maintaining chase behavior
			velocity += spacing_knockback

			# MANUAL SPACING: Check nearby enemies periodically (not every frame)
			if MANUAL_SPACING_ENABLED:
				_spacing_check_timer += dt
				if _spacing_check_timer >= MANUAL_SPACING_CHECK_INTERVAL:
					_spacing_check_timer = 0.0
					_apply_manual_spacing()

			# Safety check before physics update
			if not is_inside_tree() or is_queued_for_deletion():
				return

			# STAGGERED AI: Don't call move_and_slide() here - handled in _physics_process()
			# This allows AI to update every 20 frames while physics runs every frame

			# THROTTLED ANIMATION: Adaptive frame-based throttling (6 frames @ low count, 12+ @ high count)
			_animation_update_counter += 1
			var enemy_count = get_tree().get_nodes_in_group("enemies").size()
			var animation_throttle = 6 if enemy_count < 300 else 12  # Adjust based on enemy count

			if (_animation_update_counter + _animation_update_offset) % animation_throttle == 0:
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
	# Logger.debug("💀 %s dying (entity_id: %s)" % [get_boss_name(), entity_id], "performance")

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

## MANUAL SPACING: Use EntityTracker to find nearby enemies and apply avoidance
func _apply_manual_spacing() -> void:
	# Calculate distance to player (used for min distance check and lateral bias gating)
	var distance_to_player = global_position.distance_to(target_position)

	# Skip spacing if we're very close to player (allow dense clustering around player)
	# Can be disabled with MANUAL_SPACING_RESPECT_MIN_DISTANCE = false
	if MANUAL_SPACING_RESPECT_MIN_DISTANCE:
		if distance_to_player < MANUAL_SPACING_MIN_DISTANCE:
			return

	# Query EntityTracker for nearby enemy IDs (spatial partitioning = O(log n))
	var nearby_enemy_ids = EntityTracker.get_entities_in_radius(
		global_position,
		MANUAL_SPACING_RADIUS,
		"boss"  # Filter for bosses (registered with type="boss")
	)

	if nearby_enemy_ids.is_empty():
		return

	# Calculate avoidance force from all nearby enemies
	var avoidance_force = Vector2.ZERO
	for enemy_id in nearby_enemy_ids:
		if enemy_id == entity_id:
			continue  # Skip self

		# Get enemy position from EntityTracker
		var enemy_data = EntityTracker.get_entity(enemy_id)
		if not enemy_data.has("pos"):
			continue

		var enemy_pos = enemy_data["pos"]
		var to_other = enemy_pos - global_position
		var distance = to_other.length()

		# Apply force if within spacing radius
		if distance > 0.1 and distance < MANUAL_SPACING_RADIUS:
			# UNIFORM FORCE: Same strength regardless of distance (no falloff)
			var push_direction = -to_other.normalized()  # Push away from other enemy

			# LATERAL BIAS WITH DISTANCE GATING: Only apply lateral bias to enemies far from player
			# Enemies close to player use pure radial separation to allow dense clustering
			var effective_lateral_bias = MANUAL_SPACING_LATERAL_BIAS

			# Within 2x min distance from player: use radial separation only (no lateral bias)
			# This allows enemies to cluster naturally around the player without sideways pushing
			# Respects MANUAL_SPACING_RESPECT_MIN_DISTANCE flag
			if MANUAL_SPACING_RESPECT_MIN_DISTANCE:
				if distance_to_player < (MANUAL_SPACING_MIN_DISTANCE * 2.0):
					effective_lateral_bias = 1.0  # Pure radial (no sideways bias)

			# LATERAL BIAS: Decompose force into radial (toward/away player) and tangential (sideways)
			# This makes enemies prefer separating sideways, forming lines when approaching player
			var to_player = (target_position - global_position).normalized()

			# Radial component: projection of push onto player direction
			var radial_strength = push_direction.dot(to_player)
			var radial_component = to_player * radial_strength

			# Tangential component: perpendicular to player direction (sideways separation)
			var tangential_component = push_direction - radial_component

			# Apply bias: radial weight × radial + (1 - radial weight) × tangential
			# effective_lateral_bias = 1.0 means pure radial (close to player)
			# effective_lateral_bias = LATERAL_BIAS means configured bias (far from player)
			var biased_direction = (radial_component * effective_lateral_bias +
									tangential_component * (1.0 - effective_lateral_bias)).normalized()

			# IMPULSE-BASED: Accumulate impulse strength (like VS clone collision)
			avoidance_force += biased_direction * MANUAL_SPACING_STRENGTH

	# SET KNOCKBACK: Replace old knockback with new impulse (VS clone pattern)
	# This creates sharp instant separation that decays smoothly
	if avoidance_force.length_squared() > 0.1:
		spacing_knockback = avoidance_force  # Replaces old knockback (not additive)

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
