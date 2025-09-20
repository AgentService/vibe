extends Node

## Unified spawn director managing all enemy spawning: waves, packs, bosses, events.
## Spawns enemies using zone-based proximity logic with run-based scaling.
## Updates on fixed combat step (30 Hz) for deterministic behavior.
## Uses Enemy V2 system for weighted enemy spawning and dynamic pack composition.

class_name SpawnDirector

# Import ArenaSystem for dependency injection
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")

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

# UNIFIED SPAWNING: Pack spawning state (new functionality)
var current_run_time: float = 0.0
var current_wave_level: int = 1
var pack_spawn_timer: float = 0.0
var pack_spawn_enabled: bool = true

# EVENT SYSTEM: Event spawning state
var event_system_enabled: bool = false
var event_timer: float = 0.0
var next_event_delay: float = 45.0
var active_events: Array[Dictionary] = []
var mastery_system

# BREACH EVENT HANDLER: Separate handler for breach events
var breach_handler: BreachEventHandler

# ZONE COOLDOWN SYSTEM: Prevent rapid consecutive spawns in same zones
var _zone_cooldowns: Dictionary = {}  # zone_name -> cooldown_remaining
var zone_cooldown_duration: float = 15.0  # Seconds before zone can be used again

# ZONE THREAT ESCALATION: Track player behavior and respond with escalating threats
var _zone_threat_levels: Dictionary = {}  # zone_name -> threat_level (0.0 to 1.0)
var _zone_player_presence: Dictionary = {}  # zone_name -> time_spent_nearby
var _zone_last_combat: Dictionary = {}  # zone_name -> time_since_last_combat
var threat_escalation_enabled: bool = true
var threat_decay_rate: float = 0.1  # How fast threat levels decay when not reinforced

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
	"""Initialize the event mastery system"""
	mastery_system = EventMasterySystem.mastery_system_instance

	# Enable event system by default
	event_system_enabled = true

	Logger.info("Event system initialized using autoload", "events")

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
	if event_system_enabled and breach_handler:
		breach_handler.update(dt)

func _on_breach_activated(breach_event: EventInstance) -> void:
	"""Handle breach activation logging"""
	Logger.debug("SpawnDirector: Breach activated at %s" % breach_event.center_position, "events")

func _on_breach_completed(breach_event: EventInstance, performance_data: Dictionary) -> void:
	"""Handle breach completion logging"""
	Logger.debug("SpawnDirector: Breach completed with %d enemies spawned" % performance_data.get("enemies_spawned", 0), "events")

# SPATIAL RESTRICTION HELPERS: Prevent regular spawning inside breach circles
func _is_position_inside_any_breach(position: Vector2) -> bool:
	"""Check if a position is inside any active breach circle"""
	if not breach_handler:
		return false

	for breach_event in breach_handler.active_breach_events:
		var distance = position.distance_to(breach_event.center_position)
		if distance <= breach_event.current_radius:
			return true

	return false

func _get_alternative_spawn_position(arena_scene, original_pos: Vector2) -> Vector2:
	"""Try to find alternative spawn position outside breach circles"""
	var max_attempts = 10
	var attempt = 0

	while attempt < max_attempts:
		var test_pos = arena_scene.get_random_spawn_position()
		if test_pos != Vector2.ZERO and not _is_position_inside_any_breach(test_pos):
			return test_pos
		attempt += 1

	# No valid position found
	return Vector2.ZERO

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

	_update_zone_cooldowns(payload.dt)
	_update_zone_threat_escalation(payload.dt)
	_handle_spawning(payload.dt)
	_update_enemies(payload.dt)
	_update_breach_system(payload.dt)
	# DECISION: No longer emit enemies_updated signal for MultiMesh - scene enemies self-manage

func _update_zone_cooldowns(dt: float) -> void:
	"""Update cooldown timers for all spawn zones."""
	var expired_zones: Array[String] = []

	for zone_name in _zone_cooldowns.keys():
		_zone_cooldowns[zone_name] -= dt
		if _zone_cooldowns[zone_name] <= 0.0:
			expired_zones.append(zone_name)

	# Clean up expired cooldowns
	for zone_name in expired_zones:
		_zone_cooldowns.erase(zone_name)

func _is_zone_available(zone_name: String) -> bool:
	"""Check if a spawn zone is available (not on cooldown)."""
	return not _zone_cooldowns.has(zone_name)

func _set_zone_cooldown(zone_name: String) -> void:
	"""Set cooldown for a spawn zone after successful pack spawn."""
	_zone_cooldowns[zone_name] = zone_cooldown_duration
	Logger.debug("Zone %s on cooldown for %.1f seconds" % [zone_name, zone_cooldown_duration], "arena")

func _update_zone_threat_escalation(dt: float) -> void:
	"""Update threat escalation tracking based on player behavior."""
	if not threat_escalation_enabled:
		return

	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		return

	# Get all spawn zones from current arena
	var arena_scene = _get_arena_scene()
	if not arena_scene or not "_spawn_zone_areas" in arena_scene:
		return

	var spawn_zones = arena_scene._spawn_zone_areas
	var player_proximity_range = 200.0  # Distance to track player presence

	# Update player presence and threat decay for each zone
	for zone_area in spawn_zones:
		var zone_name = zone_area.name
		var zone_pos = zone_area.global_position
		var distance_to_player = player_pos.distance_to(zone_pos)

		# Initialize zone data if needed
		if not _zone_threat_levels.has(zone_name):
			_zone_threat_levels[zone_name] = 0.0
		if not _zone_player_presence.has(zone_name):
			_zone_player_presence[zone_name] = 0.0
		if not _zone_last_combat.has(zone_name):
			_zone_last_combat[zone_name] = 0.0

		# Track player presence near zone
		if distance_to_player <= player_proximity_range:
			_zone_player_presence[zone_name] += dt

			# Gradual threat escalation when player lingers
			if _zone_player_presence[zone_name] > 30.0:  # After 30 seconds
				var escalation_rate = 0.02  # 2% per second when lingering
				_zone_threat_levels[zone_name] = minf(1.0, _zone_threat_levels[zone_name] + escalation_rate * dt)
		else:
			# Decay presence tracking when player moves away
			_zone_player_presence[zone_name] = maxf(0.0, _zone_player_presence[zone_name] - dt * 2.0)

		# Decay threat levels over time (zones become "safer" if unused)
		_zone_threat_levels[zone_name] = maxf(0.0, _zone_threat_levels[zone_name] - threat_decay_rate * dt)

		# Update time since last combat in zone
		_zone_last_combat[zone_name] += dt

func _get_zone_threat_level(zone_name: String) -> float:
	"""Get current threat level for a zone (0.0 to 1.0)."""
	return _zone_threat_levels.get(zone_name, 0.0)

func _escalate_zone_threat(zone_name: String, escalation_amount: float) -> void:
	"""Increase threat level for a zone (called when combat occurs)."""
	if not _zone_threat_levels.has(zone_name):
		_zone_threat_levels[zone_name] = 0.0

	_zone_threat_levels[zone_name] = minf(1.0, _zone_threat_levels[zone_name] + escalation_amount)
	_zone_last_combat[zone_name] = 0.0  # Reset combat timer
	Logger.debug("Zone %s threat escalated to %.2f" % [zone_name, _zone_threat_levels[zone_name]], "arena")

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

		# Check for event completion
		_check_event_completion(entity_id)
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

	# Handle pack spawning (new unified functionality)
	_handle_pack_spawning(dt)

	# Handle event spawning
	if event_system_enabled:
		_handle_event_spawning(dt)

	# Handle existing auto spawn (wave spawning)
	spawn_timer += dt
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var spawn_count := RNG.randi_range("waves", spawn_count_min, spawn_count_max)
		for i in spawn_count:
			_spawn_enemy()

func _handle_pack_spawning(dt: float) -> void:
	"""Handle pack-based spawning with proximity detection and scaling.
	Spawns enemy packs within pack_spawn_range (1600px) of player based on time intervals."""

	if not pack_spawn_enabled:
		return

	# Update pack spawn timer
	pack_spawn_timer += dt

	# Get current arena scene
	var arena_scene = _get_arena_scene()
	if not arena_scene:
		Logger.debug("Pack spawning: No arena scene available", "arena")
		return

	var has_map_config_property = ("map_config" in arena_scene)
	var map_config_value = arena_scene.map_config if has_map_config_property else null

	if not has_map_config_property or not map_config_value:
		Logger.debug("Pack spawning: No arena map_config available (scene=%s)" % arena_scene.name, "arena")
		return

	var map_config = arena_scene.map_config as MapConfig
	if not map_config:
		Logger.debug("Pack spawning: Invalid map_config type (scene=%s)" % arena_scene.name, "arena")
		return

	var scaling = map_config.get_effective_scaling()
	var pack_interval = scaling.get("pack_spawn_interval", 60.0)


	# Check if it's time to spawn a pack
	if pack_spawn_timer < pack_interval:
		return

	# Reset timer
	pack_spawn_timer = 0.0

	# Get player position for proximity checking
	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		Logger.debug("Pack spawning: No valid player position", "arena")
		return

	# Get zones within pack spawn range (prefer distant zones to spawn off-screen)
	var pack_spawn_range = scaling.get("pack_spawn_range", 500.0)  # Use pack spawn range, not interval
	var pack_spawn_min_distance = 800.0  # Default minimum distance
	if map_config:
		pack_spawn_range = map_config.pack_spawn_range
		pack_spawn_min_distance = map_config.pack_spawn_min_distance if "pack_spawn_min_distance" in map_config else 800.0

	# Use arena scene zones with min/max distance filtering + cooldown filtering
	var zones_in_pack_range = []
	if arena_scene and arena_scene.has_method("filter_zones_by_distance_range"):
		# Get scene zones and filter by min/max pack spawn range
		var scene_spawn_zones = arena_scene._spawn_zone_areas if "_spawn_zone_areas" in arena_scene else []
		if not scene_spawn_zones.is_empty():
			var distance_filtered_zones = arena_scene.filter_zones_by_distance_range(scene_spawn_zones, player_pos, pack_spawn_min_distance, pack_spawn_range)

			# Further filter by zone availability (cooldown system)
			for zone_area in distance_filtered_zones:
				if _is_zone_available(zone_area.name):
					zones_in_pack_range.append(zone_area)

	if zones_in_pack_range.is_empty():
		Logger.debug("Pack spawning: No available zones (all in range on cooldown)", "arena")
		return

	# Calculate base pack size with MapLevel-based scaling
	var base_min = scaling.get("pack_base_size_min", 5)
	var base_max = scaling.get("pack_base_size_max", 10)
	var max_multiplier = scaling.get("max_scaling_multiplier", 2.5)

	# Use MapLevel system for consistent difficulty progression
	var level_multiplier = MapLevel.get_pack_size_scaling() if MapLevel else 1.0
	var wave_scaling = scaling.get("wave_scaling_rate", 0.15)
	var wave_multiplier = 1.0 + (current_wave_level - 1) * wave_scaling

	# Combine level and wave scaling, capped at max multiplier
	var base_total_multiplier = minf(level_multiplier * wave_multiplier, max_multiplier)

	# DYNAMIC SCALING: Adjust pack size based on current enemy density and available zones
	var current_enemy_count = _get_alive_count_fast()
	var max_enemies_threshold = max_enemies * 0.7  # Don't spawn large packs when near capacity

	# Density-based reduction: reduce pack size when arena is crowded
	var density_factor = 1.0
	if current_enemy_count > max_enemies_threshold:
		density_factor = maxf(0.3, 1.0 - float(current_enemy_count - max_enemies_threshold) / (max_enemies * 0.3))

	# Zone availability factor: prefer smaller packs when few zones available
	var available_zone_count = zones_in_pack_range.size()
	var total_zones = arena_scene._spawn_zone_areas.size() if "_spawn_zone_areas" in arena_scene else 5
	var zone_availability_factor = float(available_zone_count) / total_zones

	# Calculate average threat level of available zones (higher threat = larger packs)
	var total_threat = 0.0
	for zone_area in zones_in_pack_range:
		total_threat += _get_zone_threat_level(zone_area.name)
	var average_threat = total_threat / available_zone_count if available_zone_count > 0 else 0.0
	var threat_multiplier = 1.0 + (average_threat * 0.5)  # Up to 50% size increase for high-threat zones

	# Combined scaling with density, zone constraints, and threat escalation
	var final_multiplier = base_total_multiplier * density_factor * zone_availability_factor * threat_multiplier
	final_multiplier = maxf(0.5, minf(final_multiplier, max_multiplier))  # Clamp to reasonable range

	var scaled_min = maxi(2, int(base_min * final_multiplier))  # Minimum 2 enemies per pack
	var scaled_max = maxi(scaled_min + 1, int(base_max * final_multiplier))
	var pack_size = RNG.randi_range("packs", scaled_min, scaled_max)

	var current_level = MapLevel.current_level if MapLevel else 1
	Logger.info("Pack spawning: size=%d, multiplier=%.2f (level=%d, wave=%d, density=%.2f, zones=%d/%d, threat=%.2f)" % [pack_size, final_multiplier, current_level, current_wave_level, density_factor, available_zone_count, total_zones, average_threat], "arena")

	# Select zone from pack range, preferring distant zones for off-screen spawning
	var selected_zone: Area2D
	if zones_in_pack_range.size() == 1:
		selected_zone = zones_in_pack_range[0]
	else:
		# Sort zones by distance (furthest first) and weight selection toward distant zones
		var zone_distances: Array[Dictionary] = []
		for zone in zones_in_pack_range:
			var distance = player_pos.distance_to(zone.global_position)
			zone_distances.append({"zone": zone, "distance": distance})

		# Sort by distance descending (furthest first)
		zone_distances.sort_custom(func(a, b): return a.distance > b.distance)

		# Weight selection toward first half (furthest zones) - 70% chance for distant zones
		var selection_pool_size = max(1, zone_distances.size() / 2)
		if RNG.randf("packs") < 0.7 and selection_pool_size > 0:
			# Select from distant zones (first half)
			var distant_index = RNG.randi_range("packs", 0, selection_pool_size - 1)
			selected_zone = zone_distances[distant_index].zone
		else:
			# Fallback to any available zone
			var random_index = RNG.randi_range("packs", 0, zone_distances.size() - 1)
			selected_zone = zone_distances[random_index].zone

	# Use shared method to get proper position within zone radius
	var spawn_position = arena_scene.generate_position_in_scene_zone(selected_zone)

	# Get zone radius for formation (need for formation spread)
	var zone_radius = 50.0  # Default
	if selected_zone.get_child_count() > 0:
		var collision_shape = selected_zone.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			zone_radius = circle_shape.radius

	# Set zone cooldown to prevent rapid re-use
	_set_zone_cooldown(selected_zone.name)

	# Escalate threat in the zone where pack spawned
	_escalate_zone_threat(selected_zone.name, 0.15)  # 15% threat increase per pack spawn

	_spawn_pack_formation(pack_size, spawn_position, zone_radius)

func _handle_event_spawning(dt: float) -> void:
	"""Handle event-based spawning with mastery modifiers."""

	# Update event timer
	event_timer += dt
	if event_timer < next_event_delay:
		return

	# Reset timer
	event_timer = 0.0

	# Get current arena and map config
	var arena_scene = _get_arena_scene()
	if not arena_scene or not "map_config" in arena_scene:
		Logger.debug("Event spawning: No arena scene or map config available", "events")
		return

	var map_config = arena_scene.map_config as MapConfig
	if not map_config or not map_config.event_spawn_enabled:
		Logger.debug("Event spawning: Events disabled in arena config", "events")
		return

	# Update event delay from map config
	next_event_delay = map_config.event_spawn_interval

	# Get player position for zone filtering
	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		Logger.debug("Event spawning: No valid player position", "events")
		return

	# Get available zones for event spawning (uses pack spawn range for events)
	var available_zones = _get_available_event_zones(player_pos, map_config)
	if available_zones.is_empty():
		Logger.debug("Event spawning: No available zones (all on cooldown or out of range)", "events")
		return

	# Select random event type from arena configuration
	var event_type = map_config.get_random_event_type()
	if event_type == "":
		Logger.debug("Event spawning: No event types configured for arena", "events")
		return

	# Get event definition from mastery system
	var event_def = mastery_system.get_event_definition(event_type)
	if not event_def:
		Logger.warn("Event spawning: No definition found for event type: %s" % event_type, "events")
		return

	# Apply mastery modifiers to event configuration
	var modified_config = mastery_system.apply_event_modifiers(event_def)

	# Select zone for event spawning (prefer distant zones)
	var selected_zone = _select_event_zone(available_zones, player_pos)

	# Set zone cooldown to prevent immediate reuse
	_set_zone_cooldown(selected_zone.name)

	# Escalate threat in the zone where event spawned
	_escalate_zone_threat(selected_zone.name, 0.20)  # 20% threat increase per event

	# Spawn the event
	_spawn_event_at_zone(event_def, modified_config, selected_zone)

	Logger.info("Event spawned: %s at zone %s with %d enemies" % [
		event_type, selected_zone.name, modified_config.get("monster_count", 0)
	], "events")

func _get_available_event_zones(player_pos: Vector2, map_config: MapConfig) -> Array[Area2D]:
	"""Get zones available for event spawning with distance and cooldown filtering."""
	var arena_scene = _get_arena_scene()
	if not arena_scene or not "_spawn_zone_areas" in arena_scene:
		return []

	var all_scene_zones = arena_scene._spawn_zone_areas
	var event_spawn_range = map_config.pack_spawn_range  # Use pack spawn range for events
	var event_spawn_min_distance = map_config.pack_spawn_min_distance

	var available_zones: Array[Area2D] = []

	# Filter zones by distance and cooldown
	for zone_area in all_scene_zones:
		var distance = player_pos.distance_to(zone_area.global_position)

		# Check distance range (prefer off-screen spawning)
		if distance < event_spawn_min_distance or distance > event_spawn_range:
			continue

		# Check zone cooldown
		if not _is_zone_available(zone_area.name):
			continue

		available_zones.append(zone_area)

	return available_zones

func _select_event_zone(available_zones: Array[Area2D], player_pos: Vector2) -> Area2D:
	"""Select zone for event spawning, preferring distant zones."""
	if available_zones.size() == 1:
		return available_zones[0]

	# Sort zones by distance (furthest first)
	var zone_distances: Array[Dictionary] = []
	for zone in available_zones:
		var distance = player_pos.distance_to(zone.global_position)
		zone_distances.append({"zone": zone, "distance": distance})

	zone_distances.sort_custom(func(a, b): return a.distance > b.distance)

	# Prefer distant zones (70% chance for furthest half)
	var selection_pool_size = max(1, zone_distances.size() / 2)
	if RNG.randf("events") < 0.7 and selection_pool_size > 0:
		var distant_index = RNG.randi_range("events", 0, selection_pool_size - 1)
		return zone_distances[distant_index].zone
	else:
		var random_index = RNG.randi_range("events", 0, zone_distances.size() - 1)
		return zone_distances[random_index].zone

func _spawn_event_at_zone(event_def, config: Dictionary, zone: Area2D) -> void:
	"""Spawn event enemies at selected zone using pack formation system."""

	# Use existing pack spawning logic with event-specific parameters
	var monster_count = config.get("monster_count", 8)
	var formation = config.get("formation", "circle")

	# Get spawn position and zone radius
	var arena_scene = _get_arena_scene()
	if not arena_scene:
		Logger.warn("Event spawning: Failed to get arena scene", "events")
		return

	var spawn_position = arena_scene.generate_position_in_scene_zone(zone)

	var zone_radius = 50.0  # Default
	if zone.get_child_count() > 0:
		var collision_shape = zone.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			zone_radius = circle_shape.radius

	# Emit event started signal
	EventBus.event_started.emit(event_def.event_type, zone)

	# Spawn event enemies using existing pack formation system
	_spawn_event_formation(monster_count, spawn_position, zone_radius, event_def)

	# Track event for completion detection
	active_events.append({
		"type": event_def.event_type,
		"zone": zone,
		"start_time": Time.get_time_dict_from_system(),
		"config": config,
		"event_def": event_def,
		"monster_count": monster_count,
		"spawned_enemies": []  # Track spawned enemy IDs for completion detection
	})

func _spawn_event_formation(pack_size: int, center_pos: Vector2, formation_radius: float, event_def) -> void:
	"""Spawn event enemies in formation (reuses pack formation logic)."""

	# Use existing pack formation logic but mark enemies as event spawns
	var formation_type = _select_strategic_formation(pack_size, center_pos)
	var min_enemy_separation = 32.0
	var occupied_positions: Array[Vector2] = []
	var successful_spawns = 0
	var max_attempts_per_enemy = 5

	for i in pack_size:
		var spawn_pos: Vector2
		var valid_position_found = false

		for attempt in max_attempts_per_enemy:
			spawn_pos = _calculate_formation_position(formation_type, i, pack_size, center_pos, formation_radius, min_enemy_separation, attempt)

			if _is_position_clear(spawn_pos, min_enemy_separation, occupied_positions):
				valid_position_found = true
				occupied_positions.append(spawn_pos)
				break

		if valid_position_found:
			_spawn_event_enemy(spawn_pos, event_def)
			successful_spawns += 1

	Logger.info("Event formation spawned: %d/%d enemies for %s event" % [
		successful_spawns, pack_size, event_def.event_type
	], "events")

func _spawn_event_enemy(position: Vector2, event_def) -> void:
	"""Spawn a single event enemy using Enemy V2 system with event context."""

	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")

	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = get_alive_enemies().size()

	# Create spawn context for EnemyFactory - mark as event spawn
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": current_wave_level,
		"spawn_index": local_spawn_counter,
		"position": position,
		"context_tags": ["event", event_def.event_type],  # Mark as event spawn with type
		"spawn_type": "event",  # Additional metadata
		"event_type": event_def.event_type  # Event-specific context
	}

	# Generate V2 spawn configuration using existing system
	var cfg := EnemyFactoryScript.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("Event spawning: Failed to generate spawn config for %s" % event_def.event_type, "events")
		return

	# Apply event-specific modifiers to spawn config if needed
	if event_def.base_config.has("xp_multiplier"):
		# Apply event XP multiplier to spawned enemies
		var xp_multiplier = event_def.base_config.get("xp_multiplier", 1.0)
		# Note: This would require extending SpawnConfig to support XP modifiers
		# For now, the multiplier will be applied during XP calculation

	# Convert to legacy EnemyType for existing system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()

	# Use existing spawn system
	_spawn_from_config_v2(legacy_enemy_type, cfg)

func _spawn_pack_formation(pack_size: int, center_pos: Vector2, formation_radius: float) -> void:
	"""Spawn a pack of enemies in formation around a center point with overlap detection.
	Enemies start with chase_enabled = false for PreSpawn behavior."""

	# Enhanced formation patterns with strategic positioning
	var formation_type = _select_strategic_formation(pack_size, center_pos)
	var min_enemy_separation = 32.0  # Minimum distance between enemies
	var occupied_positions: Array[Vector2] = []
	var successful_spawns = 0
	var max_attempts_per_enemy = 5

	for i in pack_size:
		var spawn_pos: Vector2
		var valid_position_found = false

		for attempt in max_attempts_per_enemy:
			spawn_pos = _calculate_formation_position(formation_type, i, pack_size, center_pos, formation_radius, min_enemy_separation, attempt)

			# Check if position conflicts with existing enemies or pack members
			if _is_position_clear(spawn_pos, min_enemy_separation, occupied_positions):
				valid_position_found = true
				occupied_positions.append(spawn_pos)
				break

			# Add some randomization for subsequent attempts
			if attempt == max_attempts_per_enemy - 1:
				Logger.debug("Pack formation: Failed to find clear position for enemy %d after %d attempts" % [i, max_attempts_per_enemy], "arena")

		if valid_position_found:
			_spawn_pack_enemy(spawn_pos)
			successful_spawns += 1

	var spawn_efficiency = float(successful_spawns) / pack_size * 100.0
	var formation_names = ["Circle", "Line", "Cluster", "Wedge", "Ambush", "Pincer"]
	var formation_name = formation_names[formation_type] if formation_type < formation_names.size() else "Unknown"
	Logger.info("Pack spawned: %d/%d enemies in %s formation at %s (%.1f%% efficiency)" % [successful_spawns, pack_size, formation_name, center_pos, spawn_efficiency], "arena")

func _select_strategic_formation(pack_size: int, center_pos: Vector2) -> int:
	"""Select formation type based on tactical considerations."""
	var player_pos = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO

	# Consider pack size for formation selection
	if pack_size <= 3:
		# Small packs: prefer ambush formations (cluster, wedge)
		return RNG.randi_range("packs", 2, 3)  # Cluster or Wedge
	elif pack_size <= 6:
		# Medium packs: balanced selection
		return RNG.randi_range("packs", 0, 4)  # All formations except Pincer
	else:
		# Large packs: prefer organized formations
		var organized_formations = [0, 1, 5]  # Circle, Line, Pincer
		return organized_formations[RNG.randi_range("packs", 0, organized_formations.size() - 1)]

func _calculate_formation_position(formation_type: int, enemy_index: int, pack_size: int, center_pos: Vector2, formation_radius: float, min_separation: float, attempt: int) -> Vector2:
	"""Calculate spawn position for enemy in formation."""
	match formation_type:
		0: # Circle formation - classic surround
			var base_angle = (float(enemy_index) / pack_size) * TAU
			var angle_jitter = RNG.randf_range("packs", -0.2, 0.2) if attempt > 0 else 0.0
			var distance_jitter = RNG.randf_range("packs", 0.8, 1.0) if attempt > 0 else 1.0
			var distance = formation_radius * 0.7 * distance_jitter
			return center_pos + Vector2.from_angle(base_angle + angle_jitter) * distance

		1: # Line formation - wall of enemies
			var line_length = formation_radius * 1.5
			var step = line_length / max(pack_size - 1, 1)
			var offset = (enemy_index - pack_size * 0.5) * step
			var line_angle = RNG.randf_range("packs", 0.0, TAU)
			var perpendicular_offset = RNG.randf_range("packs", -min_separation, min_separation) if attempt > 0 else 0.0
			var base_pos = center_pos + Vector2.from_angle(line_angle) * offset
			return base_pos + Vector2.from_angle(line_angle + PI/2) * perpendicular_offset

		2: # Cluster formation - tight group
			var cluster_angle = RNG.randf_range("packs", 0.0, TAU)
			var max_distance = formation_radius * 0.6  # Tighter than other formations
			var cluster_distance = RNG.randf_range("packs", min_separation, max_distance)
			return center_pos + Vector2.from_angle(cluster_angle) * cluster_distance

		3: # Wedge formation - arrow pointing toward player
			var player_pos = PlayerState.position if PlayerState.has_player_reference() else center_pos + Vector2(0, -100)
			var to_player = (player_pos - center_pos).normalized()
			var wedge_angle = to_player.angle()
			var layer = enemy_index / 2  # Two enemies per layer
			var side = 1 if enemy_index % 2 == 0 else -1  # Alternate sides
			var layer_distance = layer * min_separation * 1.5
			var side_offset = side * layer * min_separation * 0.7
			var base_pos = center_pos + Vector2.from_angle(wedge_angle) * layer_distance
			return base_pos + Vector2.from_angle(wedge_angle + PI/2) * side_offset

		4: # Ambush formation - scattered for flanking
			var scatter_angle = RNG.randf_range("packs", 0.0, TAU)
			var scatter_distance = RNG.randf_range("packs", formation_radius * 0.4, formation_radius * 0.9)
			var jitter_x = RNG.randf_range("packs", -min_separation, min_separation)
			var jitter_y = RNG.randf_range("packs", -min_separation, min_separation)
			return center_pos + Vector2.from_angle(scatter_angle) * scatter_distance + Vector2(jitter_x, jitter_y)

		5: # Pincer formation - two groups on opposite sides
			var player_pos = PlayerState.position if PlayerState.has_player_reference() else center_pos + Vector2(0, -100)
			var to_player = (player_pos - center_pos).normalized()
			var pincer_side = 1 if enemy_index < pack_size / 2 else -1
			var group_center_angle = to_player.angle() + pincer_side * PI * 0.4  # 72 degrees from center
			var group_index = enemy_index % (pack_size / 2)
			var group_size = pack_size / 2
			var local_angle = (float(group_index) / group_size) * PI * 0.3 - PI * 0.15  # Spread within group
			var distance = formation_radius * 0.8
			return center_pos + Vector2.from_angle(group_center_angle + local_angle) * distance

		_: # Default to cluster if invalid formation type
			var cluster_angle = RNG.randf_range("packs", 0.0, TAU)
			var max_distance = formation_radius * 0.8
			var cluster_distance = RNG.randf_range("packs", min_separation, max_distance)
			return center_pos + Vector2.from_angle(cluster_angle) * cluster_distance

func _is_position_clear(test_pos: Vector2, min_separation: float, occupied_positions: Array[Vector2]) -> bool:
	"""Check if a position is clear of existing enemies and pack members."""

	# Check against other pack members being spawned
	for occupied_pos in occupied_positions:
		if test_pos.distance_to(occupied_pos) < min_separation:
			return false

	# Check against existing alive enemies using optimized bit-field iteration
	var separation_squared = min_separation * min_separation
	for i in range(max_enemies):
		if not _is_enemy_alive_bitfield(i):
			continue

		var enemy_pos = enemies[i].pos
		var distance_squared = test_pos.distance_squared_to(enemy_pos)
		if distance_squared < separation_squared:
			return false

	return true

func _spawn_pack_enemy(position: Vector2) -> void:
	"""Spawn a single pack enemy using the existing Enemy V2 system."""

	# Use the same enemy spawning system as regular spawning
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")

	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = get_alive_enemies().size()

	# Create spawn context for EnemyFactory - mark as pack spawn
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": current_wave_level,
		"spawn_index": local_spawn_counter,
		"position": position,
		"context_tags": ["pack"],  # Mark as pack spawn for future behavior customization
		"spawn_type": "pack"  # Additional metadata
	}

	# Generate V2 spawn configuration using existing system
	var cfg := EnemyFactoryScript.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("Pack spawning: Failed to generate spawn config", "arena")
		return

	# Convert to legacy EnemyType for existing system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()

	# Use existing spawn system
	_spawn_from_config_v2(legacy_enemy_type, cfg)

func _spawn_enemy() -> void:
	_spawn_enemy_v2()

# Enemy V2 spawning system
func _spawn_enemy_v2() -> void:
	# Prefer a local preload so later removal is trivial
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Get spawn position from current arena (supports zone-based spawning)
	var spawn_pos: Vector2
	var current_scene = get_tree().current_scene

	# Try to use arena's zone-based spawning if available (check both current scene and arena children)
	var arena_scene = null
	if current_scene and current_scene.has_method("get_random_spawn_position"):
		arena_scene = current_scene
	else:
		var found_arena = _get_arena_scene()
		if found_arena and found_arena.has_method("get_random_spawn_position"):
			arena_scene = found_arena

	if arena_scene:
		spawn_pos = arena_scene.get_random_spawn_position()
		# Check if arena returned zero position (no zones in range)
		if spawn_pos == Vector2.ZERO:
			return

		# SPATIAL RESTRICTION: Don't spawn regular enemies inside active breach circles
		if _is_position_inside_any_breach(spawn_pos):
			spawn_pos = _get_alternative_spawn_position(arena_scene, spawn_pos)
			if spawn_pos == Vector2.ZERO:
				Logger.debug("No valid spawn position outside breach circles, skipping regular spawn", "arena")
				return

		Logger.debug("Using arena zone-based spawn position: %s from %s" % [spawn_pos, arena_scene.name], "arena")
	elif arena_system and arena_system.has_method("get_random_spawn_position"):
		spawn_pos = arena_system.get_random_spawn_position()

		# SPATIAL RESTRICTION: Check for breach overlap
		if _is_position_inside_any_breach(spawn_pos):
			Logger.debug("Arena spawn position inside breach, skipping regular spawn", "arena")
			return

		Logger.debug("Using ArenaSystem spawn position: %s" % spawn_pos, "arena")
	else:
		# Fallback to legacy radius-based spawning
		var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
		var angle := RNG.randf_range("waves", 0.0, TAU)
		var effective_spawn_radius: float = arena_system.get_spawn_radius() if arena_system else spawn_radius
		spawn_pos = target_pos + Vector2.from_angle(angle) * effective_spawn_radius

		# SPATIAL RESTRICTION: Check fallback position too
		if _is_position_inside_any_breach(spawn_pos):
			Logger.debug("Fallback spawn position inside breach, skipping regular spawn", "arena")
			return

		Logger.debug("Using fallback radius-based spawn position: %s" % spawn_pos, "arena")
	
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

func _spawn_from_config_v2(enemy_type: EnemyType, spawn_config: SpawnConfig) -> void:
	# DECISION: Switch to scene-based enemies only - no more MultiMesh pooled enemies
	# All enemies (boss, elite, regular, swarm) now use existing boss scene spawning logic
	_spawn_boss_scene(spawn_config)

# Scene-based spawning for all enemy types (bosses and regular enemies)
func _spawn_boss_scene(spawn_config: SpawnConfig) -> void:
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
		return

	# Instantiate enemy scene
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		Logger.warn("Failed to instantiate enemy scene", "waves")
		return

	# Setup enemy with spawn config
	if enemy_instance.has_method("setup_from_spawn_config"):
		enemy_instance.spawn_config = spawn_config
		enemy_instance.setup_from_spawn_config(spawn_config)

	# Apply modulation if specified (for all enemies, not just breach)
	if spawn_config.modulate != Color.WHITE:
		enemy_instance.modulate = spawn_config.modulate

	# Apply event-specific properties based on strategy
	if spawn_config.event_id and spawn_config.event_id.begins_with("breach_"):
		enemy_instance.set_meta("breach_spawned", true)
	
	# Add to ArenaRoot for proper scene ownership
	var arena_root = _get_arena_root()
	arena_root.add_child(enemy_instance)
	
	# Add to groups for proper cleanup
	enemy_instance.add_to_group("arena_owned")
	enemy_instance.add_to_group("enemies")

	# Register with boss hit feedback system (only for actual bosses)
	if spawn_config.render_tier == "boss" and boss_hit_feedback:
		boss_hit_feedback.register_boss(enemy_instance)
		Logger.debug("Boss registered with hit feedback system", "waves")


# HYBRID SPAWNING SYSTEM: Core routing logic
func _spawn_from_type(enemy_type: EnemyType, position: Vector2) -> void:
	if enemy_type.is_special_boss and enemy_type.boss_scene:
		_spawn_special_boss(enemy_type, position)
	else:
		_spawn_pooled_enemy(enemy_type, position)  # Current system unchanged

func _spawn_special_boss(enemy_type: EnemyType, position: Vector2) -> void:
	var boss_node = enemy_type.boss_scene.instantiate()
	var arena_root = _get_arena_root()
	arena_root.add_child(boss_node)
	boss_node.global_position = position
	
	# Add to groups for proper cleanup
	boss_node.add_to_group("arena_owned")
	boss_node.add_to_group("enemies")
	
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
	
	Logger.info("Spawned special boss: " + enemy_type.id + " at " + str(position) + " registered as " + entity_id, "waves")

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

	for i in range(active_events.size()):
		var event_data = active_events[i]
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
	for i in range(completed_events.size() - 1, -1, -1):
		var event_index = completed_events[i]
		active_events.remove_at(event_index)
