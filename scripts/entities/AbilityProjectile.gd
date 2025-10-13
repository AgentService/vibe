## AbilityProjectile.gd
## Pooled projectile entity for ability-based attacks.
##
## Architecture:
## - Spawned from EntityPool via EventBus.ability_projectile_requested signal
## - Moves in direction at fixed speed
## - Handles collision detection with enemies via Area2D
## - Calls DamageService.apply_damage() directly (entity pattern)
## - Auto-returns to pool when lifetime expires or pierce count reaches 0
##
## Lifecycle:
## 1. EntityPool spawns from pool
## 2. initialize(projectile_data) configures properties
## 3. _on_combat_step() moves projectile at 30Hz (via EventBus.combat_step signal)
## 4. Area2D.area_entered detects enemy collisions
## 5. _on_enemy_collision() calls DamageService.apply_damage()
## 6. despawn() returns to EntityPool
##
## Physics Interpolation:
## - Godot's physics_interpolation=true automatically smooths rendering between 30Hz steps
## - No manual interpolation code needed (position updates in _on_combat_step are smoothed)
##
## OVERKILL PREVENTION CHALLENGE (CRITICAL DESIGN ISSUE): TODO
## When multiple projectiles hit the same target simultaneously (e.g., 5 arrows one-shotting
## a 900 HP boss), all projectiles currently apply damage and despawn, wasting 4 arrows.
##
## Root Cause:
## - DamageService uses zero-allocation queue (_queue_enabled = true by default)
## - Damage is queued and processed on next 30Hz tick, not immediately
## - Arrow1 hits → damage queued (boss still alive in registry)
## - Arrow2 hits → checks is_alive → TRUE (damage not processed yet) → queues again
## - Arrow3/4/5 same problem → all queue damage
## - Next 30Hz tick → all damages process, massive overkill
##
## Attempted Solutions:
## 1. ✓ Check DamageService.is_entity_alive() before applying damage (current implementation)
##    → FAILS with damage queue enabled (entity stays alive until queue processes)
##
## Potential Solutions (not yet implemented):
## A. Disable damage queue globally
##    - Pro: Overkill prevention works immediately
##    - Con: Loses zero-allocation performance benefit
##    - Con: May be needed for crazy multi-ability scenarios
##
## B. Bypass damage queue for projectiles (call _process_damage_immediate directly)
##    - Pro: Overkill prevention works for projectiles
##    - Pro: Keeps queue for other damage sources
##    - Con: Bypasses private API (fragile)
##    - Con: Inconsistent damage timing (some immediate, some queued)
##
## C. Stagger projectile spawn timing (spread over 2-3 frames)
##    - Pro: Natural target distribution
##    - Pro: Keeps damage queue
##    - Con: Changes gameplay feel (arrows don't fire "simultaneously")
##    - Con: Doesn't solve the root problem, just reduces frequency
##
## D. Smart target selection (each arrow picks different target if multiple available)
##    - Pro: Optimal damage distribution
##    - Pro: Keeps damage queue
##    - Con: Complex logic (nearest-unassigned-target algorithm)
##    - Con: Requires tracking "assigned targets" during volley
##
## E. Check damage queue for pending lethal damage before applying
##    - Pro: Works with queue enabled
##    - Con: Couples to queue internals
##    - Con: Complex (need to sum queued damage per target)
##
## F. Accept overkill as intended behavior
##    - Pro: Simple, no changes needed
##    - Con: Feels bad with high projectile counts
##    - Con: Players can't optimize around it
##
## Current Status:
## - ✓ Option B implemented and WORKING (bypass damage queue via _process_damage_immediate)
## - Arrows 2-5 in volley correctly skip already-dead targets
## - TODO: Decide if this is permanent solution or switch to Option C/D/E
## - TODO: Consider queue implications for future "crazy abilities"
##
## Usage:
##   # Entity automatically initialized by EntityPool after spawn
##   # No manual setup needed
extends Node2D

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when projectile hits an enemy
signal projectile_hit(enemy_id: String, damage: float)

## Emitted when projectile despawns
signal projectile_despawned()

# ============================================================================
# PROPERTIES
# ============================================================================

## Unique ability ID (for tracking/stats)
var ability_id: String = ""

## Firing direction (normalized)
var direction: Vector2 = Vector2.RIGHT

## Movement speed (pixels/second)
var speed: float = 400.0

## Damage dealt on hit (overwritten by initialize())
var damage: float = 15.0

## Damage type (physical, fire, cold, etc.)
var damage_type: String = "physical"

## Element type
var element: String = ""

## Damage tags for DamageService
var damage_tags: Array[String] = []

## Pierce count - how many enemies can be hit before despawn
var pierce_count: int = 0

## Remaining pierce count (decremented on hit)
var _remaining_pierce: int = 0

## Lifetime in seconds
var lifetime: float = 2.0

## Remaining lifetime
var _remaining_lifetime: float = 0.0

## Is this a homing projectile?
var is_homing: bool = false

## Homing strength (0.0-1.0)
var homing_strength: float = 0.5

## Source player ID (for damage attribution)
var source_player_id: String = "player"

## Knockback distance applied on hit (pixels)
var knockback_distance: float = 100.0

## Impact AoE radius (pixels) - 0.0 = no AoE
var impact_aoe_radius: float = 0.0

## Impact AoE damage multiplier - scales damage for AoE targets
var impact_aoe_damage_mult: float = 1.0

## Impact effect scene to spawn on collision
var impact_effect: PackedScene = null

## Visual scene key for pooling
var visual_scene_key: String = "arrow"

## TEMP: Bypass damage queue for overkill prevention testing
## Set to true to call _process_damage_immediate() directly (bypasses queue)
## TODO: Remove after choosing permanent solution from header documentation
const BYPASS_DAMAGE_QUEUE_FOR_TESTING: bool = true

## Has the projectile been initialized?
var _initialized: bool = false

## Cached dummy node for ghost targeting (reused to avoid memory leaks)
var _ghost_target_node: Node2D = null

# ============================================================================
# NODE REFERENCES
# ============================================================================

var area_2d: Area2D = null
var sprite: Node2D = null  # Can be Sprite2D or AnimatedSprite2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect collision detection (check if Area2D exists)
	if has_node("Area2D"):
		area_2d = get_node("Area2D")
		area_2d.area_entered.connect(_on_area_entered)

	# Get sprite reference (supports both Sprite2D and AnimatedSprite2D)
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D")
	elif has_node("AnimatedSprite2D"):
		sprite = get_node("AnimatedSprite2D")

	# Add to pooled projectiles group
	add_to_group("ability_projectiles")

	# Connect to fixed-step physics (Godot handles interpolation automatically)
	EventBus.combat_step.connect(_on_combat_step)


## Fixed-step physics update (called at 30Hz via EventBus.combat_step)
## Godot's physics_interpolation=true automatically smooths rendering between physics steps
func _on_combat_step(payload) -> void:
	if not _initialized:
		return

	# Move projectile at fixed timestep (payload.dt is the fixed delta time, e.g., 0.033s for 30Hz)
	position += direction * speed * payload.dt

	# Check for ghost swarm collisions (manual distance check since ghosts are MultiMesh, not Area2D)
	_check_ghost_collisions()

	# Update lifetime
	_remaining_lifetime -= payload.dt
	if _remaining_lifetime <= 0.0:
		# Use call_deferred to avoid issues during physics callback
		call_deferred("despawn")
		return

	# Homing logic (simple version - adjust direction toward closest enemy)
	if is_homing and homing_strength > 0.0:
		_update_homing_direction(payload.dt)


# ============================================================================
# INITIALIZATION (Called by EntityPool)
# ============================================================================

## Initializes projectile from pooled state.
## Called by EntityPool after spawning from pool.
func initialize(projectile_data: Dictionary) -> void:
	# Extract data from payload
	ability_id = projectile_data.get("ability_id", "")
	direction = projectile_data.get("direction", Vector2.RIGHT).normalized()
	speed = projectile_data.get("projectile_speed", 400.0)
	damage = projectile_data.get("damage", 15.0)
	damage_type = projectile_data.get("damage_type", "physical")
	element = projectile_data.get("element", "")
	damage_tags = projectile_data.get("tags", [])
	pierce_count = projectile_data.get("pierce_count", 0)
	lifetime = projectile_data.get("projectile_lifetime", 2.0)
	is_homing = projectile_data.get("is_homing", true)
	homing_strength = projectile_data.get("homing_strength", 0.5)
	knockback_distance = projectile_data.get("knockback_distance", 0.0)
	impact_aoe_radius = projectile_data.get("impact_aoe_radius", 0.0)
	impact_aoe_damage_mult = projectile_data.get("impact_aoe_damage_mult", 1.0)
	impact_effect = projectile_data.get("impact_effect", null)
	visual_scene_key = projectile_data.get("visual_scene_key", "arrow")

	# Initialize runtime state
	_remaining_pierce = pierce_count
	_remaining_lifetime = lifetime

	# Set spawn position
	position = projectile_data.get("source_position", Vector2.ZERO)

	_initialized = true

	# Rotate sprite to match direction
	if sprite:
		sprite.rotation = direction.angle()


## Resets projectile state for pool recycling.
## Called by EntityPool when projectile is returned to pool.
func reset() -> void:
	_initialized = false
	_remaining_lifetime = 0.0
	_remaining_pierce = 0
	direction = Vector2.RIGHT
	position = Vector2.ZERO
	visible = true

	# Clean up ghost target node when returning to pool
	if _ghost_target_node:
		_ghost_target_node.queue_free()
		_ghost_target_node = null


# ============================================================================
# COLLISION DETECTION
# ============================================================================

## Handles Area2D collision with enemies
func _on_area_entered(area: Area2D) -> void:
	if not _initialized:
		return

	# Check if this is an enemy (enemies should be in "enemies" group or have specific collision layer)
	var enemy_node = area.get_parent()
	if not enemy_node or not enemy_node.is_in_group("enemies"):
		return

	# Get enemy ID
	var enemy_id: String = ""
	if "entity_id" in enemy_node:
		enemy_id = enemy_node.entity_id
	else:
		# Fallback: use instance ID
		enemy_id = str(enemy_node.get_instance_id())
		Logger.warn("Arrow hit enemy without entity_id, using instance ID: %s" % enemy_id, "abilities")

	# Apply damage via DamageService (direct call - entity pattern)
	_on_enemy_collision(enemy_id)


## Check for collisions with ghost swarms (distance-based since ghosts are MultiMesh)
func _check_ghost_collisions() -> void:
	# Find Arena node (projectiles are spawned under Arena, so we can search upward)
	# Arena is the scene that has ghost_swarm_spawner property
	var arena = _find_arena_node()
	if not arena:
		return

	var ghost_spawner = arena.ghost_swarm_spawner
	if not ghost_spawner or not ghost_spawner.is_active():
		return

	# Collision radius (increased to 48px to hit stacked ghosts on player)
	var collision_radius = 48.0

	# Check for hits using area damage (efficient for MultiMesh ghosts)
	var hit_indices = ghost_spawner.check_hits_in_area(global_position, collision_radius, damage)

	if hit_indices.size() > 0:
		# Hit at least one ghost - consume pierce
		_remaining_pierce -= hit_indices.size()
		if _remaining_pierce < 0:
			call_deferred("despawn")

## Handles enemy collision and damage application
func _on_enemy_collision(enemy_id: String) -> void:
	# Check if target is still alive (prevents overkill waste)
	# With BYPASS_DAMAGE_QUEUE_FOR_TESTING enabled, _process_damage_immediate() updates
	# _entity_alive[index] synchronously, so arrows 2-5 in a volley correctly skip dead targets
	var is_alive: bool = false
	if DamageService:
		is_alive = DamageService.is_entity_alive(enemy_id)
	else:
		Logger.warn("DamageService not available for alive check!", "abilities")
		is_alive = true  # Fallback: assume alive if service unavailable

	if not is_alive:
		# Target already dead - continue flying without consuming pierce
		# This prevents overkill waste (e.g., 5 arrows one-shotting 900 HP boss)
		return

	# Call DamageService directly (entities use direct calls, not EventBus)
	if DamageService:
		# Build damage tags array including element and damage type
		var full_tags: Array = []
		if damage_type:
			full_tags.append(damage_type)
		if element:
			full_tags.append(element)
		for tag in damage_tags:
			full_tags.append(tag)

		# Use CURRENT player position for knockback direction (enemies pushed away from player)
		# PlayerState.get_position() returns 30Hz-updated cached position
		var current_player_pos: Vector2 = PlayerState.get_position() if PlayerState else global_position

		# TEMP: Queue bypass for overkill prevention testing
		if BYPASS_DAMAGE_QUEUE_FOR_TESTING:
			# Call private API directly (bypasses queue, updates alive state immediately)
			# This makes the alive check (line 271) work correctly for subsequent arrows
			DamageService._process_damage_immediate(
				enemy_id,
				damage,
				source_player_id,
				full_tags,
				knockback_distance,
				current_player_pos
			)
		else:
			# Normal path: damage queued for 30Hz tick
			# Overkill prevention WILL NOT WORK with this path
			# DamageService.apply_damage(
			# 	enemy_id,
			# 	damage,
			# 	source_player_id,
			# 	full_tags,
			# 	knockback_distance,
			# 	current_player_pos
			# )
			pass  # Currently disabled - using bypass path only
	else:
		Logger.warn("  DamageService not available!", "abilities")

	# Apply AoE damage if configured (fireball explosion effect)
	if impact_aoe_radius > 0.0:
		_apply_impact_aoe(global_position, enemy_id)

	# Spawn impact effect if configured (fireball explosion visual)
	if impact_effect:
		var effect_instance = impact_effect.instantiate()
		effect_instance.global_position = global_position
		get_tree().current_scene.add_child(effect_instance)

	# Emit projectile hit signal
	projectile_hit.emit(enemy_id, damage)

	# Decrement pierce count (only if we actually hit a living target)
	_remaining_pierce -= 1
	if _remaining_pierce < 0:
		# Use call_deferred to avoid removing CollisionObject during physics callback
		call_deferred("despawn")


## Applies AoE damage to all enemies in radius (fireball explosion effect)
## Excludes the direct hit target to prevent double-damage
func _apply_impact_aoe(center: Vector2, direct_hit_enemy_id: String) -> void:
	# Query EntityTracker for enemies and bosses in AoE radius
	var nearby_enemy_ids: Array[String] = EntityTracker.get_entities_in_radius(
		center, impact_aoe_radius, "enemy"
	)
	var nearby_boss_ids: Array[String] = EntityTracker.get_entities_in_radius(
		center, impact_aoe_radius, "boss"
	)

	# Calculate AoE damage (scaled by multiplier)
	var aoe_damage: float = damage * impact_aoe_damage_mult

	# Build damage tags (same as direct hit)
	var full_tags: Array = []
	if damage_type:
		full_tags.append(damage_type)
	if element:
		full_tags.append(element)
	for tag in damage_tags:
		full_tags.append(tag)

	var current_player_pos: Vector2 = PlayerState.get_position() if PlayerState else center
	var aoe_hit_count: int = 0

	# Apply damage to nearby enemies (excluding direct hit target)
	for enemy_id in nearby_enemy_ids:
		if enemy_id == direct_hit_enemy_id:
			continue  # Skip direct hit target to prevent double-damage

		if DamageService.is_entity_alive(enemy_id):
			if BYPASS_DAMAGE_QUEUE_FOR_TESTING:
				DamageService._process_damage_immediate(
					enemy_id,
					aoe_damage,
					source_player_id,
					full_tags,
					knockback_distance * 0.5,  # Reduced knockback for AoE
					current_player_pos
				)
			else:
				# Normal path (queued damage)
				DamageService.apply_damage(
					enemy_id,
					aoe_damage,
					source_player_id,
					full_tags,
					knockback_distance * 0.5,
					current_player_pos
				)
			aoe_hit_count += 1

	# Apply damage to nearby bosses (excluding direct hit target)
	for boss_id in nearby_boss_ids:
		if boss_id == direct_hit_enemy_id:
			continue  # Skip direct hit target

		if DamageService.is_entity_alive(boss_id):
			if BYPASS_DAMAGE_QUEUE_FOR_TESTING:
				DamageService._process_damage_immediate(
					boss_id,
					aoe_damage,
					source_player_id,
					full_tags,
					knockback_distance * 0.5,  # Reduced knockback for AoE
					current_player_pos
				)
			else:
				# Normal path (queued damage)
				DamageService.apply_damage(
					boss_id,
					aoe_damage,
					source_player_id,
					full_tags,
					knockback_distance * 0.5,
					current_player_pos
				)
			aoe_hit_count += 1

	if aoe_hit_count > 0 and Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Impact AoE: hit %d additional targets (%.1f damage each)" % [aoe_hit_count, aoe_damage], "abilities")


# ============================================================================
# HOMING LOGIC
# ============================================================================

## Updates direction for homing projectiles
func _update_homing_direction(delta: float) -> void:
	# Find closest enemy (simple implementation)
	var closest_enemy = _find_closest_enemy()
	if not closest_enemy:
		return

	# Calculate direction to enemy
	var to_enemy: Vector2 = (closest_enemy.global_position - global_position).normalized()

	# Lerp current direction toward enemy (homing strength controls turn rate)
	direction = direction.lerp(to_enemy, homing_strength * delta * 5.0).normalized()

	# Rotate sprite to match new direction
	if sprite:
		sprite.rotation = direction.angle()


## Finds the Arena node by searching upward from this projectile's parent chain
func _find_arena_node() -> Node:
	# Strategy 1: Search upward from this node's parents (projectiles spawned under Arena)
	var current_node = get_parent()
	var depth = 0
	while current_node:
		if "ghost_swarm_spawner" in current_node:
			return current_node
		current_node = current_node.get_parent()
		depth += 1
		if depth > 10:  # Prevent infinite loops
			break

	# Strategy 2: Try common paths (fallback)
	var arena_paths = [
		"Main/Arena",
		"/root/Main/Arena",
		"Arena"
	]

	for path in arena_paths:
		var node = get_tree().root.get_node_or_null(path)
		if node and "ghost_swarm_spawner" in node:
			return node

	return null

## Finds the closest enemy to this projectile (includes scene-based enemies AND ghost swarm)
func _find_closest_enemy() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF

	# Check scene-based enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_node := enemy as Node2D
		if not enemy_node:
			continue

		var dist := global_position.distance_squared_to(enemy_node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy_node

	# Check ghost swarm (MultiMesh ghosts don't have Node2D, use closest position)
	var arena = _find_arena_node()
	if arena and arena.ghost_swarm_spawner and arena.ghost_swarm_spawner.is_active():
		var closest_ghost_pos = arena.ghost_swarm_spawner.get_closest_ghost_position(global_position)
		if closest_ghost_pos != Vector2.ZERO:
			var ghost_dist = global_position.distance_squared_to(closest_ghost_pos)
			if ghost_dist < closest_dist:
				# Use cached dummy node for ghost targeting (prevents memory leak)
				if not _ghost_target_node:
					_ghost_target_node = Node2D.new()
					_ghost_target_node.name = "GhostTarget"
				_ghost_target_node.global_position = closest_ghost_pos
				closest = _ghost_target_node
				closest_dist = ghost_dist

	return closest


# ============================================================================
# DESPAWN
# ============================================================================

## Despawns projectile and returns to pool
func despawn() -> void:
	if not _initialized:
		return

	_initialized = false
	projectile_despawned.emit()

	# Return to EntityPool
	if EntityPool:
		EntityPool.release_entity(visual_scene_key, self)
	else:
		# Fallback: just hide and queue free
		queue_free()
