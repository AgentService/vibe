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

## Lightning effect scene (Pack 5 C, row 6 - electric strike animation)
const LIGHTNING_SCENE := preload("res://scenes/effects/LightningImpact.tscn")

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

	# Connect to combat_step for freeze duration updates
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)

	Logger.debug("EffectSpawner initialized", "effects")


## Combat step handler for updating freeze effects (30Hz fixed timestep)
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	var delta_time: float = payload.dt
	_update_freeze_effects(delta_time)


## Updates arena reference when entering/leaving ARENA state
func _on_state_changed(prev_state: StateManager.State, new_state: StateManager.State, context: Dictionary) -> void:
	if new_state == StateManager.State.ARENA:
		_find_arena_reference()
	else:
		_arena = null
		# Clear active freezes when leaving arena
		_active_freezes.clear()


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


## Sets arena reference directly (called by Arena._ready())
func set_arena(arena: Node2D) -> void:
	_arena = arena
	Logger.debug("EffectSpawner: Arena reference set directly", "effects")


## Returns the effects container node (same parent as enemies for proper z-ordering)
func _get_effects_container() -> Node2D:
	if not _arena:
		return null

	# Try to find the same container where enemies are spawned
	# This ensures effects and enemies share the same parent for z_index to work
	if _arena.has_node("YSort_Objects"):
		return _arena.get_node("YSort_Objects")
	elif _arena.has_node("ArenaRoot"):
		return _arena.get_node("ArenaRoot")
	else:
		# Fallback to arena itself
		return _arena


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

	# Spawn visual effect (scene has base scale 10, multiply by 0.4 for item procs)
	var explosion := EXPLOSION_SCENE.instantiate()

	# Add to same container as enemies for proper z-ordering
	var effects_container := _get_effects_container()
	effects_container.add_child(explosion)
	explosion.global_position = position

	# Randomly flip horizontally for visual variety
	var flip := 1.0 if RNG.stream("item_procs").randf() < 0.5 else -1.0
	explosion.scale = Vector2(4.0 * flip, 4.0)  # 10 * 0.4 = 4.0 (smaller for item procs)

	# Apply damage to enemies in radius (search for "boss" type - all enemies use BaseBoss)
	var nearby_enemies := EntityTracker.get_entities_in_radius(position, radius, "boss")

	Logger.debug("EffectSpawner: Explosion at %s - found %d enemies in radius %.0f" % [
		position, nearby_enemies.size(), radius
	], "effects")

	var hits := 0
	for enemy_id in nearby_enemies:
		# Check if enemy is alive before applying damage
		if not DamageService.is_entity_alive(enemy_id):
			Logger.debug("EffectSpawner: Skipping dead enemy %s" % enemy_id, "effects")
			continue

		# Apply damage via DamageService with item source (for recursion prevention)
		DamageService._process_damage_immediate(
			enemy_id,
			damage,
			"item_explosion",  # Source tag for recursion prevention
			["fire", "aoe"],   # Damage types
			0.0,               # No knockback
			position           # Source position
		)
		hits += 1

	Logger.info("EffectSpawner: Explosion dealt damage to %d/%d enemies (damage=%.1f)" % [
		hits, nearby_enemies.size(), damage
	], "effects")


# ============================================================================
# LIGHTNING EFFECT (LightningImpact.tscn)
# ============================================================================

## Spawns lightning effect at position with optional chaining.
##
## Parameters:
##   initial_position: Exact spawn position for first bolt (payload.impact_position)
##   damage: Base damage per lightning strike
##   chain_count: Number of additional targets to chain to (0 = single target)
##   chain_range: Maximum distance to chain to next target
func spawn_lightning(initial_position: Vector2, damage: float, chain_count: int, chain_range: float) -> void:
	if not _arena:
		Logger.warn("EffectSpawner: Cannot spawn lightning, no arena reference", "effects")
		return

	# Track hit enemies to prevent double-hitting
	var hit_enemies: Array[String] = []
	var current_pos := initial_position
	var remaining_chains := chain_count + 1  # +1 for initial strike
	var is_first_bolt := true

	while remaining_chains > 0:
		# Find nearest enemy within chain range (excluding already hit)
		# Returns {id: String, pos: Vector2} to capture position at search time
		var nearest_enemy_data := _find_nearest_enemy(current_pos, chain_range, hit_enemies)
		var nearest_enemy: String = nearest_enemy_data.get("id", "")

		if nearest_enemy.is_empty():
			break  # No more valid targets

		# Spawn lightning bolt
		var lightning := LIGHTNING_SCENE.instantiate()

		# Add to same container as enemies for proper z-ordering
		var effects_container := _get_effects_container()
		effects_container.add_child(lightning)

		# First bolt: Spawn at exact impact_position (where damage landed)
		# Chain bolts: Spawn at captured enemy position from search
		if is_first_bolt:
			lightning.global_position = initial_position
			is_first_bolt = false
		else:
			lightning.global_position = nearest_enemy_data.get("pos", Vector2.ZERO)

		# Setup enemy tracking for frame-accurate positioning during animation
		if lightning.has_method("track_enemy"):
			lightning.track_enemy(nearest_enemy, _arena)

		# Randomly flip horizontally for visual variety
		var flip := 1.0 if RNG.stream("item_procs").randf() < 0.5 else -1.0
		lightning.scale = Vector2(3.0 * flip, 3.0)  # 10 * 0.3 = 3.0 (smaller for item procs)

		# Apply damage to this enemy
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
		current_pos = nearest_enemy_data.get("pos", Vector2.ZERO)
		remaining_chains -= 1

	Logger.debug("EffectSpawner: Lightning spawned at %s (damage=%.1f, chains=%d, hits=%d)" % [
		initial_position, damage, chain_count, hit_enemies.size()
	], "effects")


## Finds nearest enemy within range, excluding already hit enemies.
## Returns Dictionary with {id: String, pos: Vector2} or empty dict if none found.
## Position is captured at search time to prevent movement lag.
func _find_nearest_enemy(position: Vector2, max_range: float, exclude_ids: Array[String]) -> Dictionary:
	var nearby_enemies := EntityTracker.get_entities_in_radius(position, max_range, "boss")

	var nearest_id := ""
	var nearest_pos := Vector2.ZERO
	var nearest_dist_sq := INF

	for enemy_id in nearby_enemies:
		# Skip if already hit
		if enemy_id in exclude_ids:
			continue

		# Skip if dead (overkill prevention)
		if not DamageService.is_entity_alive(enemy_id):
			continue

		# Find closest and capture position at search time
		var enemy_pos: Vector2 = EntityTracker.get_entity(enemy_id).get("pos", Vector2.ZERO)
		var dist_sq := position.distance_squared_to(enemy_pos)

		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_id = enemy_id
			nearest_pos = enemy_pos

	return {"id": nearest_id, "pos": nearest_pos}


# ============================================================================
# FREEZE EFFECT (Simple MVP - Direct Speed Modification)
# ============================================================================

## Active freeze effects tracked per enemy
## Structure: {enemy_id: {remaining_duration: float, slow_mult: float, original_speed: float, original_modulate: Color}}
var _active_freezes: Dictionary = {}

## Applies freeze/slow effect to target enemy.
##
## Parameters:
##   target_id: Entity ID of enemy to freeze
##   duration: Freeze duration in seconds
##   slow_mult: Movement speed multiplier (0.0 = full freeze, 0.5 = 50% speed)
##
## MVP Implementation: Directly modifies enemy speed, restores after duration
func spawn_freeze(target_id: String, duration: float, slow_mult: float) -> void:
	if not _arena:
		Logger.warn("EffectSpawner: Cannot spawn freeze, no arena reference", "effects")
		return

	# Find enemy node in scene tree
	var enemy_node := _find_enemy_node(target_id)
	if not enemy_node:
		Logger.debug("EffectSpawner: Cannot freeze, enemy node not found: %s" % target_id, "effects")
		return

	# Verify enemy has speed property (duck typing)
	if not "speed" in enemy_node:
		Logger.warn("EffectSpawner: Cannot freeze, enemy has no 'speed' property: %s" % target_id, "effects")
		return

	# Store original values if this is a new freeze (don't overwrite if already frozen)
	var original_speed: float = enemy_node.speed
	var original_modulate: Color = enemy_node.modulate
	if _active_freezes.has(target_id):
		# Already frozen - use stored original values
		original_speed = _active_freezes[target_id].original_speed
		original_modulate = _active_freezes[target_id].original_modulate

	# Apply slow multiplier to enemy speed
	enemy_node.speed = original_speed * slow_mult

	# Apply cyan/blue tint for frozen visual feedback
	enemy_node.modulate = Color(0.5, 0.7, 1.0, 1.0)  # Icy blue tint

	# Track freeze effect
	_active_freezes[target_id] = {
		"remaining_duration": duration,
		"slow_mult": slow_mult,
		"original_speed": original_speed,
		"original_modulate": original_modulate
	}

	Logger.debug("EffectSpawner: Applied freeze to %s (duration=%.1f, slow=%.2f, speed: %.0f → %.0f)" % [
		target_id, duration, slow_mult, original_speed, enemy_node.speed
	], "effects")


## Updates freeze durations and removes expired effects (called by _on_combat_step)
func _update_freeze_effects(delta: float) -> void:
	var expired_freezes: Array[String] = []

	for enemy_id in _active_freezes.keys():
		var freeze_data: Dictionary = _active_freezes[enemy_id]

		# Decrement duration
		freeze_data.remaining_duration -= delta

		# Check if expired
		if freeze_data.remaining_duration <= 0.0:
			expired_freezes.append(enemy_id)

	# Remove expired freezes and restore enemy speeds
	for enemy_id in expired_freezes:
		_remove_freeze_effect(enemy_id)


## Removes freeze effect from enemy and restores original speed and color
func _remove_freeze_effect(enemy_id: String) -> void:
	if not _active_freezes.has(enemy_id):
		return

	var freeze_data: Dictionary = _active_freezes[enemy_id]
	var original_speed: float = freeze_data.original_speed
	var original_modulate: Color = freeze_data.original_modulate

	# Find enemy and restore speed + color
	var enemy_node := _find_enemy_node(enemy_id)
	if enemy_node:
		if "speed" in enemy_node:
			enemy_node.speed = original_speed
		enemy_node.modulate = original_modulate
		Logger.debug("EffectSpawner: Removed freeze from %s (speed restored: %.0f)" % [
			enemy_id, original_speed
		], "effects")

	# Remove from tracking
	_active_freezes.erase(enemy_id)


## Finds enemy node in scene tree by entity_id
func _find_enemy_node(entity_id: String) -> Node:
	if not _arena:
		return null

	# Search for enemy in "enemies" group
	var enemies := _arena.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if "entity_id" in enemy and enemy.entity_id == entity_id:
			return enemy

	return null
