## EntityPool.gd
## Unified object pooling system for high-frequency, short-lived entities.
##
## Pools:
## - Projectiles (arrows, fireballs, etc.) - 100+ instances for ability spam
## - XP Orbs - 200 instances for mass enemy kills
## - Visual effects - 50+ instances for ability impacts
##
## Architecture:
## - Uses ObjectPool utility for zero-allocation acquire/release
## - Per-type pools with dedicated factory/reset callables
## - Pre-warmed in _ready() to avoid first-spawn lag
## - ONLY for high-frequency entities (NOT chests/bosses/players)
##
## Integration:
## - Listens to EventBus.ability_projectile_requested
## - Spawns pooled entities into current arena scene
## - Entities auto-release themselves when despawned
extends Node

# ============================================================================
# POOLED ENTITY SCENES
# ============================================================================

## Scene references for pooled entity types
const POOLED_ENTITY_SCENES = {
	# Projectiles
	"arrow": preload("res://scenes/abilities/projectiles/Arrow.tscn"),
	# "fireball": preload("res://scenes/abilities/projectiles/Fireball.tscn"),

	# XP Orb (existing scene)
	"xp_orb": preload("res://scenes/arena/XPOrb.tscn"),
}

## Pool sizes for pre-warming
const POOL_SIZES = {
	"arrow": 100,
	"fireball": 50,
	"xp_orb": 200,
}

# ============================================================================
# PROPERTIES
# ============================================================================

## Object pools per entity type
var _pools: Dictionary = {}  # {entity_type: ObjectPool}

## Parent node for pooled entities (set to current arena)
var _entity_parent: Node = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create pools for each entity type
	for entity_type in POOLED_ENTITY_SCENES.keys():
		var pool_size = POOL_SIZES.get(entity_type, 10)
		_setup_pool(entity_type, pool_size)

	# Connect to ability projectile requests
	if EventBus:
		EventBus.ability_projectile_requested.connect(_on_ability_projectile_requested)

	Logger.info("EntityPool initialized with %d pool types" % _pools.size(), "pooling")


## Sets up an object pool for a specific entity type
func _setup_pool(entity_type: String, initial_size: int) -> void:
	if not POOLED_ENTITY_SCENES.has(entity_type):
		Logger.warn("EntityPool: Unknown entity type '%s', skipping pool setup" % entity_type, "pooling")
		return

	var pool := ObjectPool.new()
	var scene_resource = POOLED_ENTITY_SCENES[entity_type]

	# Setup pool with factory and reset callables
	pool.setup(
		initial_size,
		_create_entity_factory(scene_resource),
		_create_entity_reset()
	)

	_pools[entity_type] = pool

	Logger.debug("EntityPool: Created pool for '%s' with %d instances" % [entity_type, initial_size], "pooling")


## Creates a factory callable for instantiating entities
func _create_entity_factory(scene: PackedScene) -> Callable:
	return func() -> Node:
		var entity = scene.instantiate()
		# Don't add to tree yet - will be added when acquired
		return entity


## Creates a reset callable for cleaning up entities before pooling
func _create_entity_reset() -> Callable:
	return func(entity: Node) -> void:
		# Remove from scene tree
		if entity.get_parent():
			entity.get_parent().remove_child(entity)

		# Reset common properties (if entity has them)
		if "position" in entity:
			entity.position = Vector2.ZERO
		if "visible" in entity:
			entity.visible = true


# ============================================================================
# POOL MANAGEMENT
# ============================================================================

## Acquires an entity from the pool and adds it to the scene
func spawn_entity(entity_type: String, parent: Node = null) -> Node:
	if not _pools.has(entity_type):
		Logger.warn("EntityPool: No pool for entity type '%s'" % entity_type, "pooling")
		return null

	var entity = _pools[entity_type].acquire()

	# Add to parent node (arena or specified parent)
	var target_parent = parent if parent else _entity_parent
	if target_parent:
		target_parent.add_child(entity)
	else:
		# Fallback: add to current scene root
		get_tree().current_scene.add_child(entity)

	return entity


## Releases an entity back to the pool
func release_entity(entity_type: String, entity: Node) -> void:
	if not _pools.has(entity_type):
		Logger.warn("EntityPool: Cannot release unknown entity type '%s'" % entity_type, "pooling")
		entity.queue_free()  # Fallback: just delete it
		return

	_pools[entity_type].release(entity)


## Sets the parent node for spawned entities (call from Arena)
func set_entity_parent(parent: Node) -> void:
	_entity_parent = parent
	Logger.debug("EntityPool: Entity parent set to %s" % parent.name, "pooling")


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Spawns a projectile entity from pool when ability requests it
func _on_ability_projectile_requested(projectile_data: Dictionary) -> void:
	var visual_key = projectile_data.get("visual_scene_key", "arrow")

	# Check if we have a pool for this projectile type
	if not _pools.has(visual_key):
		Logger.warn("EntityPool: No pool for projectile type '%s', skipping spawn" % visual_key, "pooling")
		return

	# Spawn projectile entity from pool
	var projectile = spawn_entity(visual_key)

	if not projectile:
		Logger.warn("EntityPool: Failed to spawn projectile '%s'" % visual_key, "pooling")
		return

	# Initialize projectile with data (if it has an init method)
	if projectile.has_method("initialize"):
		projectile.initialize(projectile_data)
	else:
		Logger.warn("EntityPool: Projectile '%s' missing initialize() method" % visual_key, "pooling")


# ============================================================================
# UTILITY / DEBUG
# ============================================================================

## Gets pool statistics for debugging
func get_pool_stats() -> Dictionary:
	var stats := {}
	for entity_type in _pools.keys():
		stats[entity_type] = _pools[entity_type].available_count()
	return stats


## Pre-fills pools if running low (useful for intense combat)
func ensure_pool_capacity(entity_type: String, min_available: int) -> void:
	if _pools.has(entity_type):
		_pools[entity_type].ensure_capacity(min_available)
