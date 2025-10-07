extends Node

## Unified spawn director managing all enemy spawning: waves, packs, bosses, events.
## Spawns enemies using zone-based proximity logic with run-based scaling.
## Updates on fixed combat step (30 Hz) for deterministic behavior.
## Uses Enemy V2 system for weighted enemy spawning and dynamic pack composition.

class_name SpawnDirector

# Import ArenaSystem for dependency injection
const ArenaSystem = preload("res://scripts/systems/arena/ArenaSystem.gd")
const EventSpawnManager = preload("res://scripts/systems/spawn/EventSpawnManager.gd")

# ZERO-ALLOC: Import ring buffer utilities for entity update queue
const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd")
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

# PHASE 4 OPTIMIZATION: Use Dictionary-based entities to eliminate object allocation
# Keep Array[EnemyEntity] type for compatibility, but use pre-allocated EnemyEntity instances
# that wrap reusable Dictionary data structures
var enemies: Array[EnemyEntity] = []
var _enemy_data_pool: Array[Dictionary] = []  # Actual data storage (reusable)

# PHASE 4 OPTIMIZATION: Pre-generated entity ID strings to eliminate string concatenation
# Target: 5-15MB reduction from eliminating "enemy_" + str(i) allocations
var _pre_generated_entity_ids: Array[String] = []  # Pre-generated "enemy_0", "enemy_1", etc.
var max_enemies: int
var spawn_timer: float = 0.0
var spawn_interval: float
var arena_center: Vector2
var spawn_radius: float
var enemy_speed_min: float
var enemy_speed_max: float
var spawn_count_min: int
var spawn_count_max: int
var arena_bounds: float
var target_distance: float

# Arena system for spawn configuration
var arena_system

# Note: Arena scene reference removed - using dynamic lookup for simplicity and correctness
var _is_arena_scene_cached: bool = false

# Boss hit feedback system for boss registration
var boss_hit_feedback: BossHitFeedback

# Preloaded boss scenes for performance
var _preloaded_boss_scenes: Dictionary = {}


# PHASE 7 OPTIMIZATION: Bit-field alive/dead tracking (5-10MB reduction)
# Replace individual alive checking with efficient bit operations
var _alive_bitfield: PackedByteArray = PackedByteArray()  # Bit-field for alive status (1 bit per enemy)
var _alive_count: int = 0                                # Cached count of alive enemies
var _alive_enemies_cache: Array[EnemyEntity] = []        # Cached list (rebuilt when dirty)
var _cache_dirty: bool = true
var _last_cache_frame: int = -1

# Free enemy slot tracking for faster spawning
var _last_free_index: int = 0

# PHASE 3: Pool utilization warning throttling to reduce allocation spam
var _last_warned_threshold: int = -1
var _pool_exhaustion_warning_timer: float = 0.0
const POOL_EXHAUSTION_WARNING_COOLDOWN: float = 2.0  # Only warn every 2 seconds when pool is full

# AI pause functionality for debug interface
var ai_paused: bool = false

# UNIFIED SPAWNING: Wave spawning state
var current_run_time: float = 0.0
var current_wave_level: int = 1

# EVENT SYSTEM: Delegated to EventSpawnManager
var event_spawn_manager: EventSpawnManager
var mastery_system

# BREACH EVENT HANDLER: Separate handler for breach events
var breach_handler: BreachEventHandler


# ZERO-ALLOC: Entity update queue for batch processing (eliminates Dictionary allocations)
var _entity_update_queue: RingBufferUtil
var _update_payload_pool: ObjectPoolUtil

signal enemies_updated(alive_enemies: Array[EnemyEntity])

func _ready() -> void:
	add_to_group("wave_directors")  # For DamageRegistry sync access
	
	
	# Safety check: Only allow WaveDirector to run in Arena scenes
	_is_arena_scene_cached = _is_in_arena_scene()
	if not _is_arena_scene_cached:
		Logger.warn("WaveDirector: Not in Arena scene, disabling spawning", "waves")
		set_process(false)
		set_physics_process(false)
		return

	# Arena scene lookup is now dynamic - no caching needed
	
	
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	
	# DAMAGE V3: Listen for unified damage sync events
	EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
	
	# Connect to cheat toggle events for AI pause functionality
	EventBus.cheat_toggled.connect(_on_cheat_toggled)
	
	# Connect to player death for immediate spawning stop
	EventBus.player_died.connect(_on_player_died)

	# Scene transition signals no longer needed for cache management

	_initialize_pool()
	_initialize_entity_update_queue()
	_preload_boss_scenes()
	_initialize_event_system()
	_initialize_breach_handler()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)
	

func set_arena_system(injected_arena_system) -> void:
	arena_system = injected_arena_system
	Logger.info("ArenaSystem injected into WaveDirector", "waves")

func _load_balance_values() -> void:
	max_enemies = BalanceDB.get_waves_value("max_enemies")
	spawn_interval = BalanceDB.get_waves_value("spawn_interval")
	arena_center = BalanceDB.get_waves_value("arena_center")
	# spawn_radius now comes from ArenaSystem, set via dependency injection
	enemy_speed_min = BalanceDB.get_waves_value("enemy_speed_min")
	enemy_speed_max = BalanceDB.get_waves_value("enemy_speed_max")
	spawn_count_min = BalanceDB.get_waves_value("spawn_count_min")
	spawn_count_max = BalanceDB.get_waves_value("spawn_count_max")
	arena_bounds = BalanceDB.get_waves_value("arena_bounds")
	target_distance = BalanceDB.get_waves_value("target_distance")

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if EventBus.damage_entity_sync.is_connected(_on_damage_entity_sync):
		EventBus.damage_entity_sync.disconnect(_on_damage_entity_sync)
	if EventBus.cheat_toggled.is_connected(_on_cheat_toggled):
		EventBus.cheat_toggled.disconnect(_on_cheat_toggled)
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	Logger.debug("WaveDirector: Cleaned up signal connections", "systems")

func _get_arena_root() -> Node2D:
	# Find ArenaRoot - check current scene and BaseArena children
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# First check if current scene has ArenaRoot directly
	if current_scene.has_node("ArenaRoot"):
		return current_scene.get_node("ArenaRoot")
	
	# Check if any BaseArena child has ArenaRoot (for dynamic loading)
	for child in current_scene.get_children():
		if child is BaseArena and child.has_node("ArenaRoot"):
			return child.get_node("ArenaRoot")
	
	Logger.warn("ArenaRoot not found in current scene or BaseArena children, falling back to current_scene", "waves")
	return current_scene

func _get_ysort_container_or_arena_root() -> Node2D:
	"""Get YSort_Objects container for Y-sorting, or fall back to ArenaRoot"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		Logger.debug("No current scene found, using ArenaRoot fallback", "waves")
		return _get_arena_root()

	# First check if current scene has YSort_Objects directly
	var ysort_container = current_scene.get_node_or_null("YSort_Objects")
	if ysort_container:
		return ysort_container

	# Check if any BaseArena child has YSort_Objects (for dynamic loading)
	for child in current_scene.get_children():
		if child is BaseArena:
			var child_ysort = child.get_node_or_null("YSort_Objects")
			if child_ysort:
				return child_ysort

	# Deep search for YSort_Objects in common nested locations
	ysort_container = _find_ysort_objects_recursive(current_scene)
	if ysort_container:
		return ysort_container

	# Fallback to ArenaRoot if no YSort_Objects container found
	Logger.debug("YSort_Objects not found in scene %s, using ArenaRoot fallback" % current_scene.name, "waves")
	return _get_arena_root()

func _find_ysort_objects_recursive(node: Node) -> Node2D:
	"""Recursively search for YSort_Objects container in the scene tree."""
	# Check if this node is YSort_Objects
	if node.name == "YSort_Objects" and node is Node2D:
		return node as Node2D

	# Search in children
	for child in node.get_children():
		var result = _find_ysort_objects_recursive(child)
		if result:
			return result

	return null

func _on_balance_reloaded() -> void:
	_load_balance_values()
	_initialize_pool()
	_initialize_entity_update_queue()  # Reinitialize with new max_enemies value
	Logger.info("Reloaded wave balance values", "waves")

func _preload_boss_scenes() -> void:
	# Load boss scenes dynamically from EnemyFactory templates
	const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Ensure templates are loaded
	if not EnemyFactoryScript._templates_loaded:
		EnemyFactoryScript.load_all_templates()
	
	# Load all boss templates with scene paths
	for template_id in EnemyFactoryScript._templates:
		var template = EnemyFactoryScript._templates[template_id]
		if template.render_tier == "boss" and not template.boss_scene_path.is_empty():
			var scene_resource = load(template.boss_scene_path)
			if scene_resource:
				_preloaded_boss_scenes[template_id] = scene_resource
				Logger.debug("Preloaded boss scene: %s -> %s" % [template_id, template.boss_scene_path], "waves")
			else:
				Logger.warn("Failed to load boss scene: %s" % template.boss_scene_path, "waves")
	
	Logger.info("Boss scenes preloaded for performance: %d bosses" % _preloaded_boss_scenes.size(), "waves")

func _initialize_event_system() -> void:
	"""Initialize the event mastery system and event spawn manager"""
	mastery_system = EventMasterySystem.mastery_system_instance

	# Create and initialize event spawn manager
	event_spawn_manager = EventSpawnManager.new()
	add_child(event_spawn_manager)
	event_spawn_manager.initialize(self, mastery_system)

	Logger.info("Event system initialized with EventSpawnManager", "events")

func _initialize_breach_handler() -> void:
	"""Initialize the breach event handler"""
	breach_handler = BreachEventHandler.new()
	add_child(breach_handler)
	breach_handler.initialize(self, mastery_system)

	# Connect breach signals for logging/debugging
	breach_handler.breach_activated.connect(_on_breach_activated)
	breach_handler.breach_completed.connect(_on_breach_completed)

	Logger.info("Breach event handler initialized", "events")

func _update_breach_system(dt: float) -> void:
	"""Update the breach event system if enabled"""
	if event_spawn_manager and event_spawn_manager.event_system_enabled and breach_handler:
		breach_handler.update(dt)

func _on_breach_activated(breach_event: EventInstance) -> void:
	"""Handle breach activation logging"""
	Logger.debug("SpawnDirector: Breach activated at %s" % breach_event.center_position, "events")

func _on_breach_completed(breach_event: EventInstance, performance_data: Dictionary) -> void:
	"""Handle breach completion logging"""
	Logger.debug("SpawnDirector: Breach completed with %d enemies spawned" % performance_data.get("enemies_spawned", 0), "events")



func _get_data_driven_spawn_position_bypass_validation() -> Vector2:
	"""Get spawn position using Area2D zones.
	Breach validation system removed."""

	# Get arena scene and map config
	var arena_scene = _get_arena_scene()
	if not arena_scene:
		Logger.error("No arena scene found for spawn position", "spawn")
		return Vector2.ZERO

	var map_config = null
	if "map_config" in arena_scene:
		map_config = arena_scene.map_config as MapConfig

	if not map_config:
		Logger.error("No map_config available for spawn position", "spawn")
		return Vector2.ZERO

	# Use area triggers method without validation (only supported method)
	return _get_area_triggers_spawn_position_bypass_validation(arena_scene, map_config)

func _get_area_triggers_spawn_position_bypass_validation(arena_scene: Node, map_config: MapConfig) -> Vector2:
	"""AREA_TRIGGERS spawn position WITHOUT breach validation to prevent recursion."""

	if not "_spawn_zone_areas" in arena_scene:
		Logger.error("AREA_TRIGGERS (bypass): No _spawn_zone_areas available in arena scene", "spawn")
		return Vector2.ZERO

	var spawn_zones = arena_scene._spawn_zone_areas
	if spawn_zones.is_empty():
		Logger.error("AREA_TRIGGERS (bypass): No spawn zones available", "spawn")
		return Vector2.ZERO

	# Get player position for proximity filtering
	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		# No player position, select random zone
		var selected_zone = spawn_zones[RNG.randi("spawn") % spawn_zones.size()]
		return _generate_position_in_area2d_zone(selected_zone)

	# Apply proximity filtering
	var auto_spawn_range = map_config.auto_spawn_range
	var auto_spawn_min_distance = map_config.auto_spawn_min_distance if "auto_spawn_min_distance" in map_config else 0.0

	var zones_in_range = []
	for zone in spawn_zones:
		var zone_pos = zone.global_position
		var distance_to_center = player_pos.distance_to(zone_pos)
		var zone_radius = _get_zone_radius(zone)

		# Smart proximity: if inside zone, always activate; if outside, check edge distance
		var is_inside_zone = distance_to_center <= zone_radius
		var distance_to_edge = max(0.0, distance_to_center - zone_radius)

		if is_inside_zone or (distance_to_edge >= auto_spawn_min_distance and distance_to_edge <= auto_spawn_range):
			zones_in_range.append(zone)

	if zones_in_range.is_empty():
		Logger.debug("AREA_TRIGGERS (bypass): No zones in proximity range, no spawning", "spawn")
		return Vector2.ZERO

	# Select random zone from those in range
	var selected_zone = zones_in_range[RNG.randi("spawn") % zones_in_range.size()]
	var spawn_position = _generate_position_in_area2d_zone(selected_zone)

	# NO BREACH VALIDATION - This is the key difference to prevent recursion
	var center_distance = player_pos.distance_to(selected_zone.global_position)
	var zone_radius = _get_zone_radius(selected_zone)
	var edge_distance = max(0.0, center_distance - zone_radius)
	var inside_zone = center_distance <= zone_radius
	Logger.debug("AREA_TRIGGERS (bypass): Using spawn zone at %s (edge distance: %.0fpx, inside zone: %s, no validation)" % [spawn_position, edge_distance, inside_zone], "arena")
	return spawn_position


# PHASE 4 OPTIMIZATION: Get pre-generated entity ID (eliminates string concatenation)
func get_enemy_entity_id(enemy_index: int) -> String:
	if enemy_index >= 0 and enemy_index < _pre_generated_entity_ids.size():
		return _pre_generated_entity_ids[enemy_index]
	else:
		# Fallback for out-of-bounds (shouldn't happen in normal operation)
		return "enemy_" + str(enemy_index)

# PHASE 7 OPTIMIZATION: Bit-field helper functions for alive/dead tracking
func _set_enemy_alive(index: int, alive: bool) -> void:
	if index < 0 or index >= max_enemies:
		return
		
	var byte_index = index / 8
	var bit_index = index % 8
	var current_byte = _alive_bitfield[byte_index]
	
	if alive:
		# Set bit (mark as alive)
		var new_byte = current_byte | (1 << bit_index)
		if current_byte != new_byte:
			_alive_bitfield[byte_index] = new_byte
			_alive_count += 1
			_cache_dirty = true
	else:
		# Clear bit (mark as dead)
		var new_byte = current_byte & ~(1 << bit_index)
		if current_byte != new_byte:
			_alive_bitfield[byte_index] = new_byte
			_alive_count -= 1
			_cache_dirty = true

func _is_enemy_alive_bitfield(index: int) -> bool:
	if index < 0 or index >= max_enemies:
		return false
		
	var byte_index = index / 8
	var bit_index = index % 8
	var current_byte = _alive_bitfield[byte_index]
	return (current_byte & (1 << bit_index)) != 0

func _get_alive_count_fast() -> int:
	return _alive_count

func _initialize_pool() -> void:
	# PHASE 4 OPTIMIZATION: Create Dictionary-based data pool instead of EnemyEntity objects
	# This eliminates 500 object allocations (30-50MB memory reduction target)
	
	# Pre-generate all entity ID strings to eliminate string concatenation allocations
	# Target: 5-15MB reduction from eliminating "enemy_" + str(i) calls
	_pre_generated_entity_ids.resize(max_enemies)
	for i in range(max_enemies):
		_pre_generated_entity_ids[i] = "enemy_" + str(i)
	
	# Create reusable Dictionary data structures
	_enemy_data_pool.resize(max_enemies)
	enemies.resize(max_enemies)
	
	# PHASE 7 OPTIMIZATION: Initialize bit-field for alive/dead tracking
	# Use 1 byte per 8 enemies (more efficient than individual booleans)
	var bytes_needed = (max_enemies + 7) / 8  # Round up to nearest byte
	_alive_bitfield.resize(bytes_needed)
	_alive_bitfield.fill(0)  # All enemies start as dead
	_alive_count = 0
	
	for i in range(max_enemies):
		# Create Dictionary data structure (reusable, no object allocation)
		var data_dict = {
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"hp": 0.0,
			"max_hp": 0.0,
			"alive": false,
			"type_id": "",
			"speed": 60.0,
			"size": Vector2(24, 24),
			"direction": Vector2.ZERO
		}
		_enemy_data_pool[i] = data_dict
		
		# Create ONE EnemyEntity wrapper that references the Dictionary data
		# This reduces object allocations from 500 to minimal wrapper objects
		var entity = EnemyEntity.new()
		entity._data_ref = data_dict  # Link to reusable data
		entity.index = i  # PERFORMANCE: Set direct index for O(1) lookups
		enemies[i] = entity

## ZERO-ALLOC: Initialize entity update queue and payload pool
func _initialize_entity_update_queue() -> void:
	# Initialize ring buffer for entity updates (capacity = max possible updates per frame)
	_entity_update_queue = RingBufferUtil.new()
	_entity_update_queue.setup(max_enemies)  # Worst case: all enemies need updates
	
	# Initialize payload pool for entity update payloads
	_update_payload_pool = ObjectPoolUtil.new()
	_update_payload_pool.setup(
		max_enemies / 2,  # Reasonable estimate: ~50% of enemies in update range per frame
		PayloadResetUtil.create_entity_update_payload,
		PayloadResetUtil.clear_entity_update_payload
	)
	
	Logger.info("Zero-alloc entity update queue initialized (capacity: %d, pool: %d)" % [
		_entity_update_queue.capacity(), _update_payload_pool.available_count()
	], "waves")

func _on_combat_step(payload) -> void:
	# Safety check: Don't process if not in Arena scene or if player is dead
	# Use dynamic check instead of cached value to handle scene transitions properly
	if not _is_in_arena_scene():
		return

	# TIMING FIX: Don't spawn until PlayerState has a valid player reference
	# Prevents spawning during arena initialization before player is ready
	if not PlayerState.has_player_reference():
		return

	# Zone management now handled by EventSpawnManager.update()
	_handle_spawning(payload.dt)
	_update_enemies(payload.dt)
	_update_breach_system(payload.dt)
	# DECISION: No longer emit enemies_updated signal for MultiMesh - scene enemies self-manage


## DAMAGE V3: Handle unified damage sync events for pooled enemies
func _on_damage_entity_sync(payload: Dictionary) -> void:
	var entity_id: String = payload.get("entity_id", "")
	var entity_type: String = payload.get("entity_type", "")
	var new_hp: float = payload.get("new_hp", 0.0)
	var is_death: bool = payload.get("is_death", false)
	
	# Only handle enemy entities
	if entity_type != "enemy":
		return
		
	# Extract enemy index from entity_id
	var enemy_index_str = entity_id.replace("enemy_", "")
	var enemy_index = enemy_index_str.to_int()
	
	# Validate enemy index
	if enemy_index < 0 or enemy_index >= enemies.size():
		Logger.warn("V3: Invalid enemy index for damage sync: %d" % [enemy_index], "combat")
		return
	
	var enemy = enemies[enemy_index]
	if not enemy.alive:
		if Logger.is_debug():
			Logger.debug("V3: Damage sync on dead enemy %d ignored" % [enemy_index], "combat")
		return
	
	# Update enemy HP
	enemy.hp = new_hp
	
	# Handle death
	if is_death:
		# PHASE 4 OPTIMIZATION: Use reset method instead of manual field clearing
		enemy.reset_to_defaults()
		
		# PHASE 7 OPTIMIZATION: Update bit-field when enemy dies
		_set_enemy_alive(enemy_index, false)
		
		if Logger.is_debug():
			Logger.debug("V3: Enemy %d killed and returned to pool" % [enemy_index], "combat")
		
		# Update EntityTracker
		EntityTracker.unregister_entity(entity_id)

		# Check for event completion via EventSpawnManager
		if event_spawn_manager:
			event_spawn_manager.check_event_completion(entity_id)
	else:
		# Update EntityTracker position/health data
		var entity_data = EntityTracker.get_entity(entity_id)
		if entity_data.has("id"):
			entity_data["hp"] = new_hp

func _handle_spawning(dt: float) -> void:
	# SAFETY CHECK: Don't process any spawning logic if not in arena scene
	# Use dynamic check instead of cached value to handle scene transitions properly
	if not _is_in_arena_scene():
		return
	
	# Check for spawn disabled cheat
	if CheatSystem and CheatSystem.has_method("is_spawn_disabled") and CheatSystem.is_spawn_disabled():
		return

	# Update run time for scaling calculations
	current_run_time += dt

	# Pack spawning removed - unified scaling via DifficultyDirector (future)

	# Handle event spawning via EventSpawnManager
	if event_spawn_manager:
		event_spawn_manager.update(dt)

	# Handle existing auto spawn (wave spawning)
	spawn_timer += dt
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var spawn_count := RNG.randi_range("waves", spawn_count_min, spawn_count_max)
		for i in spawn_count:
			_spawn_enemy()

# _handle_pack_spawning removed - pack spawning system eliminated
# Future: Unified scaling via DifficultyDirector (see task 03)

# _handle_event_spawning moved to EventSpawnManager

# _get_available_event_zones moved to EventSpawnManager

# _select_event_zone moved to EventSpawnManager

# _spawn_event_at_zone moved to EventSpawnManager

# _spawn_event_formation moved to EventSpawnManager
# _spawn_event_enemy moved to EventSpawnManager

# _spawn_pack_formation removed - pack spawning system eliminated

# _select_strategic_formation removed - pack spawning system eliminated

# _calculate_formation_position removed - pack spawning system eliminated

# _is_position_clear removed - pack spawning system eliminated

# _spawn_pack_enemy removed - pack spawning system eliminated

func _spawn_enemy() -> void:
	_spawn_enemy_v2()

# Enemy V2 spawning system
func _spawn_enemy_v2() -> void:
	# Prefer a local preload so later removal is trivial
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Get spawn position using data-driven activation method
	var spawn_pos: Vector2 = _get_data_driven_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return  # No valid spawn position available

	
	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = get_alive_enemies().size()  # Simple spawn indexing
	
	# Create spawn context for EnemyFactory
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 0,  # TODO: Add proper wave tracking
		"spawn_index": local_spawn_counter,
		"position": spawn_pos,
		"context_tags": []  # Optional context tags
	}
	
	# Generate V2 spawn configuration
	var cfg := EnemyFactoryScript.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("EnemyFactoryScript failed to generate spawn config", "waves")
		return
	
	# Convert to legacy EnemyType for existing pooling system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()
	
	# Hand off to existing pooling/rendering system
	_spawn_from_config_v2(legacy_enemy_type, cfg)

## Data-driven spawn position selection based on MapConfig.activation_method
func _get_data_driven_spawn_position() -> Vector2:
	"""Get spawn position using Area2D zones (only method currently supported)."""

	# Get arena scene and map config
	var arena_scene = _get_arena_scene()
	if not arena_scene:
		Logger.error("No arena scene found for spawn position", "spawn")
		return Vector2.ZERO

	var map_config = null
	if "map_config" in arena_scene:
		map_config = arena_scene.map_config as MapConfig

	if not map_config:
		Logger.error("No map_config available for spawn position", "spawn")
		return Vector2.ZERO

	# Use area triggers method (only supported method)
	return _get_area_triggers_spawn_position(arena_scene, map_config)

func _get_area_triggers_spawn_position(arena_scene: Node, map_config: MapConfig) -> Vector2:
	"""AREA_TRIGGERS: Use Area2D spawn zones with proximity filtering."""

	if not "_spawn_zone_areas" in arena_scene:
		Logger.error("AREA_TRIGGERS: No _spawn_zone_areas available in arena scene", "spawn")
		return Vector2.ZERO

	var spawn_zones = arena_scene._spawn_zone_areas
	if spawn_zones.is_empty():
		Logger.error("AREA_TRIGGERS: No spawn zones available", "spawn")
		return Vector2.ZERO

	# Get player position for proximity filtering
	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		# No player position, select random zone
		var selected_zone = spawn_zones[RNG.randi("spawn") % spawn_zones.size()]
		return _generate_position_in_area2d_zone(selected_zone)

	# Apply proximity filtering
	var auto_spawn_range = map_config.auto_spawn_range
	var auto_spawn_min_distance = map_config.auto_spawn_min_distance if "auto_spawn_min_distance" in map_config else 0.0

	var zones_in_range = []
	for zone in spawn_zones:
		var zone_pos = zone.global_position
		var distance_to_center = player_pos.distance_to(zone_pos)
		var zone_radius = _get_zone_radius(zone)

		# Smart proximity: if inside zone, always activate; if outside, check edge distance
		var is_inside_zone = distance_to_center <= zone_radius
		var distance_to_edge = max(0.0, distance_to_center - zone_radius)

		if is_inside_zone or (distance_to_edge >= auto_spawn_min_distance and distance_to_edge <= auto_spawn_range):
			zones_in_range.append(zone)

	if zones_in_range.is_empty():
		Logger.debug("AREA_TRIGGERS: No zones in proximity range (%.0f-%.0fpx), no spawning" % [auto_spawn_min_distance, auto_spawn_range], "spawn")
		return Vector2.ZERO

	# Select random zone from those in range
	var selected_zone = zones_in_range[RNG.randi("spawn") % zones_in_range.size()]
	var spawn_position = _generate_position_in_area2d_zone(selected_zone)

	# Breach validation removed - spawn directly in zone

	var center_distance = player_pos.distance_to(selected_zone.global_position)
	var zone_radius = _get_zone_radius(selected_zone)
	var edge_distance = max(0.0, center_distance - zone_radius)
	var inside_zone = center_distance <= zone_radius
	Logger.debug("AREA_TRIGGERS: Using spawn zone at %s (edge distance: %.0fpx, inside zone: %s)" % [spawn_position, edge_distance, inside_zone], "spawn")
	return spawn_position


func _get_zone_radius(zone: Area2D) -> float:
	"""Get the radius of a circular spawn zone, or return 0 for non-circular zones."""
	if zone.get_child_count() == 0:
		return 0.0

	var collision_shape = zone.get_child(0) as CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return 0.0

	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		return circle_shape.radius

	return 0.0

func _generate_position_in_area2d_zone(zone: Area2D) -> Vector2:
	"""Generate a random position within an Area2D spawn zone."""
	if zone.get_child_count() == 0:
		return zone.global_position

	var collision_shape = zone.get_child(0) as CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return zone.global_position

	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		var angle = RNG.randf_range("spawn", 0.0, TAU)
		var distance = RNG.randf_range("spawn", 0.0, circle_shape.radius)
		return zone.global_position + Vector2.from_angle(angle) * distance

	# For other shapes, just use the zone center
	return zone.global_position


func _spawn_from_config_v2(enemy_type: EnemyType, spawn_config: SpawnConfig) -> Node2D:
	# DECISION: Switch to scene-based enemies only - no more MultiMesh pooled enemies
	# All enemies (boss, elite, regular, swarm) now use existing boss scene spawning logic
	return _spawn_boss_scene(spawn_config)

# Scene-based spawning for all enemy types (bosses and regular enemies)
func _spawn_boss_scene(spawn_config: SpawnConfig) -> Node2D:
	# Event spawning now handled by individual event handlers (BreachEventHandler)
	# No strategy registration needed - events manage their own spawn logic


	# Try to get specific scene for this enemy type
	var enemy_scene: PackedScene = _preloaded_boss_scenes.get(spawn_config.template_id)

	# For boss-tier enemies, fall back to ancient_lich if no specific scene
	if not enemy_scene and spawn_config.render_tier == "boss":
		enemy_scene = _preloaded_boss_scenes.get("ancient_lich")

	if not enemy_scene:
		var message = "No scene available for enemy type: " + spawn_config.template_id + " (render_tier: " + spawn_config.render_tier + ")"
		Logger.warn(message, "waves")
		return null

	# Instantiate enemy scene
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		Logger.warn("Failed to instantiate enemy scene", "waves")
		return null

	# Setup enemy with spawn config
	if enemy_instance.has_method("setup_from_spawn_config"):
		enemy_instance.spawn_config = spawn_config
		enemy_instance.setup_from_spawn_config(spawn_config)

	# Apply modulation if specified - set on sprite before spawn effect
	if spawn_config.modulate != Color.WHITE:
		# Find AnimatedSprite2D and apply modulate so it dissolves in with color
		var sprite = enemy_instance.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = spawn_config.modulate
		else:
			Logger.warn("Could not find AnimatedSprite2D on boss %s for modulate" % spawn_config.template_id, "events")

	# Apply event-specific properties based on strategy
	if spawn_config.event_id and spawn_config.event_id.begins_with("breach_"):
		enemy_instance.set_meta("breach_spawned", true)

	# Use YSort_Objects container for proper Y-sorting, fallback to ArenaRoot
	var spawn_container = _get_ysort_container_or_arena_root()

	spawn_container.add_child(enemy_instance)

	# Add to semantic groups for proper cleanup behavior
	ClearingSemantics.add_semantic_group(enemy_instance, ClearingSemantics.CLEAR_WITH_ENEMIES)
	enemy_instance.add_to_group("enemies")  # Functional group for combat systems

	# Register with boss hit feedback system (only for actual bosses)
	if spawn_config.render_tier == "boss" and boss_hit_feedback:
		boss_hit_feedback.register_boss(enemy_instance)

	return enemy_instance


# AREA_TRIGGERS SPAWNING SYSTEM: Core routing logic
func _spawn_from_type(enemy_type: EnemyType, position: Vector2) -> void:
	if enemy_type.is_special_boss and enemy_type.boss_scene:
		_spawn_special_boss(enemy_type, position)
	else:
		_spawn_pooled_enemy(enemy_type, position)  # Current system unchanged

func _spawn_special_boss(enemy_type: EnemyType, position: Vector2) -> void:
	var boss_node = enemy_type.boss_scene.instantiate()

	# Try to spawn in YSort_Objects container for proper Y-sorting, otherwise use ArenaRoot
	var spawn_container = _get_ysort_container_or_arena_root()

	spawn_container.add_child(boss_node)
	boss_node.global_position = position

	# Add to semantic groups for proper cleanup behavior
	ClearingSemantics.add_semantic_group(boss_node, ClearingSemantics.CLEAR_WITH_ENEMIES)
	boss_node.add_to_group("enemies")  # Functional group for combat systems

	# Connect boss death to EventBus for XP/loot
	if boss_node.has_signal("died"):
		boss_node.died.connect(_on_special_boss_died.bind(enemy_type))

	# DAMAGE V3: Register boss with both EntityTracker and DamageService
	var entity_id = "boss_" + str(boss_node.get_instance_id())
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": boss_node.get_max_health() if boss_node.has_method("get_max_health") else 200.0,
		"max_hp": boss_node.get_max_health() if boss_node.has_method("get_max_health") else 200.0,
		"alive": true,
		"pos": position
	}
	EntityTracker.register_entity(entity_id, entity_data)
	DamageService.register_entity(entity_id, entity_data)

func _spawn_pooled_enemy(enemy_type: EnemyType, position: Vector2) -> void:
	# Existing pooled spawn logic - UNCHANGED
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		# Logger.warn("No free enemy slots available", "waves")  # Disabled for performance testing
		return
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var direction: Vector2 = (target_pos - position).normalized()
	
	var enemy := enemies[free_idx]
	enemy.setup_with_type(enemy_type, position, direction * enemy_type.speed)
	_cache_dirty = true  # Mark cache as dirty when spawning
	
	# DAMAGE V3: Register enemy with both EntityTracker and DamageService
	var entity_id = get_enemy_entity_id(free_idx)
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": enemy.hp,
		"max_hp": enemy.hp,
		"alive": true,
		"pos": position
	}
	EntityTracker.register_entity(entity_id, entity_data)
	DamageService.register_entity(entity_id, entity_data)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		if Logger.is_debug():
			Logger.debug("Spawned pooled enemy: " + enemy_type.id + " (size: " + str(enemy_type.size) + ") registered as " + entity_id, "enemies")

func _on_special_boss_died(enemy_type: EnemyType) -> void:
	# Handle special boss death - emit via EventBus for XP/loot systems (direct parameters - no allocation)
	EventBus.enemy_killed.emit(Vector2.ZERO, enemy_type.xp_value)
	Logger.info("Special boss killed: " + enemy_type.id + " (XP: " + str(enemy_type.xp_value) + ")", "combat")

# PERFORMANCE: _find_enemy_index() eliminated - use enemy.index directly for O(1) access

func _find_free_enemy() -> int:
	# PHASE 7 OPTIMIZATION: Use bit-field for faster alive count tracking
	var alive_count = _get_alive_count_fast()
	
	# PHASE 3: Pool utilization warnings disabled for performance testing
	# var utilization_percent = (float(alive_count) / max_enemies) * 100.0
	# if alive_count >= max_enemies * 0.9:
	#	# Only warn once per 5% threshold to reduce allocations
	#	var threshold = int(utilization_percent / 5) * 5
	#	if threshold != _last_warned_threshold:
	#		Logger.warn("WaveDirector pool high utilization: %d/%d (%d%%)" % [
	#			alive_count, max_enemies, threshold
	#		], "waves")
	#		_last_warned_threshold = threshold
	
	# PHASE 7 OPTIMIZATION: Use bit-field for faster free slot finding
	# Start search from last known free index for better performance
	for i in range(_last_free_index, max_enemies):
		if not _is_enemy_alive_bitfield(i):
			_last_free_index = i
			return i
	
	# If not found, search from beginning to last free index
	for i in range(0, _last_free_index):
		if not _is_enemy_alive_bitfield(i):
			_last_free_index = i
			return i
	
	# Pool exhausted warnings disabled for performance testing
	# var current_time = Time.get_ticks_msec() / 1000.0
	# if current_time - _pool_exhaustion_warning_timer >= POOL_EXHAUSTION_WARNING_COOLDOWN:
	#	Logger.warn("WaveDirector pool exhausted: %d/%d enemies alive - no free slots" % [alive_count, max_enemies], "waves")
	#	_pool_exhaustion_warning_timer = current_time
	return -1

func _update_enemies(dt: float) -> void:
	# Skip enemy AI updates if paused for debug
	if ai_paused:
		return
	
	# PERFORMANCE OPTIMIZATION: Pre-calculate values once
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var update_distance: float = BalanceDB.get_waves_value("enemy_update_distance")
	var update_distance_squared: float = update_distance * update_distance  # Eliminate sqrt calls
	var target_x: float = target_pos.x
	var target_y: float = target_pos.y
	
	# ZERO-ALLOC: Clear entity update queue for this frame
	_entity_update_queue.clear()
	
	# PERFORMANCE: Direct bit-field iteration instead of get_alive_enemies() (eliminates array allocation)
	for i in range(max_enemies):
		if not _is_enemy_alive_bitfield(i):
			continue
			
		var enemy: EnemyEntity = enemies[i]
		var enemy_x: float = enemy.pos.x
		var enemy_y: float = enemy.pos.y
		
		# ZERO-ALLOC: Direct distance calculation without Vector2 allocation
		var dx: float = target_x - enemy_x
		var dy: float = target_y - enemy_y
		var dist_squared: float = dx * dx + dy * dy
		
		# Only update enemies within update distance (using squared distance)
		if dist_squared <= update_distance_squared:
			# ZERO-ALLOC: Direct normalization without Vector2 allocation
			var dist: float = sqrt(dist_squared)
			if dist > 0.001:  # Avoid division by zero
				var inv_dist: float = 1.0 / dist
				var norm_x: float = dx * inv_dist
				var norm_y: float = dy * inv_dist
				
				# Update velocity components directly
				enemy.vel.x = norm_x * enemy.speed
				enemy.vel.y = norm_y * enemy.speed
				
				# Store direction for sprite flipping (reuse normalized values)
				enemy.direction.x = norm_x
				enemy.direction.y = norm_y
				
				# Update position directly
				enemy.pos.x = enemy_x + enemy.vel.x * dt
				enemy.pos.y = enemy_y + enemy.vel.y * dt
				
				# ZERO-ALLOC: Use pooled payload instead of Dictionary allocation
				var entity_id: String = get_enemy_entity_id(i)  # Direct index access (O(1))
				var update_payload = _update_payload_pool.acquire()
				if update_payload:
					update_payload["entity_id"] = entity_id
					update_payload["position"] = enemy.pos
					
					# Queue for batch processing
					if not _entity_update_queue.try_push(update_payload):
						# Queue full - release payload back to pool and continue
						_update_payload_pool.release(update_payload)
	
	# ZERO-ALLOC BATCH PROCESSING: Process ring buffer and release payloads back to pool
	while not _entity_update_queue.is_empty():
		var update_payload = _entity_update_queue.try_pop()
		if update_payload:
			EntityTracker.update_entity_position(update_payload["entity_id"], update_payload["position"])
			DamageService.update_entity_position(update_payload["entity_id"], update_payload["position"])
			
			# Release payload back to pool for reuse
			_update_payload_pool.release(update_payload)

func _is_out_of_bounds(pos: Vector2) -> bool:
	return abs(pos.x) > arena_bounds or abs(pos.y) > arena_bounds

func get_alive_enemies() -> Array[EnemyEntity]:
	var current_frame = Engine.get_process_frames()
	
	# Use cached list if available and not dirty, or if already rebuilt this frame
	if (not _cache_dirty and not _alive_enemies_cache.is_empty()) or _last_cache_frame == current_frame:
		return _alive_enemies_cache
	
	# PHASE 7 OPTIMIZATION: Rebuild cache using bit-field for faster iteration
	_alive_enemies_cache.clear()
	for i in range(enemies.size()):
		if _is_enemy_alive_bitfield(i):
			_alive_enemies_cache.append(enemies[i])
	
	_cache_dirty = false
	_last_cache_frame = current_frame
	return _alive_enemies_cache

func set_enemy_velocity(enemy_index: int, velocity: Vector2) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return
	
	enemy["vel"] = velocity

func clear_all_enemies() -> void:
	"""Clear all enemies using the production entity clearing system"""
	if EntityClearingService:
		EntityClearingService.clear_all_entities()
		if Logger.is_debug():
			Logger.debug("WaveDirector: Cleared enemies via production EntityClearingService", "waves")
	else:
		Logger.error("EntityClearingService not available - cannot clear enemies", "waves")


func stop() -> void:
	"""Stop WaveDirector - halt spawning and clear timers for scene transitions"""
	Logger.info("WaveDirector: Stopping wave spawning", "waves")
	
	# Reset spawn timer to prevent immediate spawning
	spawn_timer = 0.0
	
	# Stop method should only halt spawning, not clear entities
	# Entity clearing happens during SessionManager resets, not during stop()
	
	# Mark as stopped (add is_running flag if needed)
	Logger.info("WaveDirector: Stopped successfully", "waves")

func reset() -> void:
	"""Reset WaveDirector state for clean scene transitions"""
	Logger.info("WaveDirector: Resetting state", "waves")
	
	# Reset spawn timer
	spawn_timer = 0.0
	
	# Clear cached alive enemies
	_alive_enemies_cache.clear()
	_cache_dirty = true
	_last_free_index = 0
	
	# Reset AI pause state
	ai_paused = false
	
	# PHASE 7 OPTIMIZATION: Clear all enemies using bit-field
	for i in range(enemies.size()):
		if _is_enemy_alive_bitfield(i):
			# PHASE 4 OPTIMIZATION: Use reset method instead of manual field clearing
			enemies[i].reset_to_defaults()
			# PHASE 7 OPTIMIZATION: Update bit-field
			_set_enemy_alive(i, false)

	# Reset breach event handler state
	if breach_handler:
		breach_handler.reset()

	Logger.info("WaveDirector: Reset completed", "waves")

func _on_cheat_toggled(payload) -> void:
	# Handle AI pause/unpause cheat toggle
	if payload.cheat_name == "ai_paused":
		ai_paused = payload.enabled

func _on_player_died() -> void:
	"""Handle player death - stop spawning but keep enemies alive for results screen"""
	Logger.info("WaveDirector: Player died, stopping spawning (enemies preserved for results)", "waves")
	
	# Stop spawning immediately
	stop()
	
	# Pause AI for dramatic effect but don't clear enemies yet
	# Enemies will be cleared by SessionManager when user transitions from results screen
	ai_paused = true


func _clear_all_enemies() -> void:
	"""Clear all enemies from the pool and scene"""
	Logger.info("WaveDirector: Clearing all enemies", "waves")
	
	# PHASE 7 OPTIMIZATION: Clear all pooled enemies using bit-field
	for i in range(enemies.size()):
		if _is_enemy_alive_bitfield(i):
			# PHASE 4 OPTIMIZATION: Use reset method instead of manual field clearing
			enemies[i].reset_to_defaults()
			# PHASE 7 OPTIMIZATION: Update bit-field
			_set_enemy_alive(i, false)
	
	# Clear cache
	_alive_enemies_cache.clear()
	_cache_dirty = true
	
	# DECISION: No longer emit enemies_updated for MultiMesh - scene enemies handled by EntityClearingService
	
	Logger.info("WaveDirector: All enemies cleared", "waves")

func _is_in_arena_scene() -> bool:
	"""Check if SpawnDirector is running in an Arena scene to prevent spawning in other scenes
	Uses type-safe BaseArena class detection - future-proof for all arena types
	Also handles dynamic scene loading where Arena is loaded as child of Main"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return false

	# Check if current scene is directly a BaseArena
	if current_scene is BaseArena:
		return true

	# Check if any child of current scene is a BaseArena (for dynamic loading)
	for child in current_scene.get_children():
		if child is BaseArena:
			return true

	# FIX: Allow performance test scenes to use SpawnDirector
	if current_scene.name == "PerformanceTest":
		return true

	return false

func _find_arena_scene() -> Node:
	"""Find the arena scene in the current scene tree for accessing map_config.
	Returns the arena scene node or null if not found."""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null

	# Check if current scene is directly a BaseArena
	if current_scene is BaseArena:
		return current_scene

	# Check if any child of current scene is a BaseArena (for dynamic loading)
	for child in current_scene.get_children():
		if child is BaseArena:
			return child

	return null

func _get_arena_scene() -> Node:
	"""Get the current arena scene. Simple wrapper around _find_arena_scene for clarity."""
	return _find_arena_scene()

func _check_event_completion(killed_entity_id: String) -> void:
	"""Check if any active events are completed by enemy death."""

	# Simple completion logic: event completes when any enemy dies in event area
	# This could be enhanced later with more sophisticated event mechanics
	var completed_events: Array[int] = []

	var events_to_check = event_spawn_manager.active_events if event_spawn_manager else []
	for i in range(events_to_check.size()):
		var event_data = events_to_check[i]
		var event_def = event_data.event_def

		# Simple completion: any kill in the event zone completes the event
		# More sophisticated logic could track specific spawned enemies
		if killed_entity_id.begins_with("enemy_"):
			# Check if killed enemy was near the event zone
			var event_zone = event_data.zone as Area2D
			var zone_pos = event_zone.global_position

			# Extract enemy index and check position
			var enemy_index_str = killed_entity_id.replace("enemy_", "")
			var enemy_index = enemy_index_str.to_int()

			if enemy_index >= 0 and enemy_index < enemies.size():
				var enemy_pos = enemies[enemy_index].pos
				var distance_to_zone = zone_pos.distance_to(enemy_pos)

				# If enemy was within event zone radius, count it as event completion
				var zone_radius = 100.0  # Default event completion radius
				if event_zone.get_child_count() > 0:
					var collision_shape = event_zone.get_child(0) as CollisionShape2D
					if collision_shape and collision_shape.shape is CircleShape2D:
						var circle_shape = collision_shape.shape as CircleShape2D
						zone_radius = circle_shape.radius * 1.5  # Allow some margin

				if distance_to_zone <= zone_radius:
					completed_events.append(i)

					# Emit event completion signal with performance data
					var performance_data = {
						"duration": Time.get_time_dict_from_system(),  # TODO: Calculate actual duration
						"enemies_killed": 1,  # Simple metric for now
						"zone": event_zone.name
					}

					EventBus.event_completed.emit(event_def.event_type, performance_data)

					Logger.info("Event completed: %s at zone %s" % [
						event_def.event_type, event_zone.name
					], "events")

	# Remove completed events (iterate backwards to avoid index issues)
	if event_spawn_manager:
		for i in range(completed_events.size() - 1, -1, -1):
			var event_index = completed_events[i]
			event_spawn_manager.active_events.remove_at(event_index)
