extends Node
class_name BreachEventHandler

## Handles all breach event logic: touch activation, circle expansion, enemy spawning
## Separated from SpawnDirector for cleaner architecture and easier maintenance
## Future event types (ritual, pack_hunt, boss) will have similar handler files

# Import the BreachEnemyTracker for zero-allocation enemy management
const BreachEnemyTracker = preload("res://scripts/systems/events/BreachEnemyTracker.gd")

signal breach_activated(breach_event: EventInstance)
signal breach_completed(breach_event: EventInstance, performance_data: Dictionary)

# State management
var pending_breach_events: Array[EventInstance] = []
var active_breach_events: Array[EventInstance] = []

# Performance optimization: Zero-allocation breach enemy tracking
var breach_trackers: Dictionary[String, BreachEnemyTracker] = {}  # breach_id -> BreachEnemyTracker

# Dependencies
var spawn_director: SpawnDirector
var mastery_system
var breach_config: BreachEventConfig

func initialize(director: SpawnDirector, mastery: EventMasterySystemImpl) -> void:
	"""Initialize with required dependencies"""
	assert(director != null, "SpawnDirector required for BreachEventHandler")
	assert(mastery != null, "Mastery system required for BreachEventHandler")
	
	spawn_director = director
	mastery_system = mastery

	# Load breach configuration (force reload for hot-reload support)
	breach_config = ResourceLoader.load("res://data/balance/breach_event_config.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BreachEventConfig
	if not breach_config or not breach_config.validate():
		Logger.warn("Failed to load valid breach config, using defaults", "events")
		breach_config = BreachEventConfig.new()  # Create with defaults

	# Initialize breach tracking system
	_initialize_breach_trackers()

	# Connect to 30Hz fixed-step combat updates for performance optimization
	EventBus.combat_step.connect(_on_combat_step)

	Logger.info("BreachEventHandler initialized with config and 30Hz combat step", "events")

func reset() -> void:
	"""Reset breach event state for session resets - clears all pending and active breaches"""
	Logger.info("BreachEventHandler: Resetting state for session reset", "events")

	# Clear all breach event state
	pending_breach_events.clear()
	active_breach_events.clear()
	breach_trackers.clear()

	Logger.debug("BreachEventHandler: Reset complete - all breach state cleared", "events")

func _ready() -> void:
	"""Register BreachEventHandler for monitoring detection"""
	add_to_group("breach_handlers")
	Logger.debug("BreachEventHandler added to 'breach_handlers' group", "events")

func update(dt: float) -> void:
	"""Main update loop called by SpawnDirector"""

	# Create pending breaches if needed
	_handle_breach_creation()

	# Check for player activation
	_check_breach_activation()

	# Update active breach lifecycles
	_update_active_breaches(dt)

	# Clean up completed breaches
	_cleanup_completed_breaches()

func _handle_breach_creation() -> void:
	"""Create pending breach events in available spawn zones"""

	# Only create new breaches if we have fewer than max allowed
	var max_breaches = breach_config.max_simultaneous_breaches if breach_config else 3
	if pending_breach_events.size() >= max_breaches:
		return

	var arena_scene = spawn_director._get_arena_scene()
	if not arena_scene or not "_spawn_zone_areas" in arena_scene:
		return

	var available_zones = []
	for zone_area in arena_scene._spawn_zone_areas:
		# CHANGED: Only check distance, ignore zone cooldowns for breach independence
		if _is_zone_far_from_existing_breaches(zone_area):
			available_zones.append(zone_area)

	# Create breach events in available zones
	var needed_breaches = max_breaches - pending_breach_events.size()
	for i in range(min(needed_breaches, available_zones.size())):
		var zone = available_zones[i]
		var breach_event = EventInstance.new(zone, breach_config)
		pending_breach_events.append(breach_event)

		# Create visual indicator scene for this breach
		_create_breach_visual_indicator(breach_event)

		Logger.debug("Created pending breach at zone %s" % zone.name, "events")

func _is_zone_far_from_existing_breaches(zone_area) -> bool:
	"""Check if zone is far enough from existing breaches to prevent overlap"""
	var min_distance = breach_config.min_breach_distance if breach_config else 200.0

	var zone_center = _get_zone_center(zone_area)

	# Check against all existing breach events
	var all_breaches = pending_breach_events + active_breach_events
	for existing_breach in all_breaches:
		var distance = zone_center.distance_to(existing_breach.center_position)
		if distance < min_distance:
			return false

	return true

func _is_position_in_zone(position: Vector2, zone_area: Area2D) -> bool:
	"""Check if a position is within the given spawn zone"""
	if not zone_area:
		return false

	# Check if zone has collision shapes to determine bounds
	var shape_owners = zone_area.get_shape_owners()
	if shape_owners.size() > 0:
		var owner_id = shape_owners[0]
		var shape = zone_area.shape_owner_get_shape(owner_id, 0)

		if shape is RectangleShape2D:
			var rect_shape = shape as RectangleShape2D
			var half_size = rect_shape.size / 2
			var local_pos = position - zone_area.global_position
			return abs(local_pos.x) <= half_size.x and abs(local_pos.y) <= half_size.y
		elif shape is CircleShape2D:
			var circle_shape = shape as CircleShape2D
			var distance = position.distance_to(zone_area.global_position)
			return distance <= circle_shape.radius

	# Fallback: always return true if we can't determine zone bounds
	return true

func _find_valid_position_near_ring(breach_event: EventInstance, sector: int, ring_radius: float) -> Vector2:
	"""Find a valid spawn position near the ring within the zone"""
	var sector_angle = (TAU / breach_event.total_sectors) * sector
	var attempts = 8  # Try multiple positions in the sector

	for attempt in range(attempts):
		# Vary both angle and distance to find a valid position
		var angle_variation = randf_range(-PI / breach_event.total_sectors * 0.7, PI / breach_event.total_sectors * 0.7)
		var distance_variation = randf_range(0.6, 1.1)  # Allow more distance variation for validation
		var angle = sector_angle + angle_variation
		var distance = ring_radius * distance_variation

		var test_pos = breach_event.center_position + Vector2.from_angle(angle) * distance

		if _is_position_in_zone(test_pos, breach_event.zone):
			return test_pos

	# No valid position found
	return Vector2.ZERO

func _get_zone_center(zone_area: Area2D) -> Vector2:
	"""Get the center position of a zone area"""
	# Check if zone has collision shapes to determine center
	var shape_owners = zone_area.get_shape_owners()
	if shape_owners.size() > 0:
		var owner_id = shape_owners[0]
		var shape = zone_area.shape_owner_get_shape(owner_id, 0)

		if shape is RectangleShape2D:
			# For rectangles, center is at zone position (assuming it's already centered)
			return zone_area.global_position
		elif shape is CircleShape2D:
			# For circles, center is at zone position
			return zone_area.global_position

	# Fallback to zone position
	return zone_area.global_position

func _create_breach_visual_indicator(breach_event: EventInstance) -> void:
	"""Create scene-based visual indicator for breach event (editor-friendly)"""

	# Load breach indicator scene
	var breach_scene_path = "res://scenes/events/BreachIndicator.tscn"
	if not ResourceLoader.exists(breach_scene_path):
		# Fallback: create simple programmatic indicator for now
		_create_simple_breach_indicator(breach_event)
		return

	var breach_scene = load(breach_scene_path)
	var breach_indicator = breach_scene.instantiate()

	# Add to arena for proper scene ownership FIRST
	var arena_root = spawn_director._get_arena_root()
	arena_root.add_child(breach_indicator)

	# Now set position after it's in the tree
	breach_indicator.global_position = breach_event.center_position

	# Set up breach indicator with event data
	if breach_indicator.has_method("setup_breach"):
		breach_indicator.setup_breach(breach_event)

	# Add to semantic groups - breaches persist across enemy clears
	ClearingSemantics.add_semantic_group(breach_indicator, ClearingSemantics.PERSIST_ACROSS_ENEMY_CLEARS)
	breach_indicator.add_to_group("breach_indicators")  # Functional group for breach system

	Logger.debug("Created scene-based breach indicator for %s" % breach_event.zone.name, "events")

func _create_simple_breach_indicator(breach_event: EventInstance) -> void:
	"""Fallback: create programmatic breach indicator if scene is missing"""
	var breach_indicator = BreachIndicator.new()

	# Add to arena for proper scene ownership FIRST
	var arena_root = spawn_director._get_arena_root()
	arena_root.add_child(breach_indicator)

	# Now set position after it's in the tree
	breach_indicator.global_position = breach_event.center_position

	# Set up breach indicator with event data
	if breach_indicator.has_method("setup_breach"):
		breach_indicator.setup_breach(breach_event)

	# Add to semantic groups - breaches persist across enemy clears
	ClearingSemantics.add_semantic_group(breach_indicator, ClearingSemantics.PERSIST_ACROSS_ENEMY_CLEARS)
	breach_indicator.add_to_group("breach_indicators")  # Functional group for breach system

	Logger.debug("Created programmatic breach indicator (fallback) for %s" % breach_event.zone.name, "events")

func _check_breach_activation() -> void:
	"""Check if player touches any pending breach circles"""
	var player_pos = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		return

	# Check each pending breach for player contact
	for i in range(pending_breach_events.size() - 1, -1, -1):
		var breach_event = pending_breach_events[i]

		if breach_event.is_player_in_touch_range(player_pos):
			# Activate the breach
			breach_event.activate()

			# DYNAMIC RING SPAWNING: Initialize sector tracking for even distribution
			_initialize_breach_sectors(breach_event)

			# Move from pending to active
			pending_breach_events.remove_at(i)
			active_breach_events.append(breach_event)

			# Zone cooldowns disabled for multi-breach independence
			# Old spawn strategy system replaced with dynamic ring spawning

			# Apply mastery modifiers (placeholder for now)
			_apply_breach_modifiers(breach_event)

			# Emit signals
			breach_activated.emit(breach_event)
			EventBus.event_started.emit("breach", breach_event.zone)

			Logger.info("Breach activated by player at %s (dynamic ring spawning enabled)" % [
				breach_event.center_position
			], "events")

func _initialize_breach_sectors(breach_event: EventInstance) -> void:
	"""Initialize sector tracking for dynamic ring spawning"""
	# Clear any existing sector counts
	breach_event.sector_enemy_counts.clear()
	breach_event.last_ring_spawn_radius = 0.0

	# Load configuration from breach config
	if breach_config:
		breach_event.ring_spawn_threshold = breach_config.ring_spawn_interval
		breach_event.total_sectors = breach_config.sector_count

	Logger.info("Initialized dynamic ring spawning for breach %s (threshold: %.1f, sectors: %d)" % [
		breach_event.breach_id, breach_event.ring_spawn_threshold, breach_event.total_sectors
	], "events")

func _calculate_ring_enemy_count(radius: float) -> int:
	"""Calculate how many enemies to spawn in a ring based on circumference"""
	if breach_config:
		return breach_config.get_ring_enemy_count(radius)
	else:
		# Fallback calculation if no config
		var circumference = 2 * PI * radius
		var edge_factor = 0.87  # Default edge spawn factor
		var density = 0.033     # Default density
		var actual_circumference = circumference * edge_factor
		var enemy_count = max(3, int(actual_circumference * density))
		Logger.debug("Ring at radius %.1f: circumference %.1f, enemies %d (fallback)" % [radius, circumference, enemy_count], "events")
		return enemy_count

func _spawn_edge_ring(breach_event: EventInstance) -> void:
	"""Spawn a ring of enemies at configured edge factor of current breach radius"""
	var edge_factor = breach_config.edge_spawn_factor if breach_config else 0.87
	var ring_radius = breach_event.current_radius * edge_factor
	var enemy_count = _calculate_ring_enemy_count(breach_event.current_radius)

	# Get emptiest sectors for spawn prioritization
	var target_sectors = breach_event.get_emptiest_sectors(enemy_count)
	var spawned_count = 0

	# PERFORMANCE: Disabled debug logging during ring spawn (called frequently during expansion)
	# Logger.debug("Spawning ring at radius %.1f with %d enemies in sectors %s" % [
	# 	ring_radius, enemy_count, target_sectors
	# ], "events")

	for i in range(enemy_count):
		# Use sector prioritization
		var target_sector = target_sectors[i % target_sectors.size()]
		var sector_angle = (TAU / breach_event.total_sectors) * target_sector

		# Add variation within sector
		var angle_variation = randf_range(-PI / breach_event.total_sectors * 0.5, PI / breach_event.total_sectors * 0.5)
		var angle = sector_angle + angle_variation

		# Add slight distance variation (±3%)
		var distance = ring_radius * randf_range(0.97, 1.03)

		var spawn_pos = breach_event.center_position + Vector2.from_angle(angle) * distance

		# Validate spawn position is within the breach's spawn zone
		if not _is_position_in_zone(spawn_pos, breach_event.zone):
			# Try to find a valid position near the ring
			spawn_pos = _find_valid_position_near_ring(breach_event, target_sector, ring_radius)
			if spawn_pos == Vector2.ZERO:  # No valid position found
				continue

		var enemy_node = _spawn_breach_enemy_at_position(spawn_pos, breach_event)

		if enemy_node:
			# Track in sector
			breach_event.increment_sector_count(target_sector)
			breach_event.add_spawned_enemy("enemy_" + str(enemy_node.get_instance_id()))

			# Track in revealed_enemies for shrinking cleanup
			var position_key = _get_position_key(spawn_pos)
			breach_event.revealed_enemies[position_key] = enemy_node

			spawned_count += 1

	# Mark that we've spawned this ring
	breach_event.mark_ring_spawned()

	Logger.info("Spawned ring: %d enemies at radius %.1f for breach %s" % [
		spawned_count, ring_radius, breach_event.breach_id
	], "events")

# NOTE: _find_enemy_at_position() removed - no longer needed with direct node references

func _update_active_breaches(dt: float) -> void:
	"""Update lifecycle for all active breach events"""
	for breach_event in active_breach_events:
		breach_event.update_lifecycle(dt)

		# Handle dynamic ring spawning during expansion
		if breach_event.phase == EventInstance.Phase.EXPANDING and breach_event.should_spawn_new_ring():
			_spawn_edge_ring(breach_event)

		# Handle enemy cleanup during shrinking - only when circle touches spawn rings
		elif breach_event.phase == EventInstance.Phase.SHRINKING:
			_check_and_cleanup_touched_rings(breach_event)


func _check_and_cleanup_touched_rings(breach_event: EventInstance) -> void:
	"""Legacy function - now redirects to optimized zero-allocation cleanup"""
	_cleanup_breach_enemies_optimized(breach_event)

func _get_position_key(position: Vector2) -> String:
	"""Generate a unique key for a position (for tracking revealed enemies)"""
	return "pos_" + str(int(position.x)) + "_" + str(int(position.y))

func _spawn_breach_enemy_at_position(position: Vector2, breach_event: EventInstance) -> Node2D:
	"""Spawn a single breach enemy at specified position with breach ownership"""
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")

	# PERFORMANCE: Use breach-local counter instead of expensive get_alive_enemies() call
	# The spawn index is only used for RNG seeding, so local incrementing is sufficient
	var local_spawn_counter: int = breach_event.spawned_enemies.size()

	# Spawn appropriate enemies for breach events
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": spawn_director.current_wave_level,
		"spawn_index": local_spawn_counter,
		"position": position,
		"context_tags": ["event", "breach", "ring_spawn"],
		"spawn_type": "breach_ring",
		"event_type": "breach"
	}

	# Use weighted enemy selection for breach events
	var cfg: SpawnConfig = EnemyFactoryScript.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("Ring spawning: Failed to generate enemy config", "events")
		return null

	# Apply breach purple modulation
	cfg.modulate = breach_config.enemy_modulate if breach_config else Color(0.8, 0.3, 1.0, 0.9)

	# Link to breach strategy for position/validation
	cfg.event_id = breach_event.strategy_id if breach_event.strategy_id else ""

	# Convert to legacy EnemyType for existing system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()

	# Get direct node reference from SpawnDirector (eliminates race condition)
	var enemy_node = spawn_director._spawn_from_config_v2(legacy_enemy_type, cfg)

	if enemy_node:
		# IMMEDIATE and RELIABLE tagging (100% success rate)
		enemy_node.set_meta("breach_owner", breach_event.breach_id)
		enemy_node.set_meta("breach_spawned", true)
		enemy_node.add_to_group("breach_enemies")

		# Performance optimization: Add enemy to zero-allocation RingBuffer tracker
		_add_enemy_to_breach(enemy_node, breach_event.breach_id)

		# Track in breach event for extra safety
		var pos_key = _get_position_key(position)
		breach_event.revealed_enemies[pos_key] = enemy_node

	else:
		Logger.warn("Failed to spawn breach enemy at %s for breach %s" % [position, breach_event.breach_id], "events")

	return enemy_node

func _is_enemy_owned_by_breach(enemy_node: Node2D, breach_id: String) -> bool:
	"""Check if enemy is owned by specific breach (prevents cross-breach interference)"""
	if not enemy_node.has_meta("breach_owner"):
		return false
	return enemy_node.get_meta("breach_owner") == breach_id

func _delete_breach_enemy_with_effect(enemy_node: Node2D) -> void:
	"""Delete breach enemy instantly - direct removal without XP/loot rewards"""

	# Get entity ID for proper cleanup through damage system
	if not enemy_node.has_meta("entity_id"):
		# Fallback: direct cleanup if no entity_id (shouldn't happen)
		enemy_node.queue_free()
		Logger.warn("Breach cleanup: Enemy missing entity_id, direct cleanup used", "events")
		return

	var entity_id: String = enemy_node.get_meta("entity_id")

	# PERFORMANCE: Direct instant removal without damage calculation overhead
	# This skips the entire damage pipeline (crit checks, modifiers, etc.)

	# TODO: Add breach-specific death effect here when visual polish phase begins:
	# - Option 1: Instant purple flash (modulate then queue_free)
	# - Option 2: Spawn lightweight particle effect (pre-pooled GPUParticles2D)
	# - Option 3: Use shader dissolve effect (most performant for 100+ enemies)
	# Example: enemy_node.modulate = Color(0.8, 0.0, 1.0, 0.5)  # Purple tint

	# Unregister from damage system (marks as dead, triggers cleanup)
	DamageService.unregister_entity(entity_id)

	# Direct scene cleanup (instant, no tween delay)
	enemy_node.queue_free()

	Logger.debug("Breach cleanup: Enemy dissolved by shrinking circle (no XP/loot)", "events")

func _cleanup_completed_breaches() -> void:
	"""Remove completed breach events and award mastery points"""
	for i in range(active_breach_events.size() - 1, -1, -1):
		var breach_event = active_breach_events[i]

		if breach_event.phase == EventInstance.Phase.COMPLETED:
			# Award mastery point
			var performance_data = {
				"duration": breach_event.get_total_duration(),
				"enemies_spawned": breach_event.spawned_enemies.size(),
				"zone": breach_event.zone.name,
				"completion_time": Time.get_time_dict_from_system()
			}

			# Emit signals
			breach_completed.emit(breach_event, performance_data)
			EventBus.event_completed.emit("breach", performance_data)

			# Old spawn strategy system removed - phantom positions used instead

			# Note: Breach enemies are cleaned up during shrinking phase

			# Clean up visual indicator
			_cleanup_breach_visual_indicator(breach_event)

			# Performance optimization: Clean up breach tracker for this breach
			if breach_trackers.has(breach_event.breach_id):
				var tracker = breach_trackers[breach_event.breach_id]
				tracker.clear()
				breach_trackers.erase(breach_event.breach_id)
				Logger.debug("Cleaned up breach tracker for breach %s" % breach_event.breach_id, "events")

			# Remove from active list
			active_breach_events.remove_at(i)

			Logger.info("Breach completed: %d enemies spawned at %s" % [
				breach_event.spawned_enemies.size(), breach_event.zone.name
			], "events")


func _cleanup_breach_visual_indicator(breach_event: EventInstance) -> void:
	"""Clean up scene-based visual indicator"""
	# Find and remove breach indicator nodes
	var arena_root = spawn_director._get_arena_root()
	for child in arena_root.get_children():
		if child.is_in_group("breach_indicators"):
			# Check if this indicator belongs to our breach (by position or other identifier)
			if child.global_position.distance_to(breach_event.center_position) < 10.0:
				child.queue_free()
				Logger.debug("Cleaned up breach indicator for %s" % breach_event.zone.name, "events")

func _apply_breach_modifiers(breach_event: EventInstance) -> void:
	"""Apply mastery passive modifiers to breach event (placeholder)"""
	if not mastery_system:
		return

	# Get breach event definition
	var event_def = mastery_system.get_event_definition("breach")
	if not event_def:
		Logger.debug("No breach event definition found (placeholder mode)", "events")
		return

	# Apply modifiers (placeholder - just log for now)
	var modified_config = mastery_system.apply_event_modifiers(event_def)

	# TODO: Apply actual modifiers to breach_event
	# - Duration modifiers: breach_event.expand_duration *= modifier
	# - Size modifiers: breach_event.max_radius *= modifier
	# - Spawn rate modifiers: breach_event.spawn_interval *= modifier

	Logger.debug("Applied breach modifiers (placeholder): %s" % modified_config, "events")

func get_active_breach_count() -> int:
	"""Get number of currently active breaches"""
	return active_breach_events.size()

func get_pending_breach_count() -> int:
	"""Get number of pending breaches waiting for activation"""
	return pending_breach_events.size()

func clear_all_breaches() -> void:
	"""Clear all breach events (for scene transitions)"""
	pending_breach_events.clear()
	active_breach_events.clear()
	
	# Performance optimization: Clear breach trackers
	_clear_all_breach_trackers()

	Logger.info("All breach events cleared", "events")

## ZERO-ALLOCATION OPTIMIZATION: New functions for RingBuffer-based tracking

func _initialize_breach_trackers() -> void:
	"""Initialize breach tracking system - call during setup"""
	breach_trackers.clear()
	Logger.debug("Breach tracker system initialized", "events")

func _on_combat_step(payload) -> void:
	"""30Hz fixed-step update handler for deterministic performance"""
	if not payload:
		return

	var delta_time = payload.dt  # Fixed 1/30 = 0.0333... seconds

	# Create pending breaches if needed
	_handle_breach_creation()

	# Check for player activation
	_check_breach_activation()

	# Update active breach lifecycles at fixed 30Hz
	_update_active_breaches_optimized(delta_time)

	# Clean up completed breaches
	_cleanup_completed_breaches()

func _update_active_breaches_optimized(dt: float) -> void:
	"""Optimized breach lifecycle updates using 30Hz fixed-step timing"""
	for breach_event in active_breach_events:
		breach_event.update_lifecycle(dt)

		# Handle dynamic ring spawning during expansion
		if breach_event.phase == EventInstance.Phase.EXPANDING and breach_event.should_spawn_new_ring():
			_spawn_edge_ring(breach_event)

		# Handle enemy cleanup during shrinking - use zero-allocation strategy
		elif breach_event.phase == EventInstance.Phase.SHRINKING:
			_cleanup_breach_enemies_optimized(breach_event)

func _add_enemy_to_breach(enemy: Node2D, breach_id: String) -> bool:
	"""Add enemy to breach using RingBuffer tracker"""
	if not enemy or not is_instance_valid(enemy):
		Logger.warn("BreachEventHandler: Attempted to add invalid enemy to breach %s" % breach_id, "events")
		return false

	# Ensure tracker exists for this breach
	if not breach_trackers.has(breach_id):
		var tracker = BreachEnemyTracker.new()
		tracker.setup(256)  # 256-enemy capacity per breach
		breach_trackers[breach_id] = tracker
		Logger.debug("Created new breach tracker for %s with 256 capacity" % breach_id, "events")

	var tracker = breach_trackers[breach_id]
	var success = tracker.add_enemy(enemy)

	if not success:
		_handle_capacity_overflow(breach_id)

	return success

func _cleanup_breach_enemies_optimized(breach_event: EventInstance) -> void:
	"""Zero-allocation enemy cleanup with spatial partitioning optimization"""
	if not breach_trackers.has(breach_event.breach_id):
		return  # No tracker for this breach

	var tracker = breach_trackers[breach_event.breach_id]
	var cleanup_count = 0

	# OPTIMIZATION: Spatial partitioning to skip enemies safely inside
	const SAFE_ZONE_MARGIN := 100.0  # Only skip enemies more than 100px inside border
	var min_safe_distance := breach_event.current_radius - SAFE_ZONE_MARGIN

	# Mark enemies outside shrinking radius for removal (zero allocations)
	var valid_enemies = tracker.iterate_valid_enemies()
	for enemy in valid_enemies:
		if not is_instance_valid(enemy):
			tracker.mark_for_removal(enemy)
			cleanup_count += 1
			continue

		# Calculate distance once
		var distance: float = enemy.global_position.distance_to(breach_event.center_position)

		# OPTIMIZATION: Skip enemies deep inside safe zone (major performance win)
		# Note: Enemies outside radius will ALWAYS be checked (no upper bound skip)
		if distance < min_safe_distance:
			continue  # Enemy is safely inside, no need to check

		# Mark enemy for removal if outside current radius (touched by shrinking border)
		if distance > breach_event.current_radius:
			_delete_breach_enemy_with_effect(enemy)
			tracker.mark_for_removal(enemy)
			cleanup_count += 1
			# PERFORMANCE: Only log first few enemies to avoid string formatting spam
			if cleanup_count <= 3 and Logger.is_debug():
				Logger.debug("MARKED enemy for removal - touched by shrinking border at distance %.1f (radius: %.1f)" % [
					distance, breach_event.current_radius
				], "events")

	# Batch cleanup marked enemies during safe phase
	if cleanup_count > 0:
		tracker.cleanup_marked()
		Logger.info("SHRINK: Removed %d breach enemies touched by border for breach %s" % [
			cleanup_count, breach_event.breach_id
		], "events")

func _handle_capacity_overflow(breach_id: String) -> void:
	"""Handle capacity overflow - log warning and continue gracefully"""
	Logger.warn("BreachEventHandler: Breach %s exceeded 256-enemy capacity limit" % breach_id, "events")

	# Get debug info if tracker exists
	if breach_trackers.has(breach_id):
		var debug_info = breach_trackers[breach_id].get_debug_info()
		Logger.warn("Breach %s tracker state: %s" % [breach_id, debug_info], "events")

func _clear_all_breach_trackers() -> void:
	"""Clear all breach trackers - call during scene transitions"""
	for breach_id in breach_trackers:
		var tracker = breach_trackers[breach_id]
		tracker.clear()

	breach_trackers.clear()
	Logger.debug("All breach trackers cleared", "events")
