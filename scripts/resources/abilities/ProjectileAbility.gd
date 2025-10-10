## ProjectileAbility.gd
## Projectile-based ability subclass with auto-fire support.
##
## This class extends DamageAbility to handle projectile-based attacks.
## Projectiles are spawned via EventBus signals (signal-based decoupling).
##
## Class Hierarchy:
## - BaseAbility (universal: id, name, icon, tags, level, visuals)
##   - DamageAbility (damage, cooldown, scaling, breakpoints)
##     - ProjectileAbility (projectile-specific behavior) ← YOU ARE HERE
##
## Auto-Fire Design:
## - activate() is called automatically when cooldown is ready
## - No player input required - fires based on target_mode
## - Target modes: CLOSEST_ENEMY (default), RANDOM
##
## Signal-Based Architecture:
## - Emits EventBus.ability_projectile_requested with payload
## - ProjectileSpawnSystem (future phase) listens and spawns actual entities
## - Decouples ability logic from projectile pooling/rendering
##
## Simplified Fire Patterns (Phase 1):
## - Target closest enemy
## - Random direction
## - Future phases can add spread, circle, targeted patterns
##
## Usage:
##   var fireball: ProjectileAbility = load("res://data/content/abilities/fireball.tres")
##   fireball.activate(player, {"enemies": enemy_array})  # Auto-fires at closest
extends DamageAbility
class_name ProjectileAbility

# ============================================================================
# ENUMS
# ============================================================================

## Fire mode for projectile targeting (simplified for Phase 1)
enum FireMode {
	CLOSEST_ENEMY,  ## Targets the closest enemy to player
	RANDOM          ## Fires in random direction
}

# ============================================================================
# PROJECTILE PROPERTIES
# ============================================================================

@export_group("Projectile Targeting")

## Fire mode for this projectile ability
@export var fire_mode: FireMode = FireMode.CLOSEST_ENEMY

@export_group("Projectile Behavior")

## Is this a homing projectile?
@export var is_homing: bool = false

## Homing strength (0.0 = no homing, 1.0 = perfect tracking)
@export_range(0.0, 5.0) var homing_strength: float = 0.5

## Projectile chains to nearby enemies after hitting
@export var chains_to_enemies: int = 0

## Chain radius (pixels) - only used if chains_to_enemies > 0
@export var chain_radius: float = 150.0

## Pierce count - how many enemies projectile can pass through
@export var pierce_count: int = 0

## Knockback distance applied on hit (pixels)
@export var knockback_distance: float = 0.0

## Spread angle in degrees for multi-projectile attacks (total cone angle)
@export_range(0.0, 180.0) var spread_angle: float = 40.0

## Projectile movement speed in pixels/second
@export var projectile_speed: float = 800.0

## Projectile lifetime in seconds before auto-destroying
@export var projectile_lifetime: float = 3.0


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	super._init()  # Initialize DamageAbility (DAMAGE/COOLDOWN tags, computed stats)

	# Projectiles typically have longer range than melee
	# Only override if using default value (800px from DamageAbility)
	if base_range == 800.0:
		base_range = 900.0  # Projectile default
		final_range = 900.0

	# Ensure PROJECTILE tag is always present
	if not has_tag(AbilityTags.PROJECTILE):
		tags.append(AbilityTags.PROJECTILE)


# ============================================================================
# ACTIVATION (Auto-Fire)
# ============================================================================

## Activates the projectile ability (auto-fire).
## Determines firing direction based on fire_mode and emits signal.
##
## Parameters:
##   player: Node2D - The player node (for position/direction)
##   context: Dictionary - Must contain "enemies": Array for CLOSEST_ENEMY mode
##
## Context Keys:
##   - enemies: Array - Array of enemy nodes for targeting (required for CLOSEST_ENEMY)
##   - direction: Vector2 - Override direction (optional)
##
## Emits:
##   EventBus.ability_projectile_requested(projectile_data: Dictionary)
func activate(player: Node2D, context: Dictionary) -> void:
	if not player:
		push_warning("ProjectileAbility.activate() called without player node")
		return

	# Determine base firing direction based on fire_mode
	var base_direction: Vector2 = _determine_firing_direction(player, context)

	# Spawn multiple projectiles with spread (multi-shot)
	var projectiles_to_spawn := maxi(1, projectile_count)  # At least 1 projectile

	for i in range(projectiles_to_spawn):
		# Calculate spread angle for this projectile
		var spread_direction := _calculate_spread_direction(base_direction, i, projectiles_to_spawn)

		# Create projectile data payload with spread direction
		var projectile_data: Dictionary = _create_projectile_data(player, spread_direction, context)

		# Emit signal for projectile spawning system to handle
		EventBus.ability_projectile_requested.emit(projectile_data)

	# Also emit generic ability_activated signal
	EventBus.ability_activated.emit(ability_id)


# ============================================================================
# TARGETING LOGIC
# ============================================================================

## Determines the firing direction based on fire_mode and context.
## Returns a normalized Vector2 direction vector.
func _determine_firing_direction(player: Node2D, context: Dictionary) -> Vector2:
	# Check for override direction in context
	if context.has("direction") and context["direction"] is Vector2:
		return context["direction"].normalized()

	match fire_mode:
		FireMode.CLOSEST_ENEMY:
			return _get_direction_to_closest_enemy(player, context)
		FireMode.RANDOM:
			return _get_random_direction()
		_:
			# Fallback to right direction
			return Vector2.RIGHT


## Gets direction to the closest enemy from context.
## Returns Vector2.RIGHT if no enemies available.
## Supports both scene-based enemies (Node2D) and ghost wrappers (Dictionary).
func _get_direction_to_closest_enemy(player: Node2D, context: Dictionary) -> Vector2:
	if not context.has("enemies"):
		push_warning("ProjectileAbility: CLOSEST_ENEMY mode requires 'enemies' in context")
		return Vector2.RIGHT

	var enemies: Array = context["enemies"]
	if enemies.is_empty():
		return Vector2.RIGHT

	var player_pos: Vector2 = player.global_position
	var closest_enemy = null
	var closest_distance: float = INF
	var closest_enemy_position: Vector2 = Vector2.ZERO

	# Find closest enemy (supports both Node2D and Dictionary types)
	for enemy in enemies:
		# Skip null or invalid entries
		if not enemy:
			continue

		# Handle scene-based enemies (Node2D)
		if enemy is Node2D:
			var enemy_node: Node2D = enemy as Node2D
			if not is_instance_valid(enemy_node):
				continue

			var distance: float = player_pos.distance_squared_to(enemy_node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy_node
				closest_enemy_position = enemy_node.global_position

		# Handle ghost swarm wrappers (Dictionary with "global_position" key)
		elif enemy is Dictionary and enemy.has("global_position"):
			var ghost_pos: Vector2 = enemy["global_position"]
			var distance: float = player_pos.distance_squared_to(ghost_pos)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy  # Store Dictionary wrapper
				closest_enemy_position = ghost_pos

	# Return direction to closest enemy
	if closest_enemy:
		# For scene-based enemies, try to get hitbox center
		if closest_enemy is Node2D:
			var target_position := _get_enemy_hitbox_center(closest_enemy)
			return (target_position - player_pos).normalized()
		# For ghost wrappers, use stored position
		else:
			return (closest_enemy_position - player_pos).normalized()
	else:
		return Vector2.RIGHT


## Calculates spread direction for multi-shot projectiles.
## Distributes projectiles evenly across a spread cone.
##
## Parameters:
##   base_direction: Vector2 - The main firing direction
##   projectile_index: int - Which projectile this is (0, 1, 2, ...)
##   total_projectiles: int - Total number of projectiles to spawn
##
## Returns:
##   Vector2 - Direction with spread angle applied
func _calculate_spread_direction(base_direction: Vector2, projectile_index: int, total_projectiles: int) -> Vector2:
	# No spread needed for single projectile
	if total_projectiles == 1:
		return base_direction

	# Total spread angle in radians (use configured spread_angle property)
	var total_spread_angle: float = deg_to_rad(spread_angle)

	# Calculate angle offset for this projectile
	# Center the spread around the base direction
	var spread_per_projectile := total_spread_angle / float(total_projectiles - 1)
	var angle_offset := -total_spread_angle / 2.0 + (projectile_index * spread_per_projectile)

	# Get base angle and apply offset
	var base_angle := base_direction.angle()
	var final_angle := base_angle + angle_offset

	# Return rotated direction vectoras
	return Vector2(cos(final_angle), sin(final_angle))


## Gets the center position of an enemy's hitbox.
## Returns enemy global_position if HitBox not found.
func _get_enemy_hitbox_center(enemy: Node2D) -> Vector2:
	# Try to find HitBox Area2D child node
	var hitbox := enemy.get_node_or_null("HitBox")
	if hitbox and hitbox is Area2D:
		return hitbox.global_position

	# Fallback: use enemy position
	return enemy.global_position


## Gets a random direction vector.
func _get_random_direction() -> Vector2:
	var angle: float = randf() * TAU  # Random angle 0 to 2π
	return Vector2(cos(angle), sin(angle))


# ============================================================================
# PROJECTILE DATA CREATION
# ============================================================================

## Creates the projectile data payload for signal emission.
## Returns a Dictionary with all necessary information for spawning.
##
## IMPORTANT: Uses final_damage (computed from base_damage + tome modifiers)
## NOT base_damage (immutable baseline). This ensures tomes affect damage output.
##
## Payload Structure:
##   ability_id: String - Unique identifier
##   source_position: Vector2 - Spawn position (player position)
##   direction: Vector2 - Normalized firing direction
##   damage: float - FINAL damage (base_damage × tome modifiers)
##   element: String - Inherent element (fire, cold, etc.)
##   tags: Array[String] - Ability tags
##   projectile_count: int - Number of projectiles to spawn
##   projectile_speed: float - Speed in pixels/second
##   projectile_lifetime: float - Lifetime in seconds
##   is_homing: bool - Homing behavior
##   homing_strength: float - Homing tracking strength
##   chains_to_enemies: int - Chain count
##   chain_radius: float - Chain radius
##   pierce_count: int - Pierce count
##   visual_scene: PackedScene - Projectile visual (if set)
##   impact_effect: PackedScene - Impact effect (if set)
func _create_projectile_data(player: Node2D, direction: Vector2, context: Dictionary) -> Dictionary:
	# Spawn projectile at character center + offset up
	const SPAWN_Y_OFFSET: float = -24.0  # Pixels up from character origin
	var spawn_position := player.global_position + Vector2(0, SPAWN_Y_OFFSET)

	var data: Dictionary = {
		"ability_id": ability_id,
		"source_position": spawn_position,
		"direction": direction,
		"damage": final_damage,  # Use FINAL damage (includes tome modifiers), NOT base_damage
		"element": inherent_element,
		"damage_type": damage_type,
		"tags": tags.duplicate(),  # Copy tags array
		"projectile_count": projectile_count,
		"projectile_speed": projectile_speed,
		"projectile_lifetime": projectile_lifetime,
		"is_homing": is_homing,
		"homing_strength": homing_strength,
		"chains_to_enemies": chains_to_enemies,
		"chain_radius": chain_radius,
		"pierce_count": pierce_count,
		"knockback_distance": knockback_distance
	}

	# Add visual references if available
	if visual_scene:
		data["visual_scene"] = visual_scene

	if impact_effect:
		data["impact_effect"] = impact_effect

	return data


# ============================================================================
# VALIDATION
# ============================================================================

## Validates ProjectileAbility configuration.
## Extends BaseAbility validation with projectile-specific checks.
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()

	# Ensure PROJECTILE tag exists (should be added in _init)
	if not has_tag(AbilityTags.PROJECTILE):
		errors.append("ProjectileAbility must have PROJECTILE tag")

	# Validate homing settings
	if is_homing and homing_strength <= 0:
		errors.append("is_homing requires homing_strength > 0")

	# Validate chaining settings
	if chains_to_enemies > 0 and chain_radius <= 0:
		errors.append("chains_to_enemies requires chain_radius > 0")

	return errors
