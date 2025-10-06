## ProjectileAbility.gd
## Projectile-based ability subclass with auto-fire support.
##
## This class extends BaseAbility to handle projectile-based attacks.
## Projectiles are spawned via EventBus signals (signal-based decoupling).
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
extends BaseAbility
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
@export_range(0.0, 1.0) var homing_strength: float = 0.5

## Projectile chains to nearby enemies after hitting
@export var chains_to_enemies: int = 0

## Chain radius (pixels) - only used if chains_to_enemies > 0
@export var chain_radius: float = 150.0

## Pierce count - how many enemies projectile can pass through
@export var pierce_count: int = 0


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	# NOTE: Don't call super._init() - Resource doesn't have a callable _init()

	# Ensure PROJECTILE tag is always present
	if not has_tag(AbilityTags.PROJECTILE):
		tags.append(AbilityTags.PROJECTILE)

	# Add COOLDOWN tag by default for progression scaling
	if not has_tag(AbilityTags.COOLDOWN):
		tags.append(AbilityTags.COOLDOWN)

	# Add DAMAGE tag by default
	if not has_tag(AbilityTags.DAMAGE):
		tags.append(AbilityTags.DAMAGE)


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

	# Determine firing direction based on fire_mode
	var firing_direction: Vector2 = _determine_firing_direction(player, context)

	# Create projectile data payload
	var projectile_data: Dictionary = _create_projectile_data(player, firing_direction, context)

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

	# Find closest enemy
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if not enemy_node:
			continue

		var distance: float = player_pos.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node

	# Return direction to closest enemy
	if closest_enemy:
		return (closest_enemy.global_position - player_pos).normalized()
	else:
		return Vector2.RIGHT


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
	var data: Dictionary = {
		"ability_id": ability_id,
		"source_position": player.global_position,
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
		"pierce_count": pierce_count
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
