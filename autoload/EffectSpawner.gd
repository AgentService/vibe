extends Node

## EffectSpawner - Global effect spawning system for item procs
##
## Responsibilities:
##   - Spawn visual effects at world positions (lightning, explosion, freeze)
##   - Apply area damage to nearby enemies via DamageService
##   - Handle chaining for lightning effects
##   - Apply status effects (freeze/slow) to targets
##
## Usage:
##   EffectSpawner.spawn_explosion(position, damage, radius)
##   EffectSpawner.spawn_lightning(position, damage, chain_count, chain_range)
##   EffectSpawner.spawn_freeze(target_id, duration, slow_mult)

# ============================================================================
# EFFECT SCENES
# ============================================================================

## Explosion effect scene (reuses FireballImpact)
const EXPLOSION_SCENE := preload("res://scenes/effects/FireballImpact.tscn")

## Lightning effect scene (TODO: Create proper lightning effect scene)
## For now, uses explosion effect as placeholder
const LIGHTNING_SCENE := EXPLOSION_SCENE

## Freeze effect scene (TODO: Create proper freeze effect scene)
## For now, no visual effect spawned
const FREEZE_SCENE = null


# ============================================================================
# ARENA REFERENCE
# ============================================================================

## Reference to current arena for spawning effects
var _arena: Node2D = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to state changes to track arena
	StateManager.state_changed.connect(_on_state_changed)
	Logger.debug("EffectSpawner initialized", "effects")


## Updates arena reference when entering/leaving ARENA state
func _on_state_changed(prev_state: StateManager.State, new_state: StateManager.State, context: Dictionary) -> void:
	if new_state == StateManager.State.ARENA:
		_find_arena_reference()
	else:
		_arena = null


## Finds and caches arena reference from scene tree
func _find_arena_reference() -> void:
	# Wait one frame for arena to be fully initialized
	await get_tree().process_frame

	# Find arena in scene tree
	var root = get_tree().current_scene
	if root and root.has_node("Arena"):
		_arena = root.get_node("Arena")
		Logger.debug("EffectSpawner: Arena reference found", "effects")
	else:
		Logger.warn("EffectSpawner: Arena not found in scene tree", "effects")


# ============================================================================
# EXPLOSION EFFECT (Using FireballImpact.tscn)
# ============================================================================

## Spawns explosion effect at position and damages nearby enemies.
##
## Parameters:
##   position: World position to spawn explosion
##   damage: Base damage to apply to enemies in radius
##   radius: Explosion radius in pixels
func spawn_explosion(position: Vector2, damage: float, radius: float) -> void:
	if not _arena:
		Logger.warn("EffectSpawner: Cannot spawn explosion, no arena reference", "effects")
		return

	# Spawn visual effect
	var explosion := EXPLOSION_SCENE.instantiate()
	_arena.add_child(explosion)
	explosion.global_position = position

	# Apply damage to enemies in radius
	var nearby_enemies := EntityTracker.get_entities_in_radius(position, radius, "enemy")

	for enemy_id in nearby_enemies:
		# Apply damage via DamageService with item source (for recursion prevention)
		DamageService._process_damage_immediate(
			enemy_id,
			damage,
			"item_explosion",  # Source tag for recursion prevention
			["fire", "aoe"],   # Damage types
			0.0,               # No knockback
			position           # Source position
		)

	Logger.debug("EffectSpawner: Explosion spawned at %s (damage=%.1f, radius=%.0f, hits=%d)" % [
		position, damage, radius, nearby_enemies.size()
	], "effects")


# ============================================================================
# LIGHTNING EFFECT (Placeholder - TODO: Create proper lightning effect)
# ============================================================================

## Spawns lightning effect at position with optional chaining.
##
## Parameters:
##   position: Initial strike position (enemy that triggered proc)
##   damage: Base damage per lightning strike
##   chain_count: Number of additional targets to chain to (0 = single target)
##   chain_range: Maximum distance to chain to next target
func spawn_lightning(position: Vector2, damage: float, chain_count: int, chain_range: float) -> void:
	if not _arena:
		Logger.warn("EffectSpawner: Cannot spawn lightning, no arena reference", "effects")
		return

	# Track hit enemies to prevent double-hitting
	var hit_enemies: Array[String] = []
	var current_pos := position
	var remaining_chains := chain_count + 1  # +1 for initial strike

	while remaining_chains > 0:
		# Find nearest enemy within chain range (excluding already hit)
		var nearest_enemy := _find_nearest_enemy(current_pos, chain_range, hit_enemies)

		if not nearest_enemy:
			break  # No more valid targets

		# Get enemy position for next chain
		var enemy_pos: Vector2 = EntityTracker.get_entity(nearest_enemy).get("pos", Vector2.ZERO)

		# Spawn visual effect (TODO: Replace with proper lightning arc effect)
		var lightning := LIGHTNING_SCENE.instantiate()
		_arena.add_child(lightning)
		lightning.global_position = enemy_pos

		# Apply damage via DamageService with item source
		DamageService._process_damage_immediate(
			nearest_enemy,
			damage,
			"item_lightning",  # Source tag for recursion prevention
			["lightning"],     # Damage types
			0.0,               # No knockback
			current_pos        # Source position (for VFX direction)
		)

		# Update state for next chain
		hit_enemies.append(nearest_enemy)
		current_pos = enemy_pos
		remaining_chains -= 1

	Logger.debug("EffectSpawner: Lightning spawned at %s (damage=%.1f, chains=%d, hits=%d)" % [
		position, damage, chain_count, hit_enemies.size()
	], "effects")


## Finds nearest enemy within range, excluding already hit enemies.
## Returns enemy_id or empty string if none found.
func _find_nearest_enemy(position: Vector2, max_range: float, exclude_ids: Array[String]) -> String:
	var nearby_enemies := EntityTracker.get_entities_in_radius(position, max_range, "enemy")

	var nearest_id := ""
	var nearest_dist_sq := INF

	for enemy_id in nearby_enemies:
		# Skip if already hit
		if enemy_id in exclude_ids:
			continue

		# Skip if dead (overkill prevention)
		if not DamageService.is_entity_alive(enemy_id):
			continue

		# Find closest
		var enemy_pos: Vector2 = EntityTracker.get_entity(enemy_id).get("pos", Vector2.ZERO)
		var dist_sq := position.distance_squared_to(enemy_pos)

		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_id = enemy_id

	return nearest_id


# ============================================================================
# FREEZE EFFECT (Placeholder - TODO: Implement freeze debuff system)
# ============================================================================

## Applies freeze/slow effect to target enemy.
##
## Parameters:
##   target_id: Entity ID of enemy to freeze
##   duration: Freeze duration in seconds
##   slow_mult: Movement speed multiplier (0.0 = full freeze, 0.5 = 50% speed)
##
## TODO: Implement proper debuff system for status effects
func spawn_freeze(target_id: String, duration: float, slow_mult: float) -> void:
	# TODO: Implement debuff system
	# For now, just log the freeze attempt
	Logger.debug("EffectSpawner: Freeze effect requested (target=%s, duration=%.1f, slow=%.2f) - NOT IMPLEMENTED" % [
		target_id, duration, slow_mult
	], "effects")

	# Future implementation:
	# 1. Create DebuffSystem autoload
	# 2. DebuffSystem.apply_debuff(target_id, "freeze", duration, {"slow_mult": slow_mult})
	# 3. DebuffSystem handles movement speed reduction in combat_step
	# 4. Spawn freeze visual effect at enemy position
