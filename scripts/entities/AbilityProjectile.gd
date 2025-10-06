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
## 3. _physics_process() moves projectile and updates lifetime
## 4. Area2D.area_entered detects enemy collisions
## 5. _on_enemy_collision() calls DamageService.apply_damage()
## 6. despawn() returns to EntityPool
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

## Visual scene key for pooling
var visual_scene_key: String = "arrow"

## Has the projectile been initialized?
var _initialized: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================

var area_2d: Area2D = null
var sprite: Sprite2D = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect collision detection (check if Area2D exists)
	if has_node("Area2D"):
		area_2d = get_node("Area2D")
		area_2d.area_entered.connect(_on_area_entered)

	# Get sprite reference
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D")

	# Add to pooled projectiles group
	add_to_group("ability_projectiles")


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	# Move projectile
	position += direction * speed * delta

	# Update lifetime
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		# Use call_deferred to avoid removing CollisionObject during physics callback
		call_deferred("despawn")
		return

	# Homing logic (simple version - adjust direction toward closest enemy)
	if is_homing and homing_strength > 0.0:
		_update_homing_direction(delta)


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
	visual_scene_key = projectile_data.get("visual_scene_key", "arrow")

	# Initialize runtime state
	_remaining_pierce = pierce_count
	_remaining_lifetime = lifetime
	position = projectile_data.get("source_position", Vector2.ZERO)
	_initialized = true

	# Rotate sprite to match direction
	if sprite:
		sprite.rotation = direction.angle()

	Logger.debug("AbilityProjectile initialized: %s at %s" % [ability_id, position], "abilities")


## Resets projectile state for pool recycling.
## Called by EntityPool when projectile is returned to pool.
func reset() -> void:
	_initialized = false
	_remaining_lifetime = 0.0
	_remaining_pierce = 0
	direction = Vector2.RIGHT
	position = Vector2.ZERO
	visible = true

	Logger.debug("AbilityProjectile reset for pool", "abilities")


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
		Logger.debug("Arrow hit enemy with entity_id: %s" % enemy_id, "abilities")
	else:
		# Fallback: use instance ID
		enemy_id = str(enemy_node.get_instance_id())
		Logger.warn("Arrow hit enemy without entity_id, using instance ID: %s" % enemy_id, "abilities")

	# Apply damage via DamageService (direct call - entity pattern)
	_on_enemy_collision(enemy_id)


## Handles enemy collision and damage application
func _on_enemy_collision(enemy_id: String) -> void:
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

		# Apply damage (DamageService signature: target_id, amount, source, tags)
		DamageService.apply_damage(
			enemy_id,          # target ID
			damage,            # damage amount
			source_player_id,  # source identifier
			full_tags          # damage tags
		)

	# Emit projectile hit signal
	projectile_hit.emit(enemy_id, damage)

	# Decrement pierce count
	_remaining_pierce -= 1
	if _remaining_pierce < 0:
		# Use call_deferred to avoid removing CollisionObject during physics callback
		call_deferred("despawn")


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


## Finds the closest enemy to this projectile
func _find_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var closest: Node2D = null
	var closest_dist: float = INF

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

	Logger.debug("AbilityProjectile despawned: %s" % ability_id, "abilities")
