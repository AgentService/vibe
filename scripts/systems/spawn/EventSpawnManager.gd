extends Node
class_name EventSpawnManager

## Manages event-based spawning including event zones, timers, and completion tracking.
## Extracted from SpawnDirector as part of the ultra-phased refactoring to reduce complexity.
## Handles mastery modifiers, zone cooldowns, and event formation spawning.

# Dependencies injected by SpawnDirector
var spawn_director: SpawnDirector
var mastery_system

# Event system state
var event_system_enabled: bool = false
var event_timer: float = 0.0
var next_event_delay: float = 45.0
var active_events: Array[Dictionary] = []


func initialize(parent_spawn_director: SpawnDirector, parent_mastery_system) -> void:
	"""Initialize the event spawn manager with dependencies"""
	spawn_director = parent_spawn_director
	mastery_system = parent_mastery_system

	# Enable event system by default
	event_system_enabled = true

	Logger.info("EventSpawnManager initialized", "events")

func update(dt: float) -> void:
	"""Update event spawning logic called from combat step"""
	if not event_system_enabled:
		return

	_handle_event_spawning(dt)


func _handle_event_spawning(dt: float) -> void:
	"""Handle event-based spawning with mastery modifiers."""

	# Update event timer
	event_timer += dt
	if event_timer < next_event_delay:
		return

	# Reset timer
	event_timer = 0.0

	# Get current arena and map config
	var arena_scene = spawn_director._get_arena_scene()
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


	# Spawn the event
	_spawn_event_at_zone(event_def, modified_config, selected_zone)

	Logger.info("Event spawned: %s at zone %s with %d enemies" % [
		event_type, selected_zone.name, modified_config.get("monster_count", 0)
	], "events")

func _get_available_event_zones(player_pos: Vector2, map_config: MapConfig) -> Array[Area2D]:
	"""Get zones available for event spawning with distance and cooldown filtering."""
	var arena_scene = spawn_director._get_arena_scene()
	if not arena_scene or not "_spawn_zone_areas" in arena_scene:
		return []

	var all_scene_zones = arena_scene._spawn_zone_areas
	# Use dedicated event spawn distances (fallback to reasonable defaults)
	var event_spawn_range = 600.0  # Event spawn range
	var event_spawn_min_distance = 200.0  # Event minimum distance from player

	var available_zones: Array[Area2D] = []

	# Filter zones by distance only (zone cooldowns removed)
	for zone_area in all_scene_zones:
		var distance = player_pos.distance_to(zone_area.global_position)

		# Check distance range (prefer off-screen spawning)
		if distance < event_spawn_min_distance or distance > event_spawn_range:
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
	var arena_scene = spawn_director._get_arena_scene()
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
	"""Spawn event enemies in simple circle formation."""

	# Use simple circle formation instead of complex pack formation
	var successful_spawns = 0
	var min_separation = 40.0  # Minimum distance between enemies

	for i in pack_size:
		var spawn_pos: Vector2

		# Simple circle formation
		if pack_size == 1:
			spawn_pos = center_pos
		else:
			var angle = (float(i) / pack_size) * TAU
			var distance = formation_radius * 0.7
			spawn_pos = center_pos + Vector2.from_angle(angle) * distance

		# Add some random jitter to avoid perfect positioning
		var jitter = Vector2(
			RNG.randf_range("events", -min_separation * 0.3, min_separation * 0.3),
			RNG.randf_range("events", -min_separation * 0.3, min_separation * 0.3)
		)
		spawn_pos += jitter

		_spawn_event_enemy(spawn_pos, event_def)
		successful_spawns += 1

	Logger.info("Event formation spawned: %d/%d enemies in circle formation for %s event" % [
		successful_spawns, pack_size, event_def.event_type
	], "events")

func _spawn_event_enemy(position: Vector2, event_def) -> void:
	"""Spawn a single event enemy using Enemy V2 system with event context."""

	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")

	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = spawn_director.get_alive_enemies().size()

	# Create spawn context for EnemyFactory - mark as event spawn
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": spawn_director.current_wave_level,
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

	# Apply event-specific modifiers to config if needed
	cfg.position = position

	# Spawn the enemy using SpawnDirector's infrastructure
	var enemy = spawn_director._spawn_enemy_from_config(cfg)
	if enemy:
		Logger.debug("Event enemy spawned: %s at %s for event %s" % [
			cfg.enemy_type, str(position), event_def.event_type
		], "events")

func check_event_completion(killed_entity_id: String) -> void:
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

			if enemy_index >= 0 and enemy_index < spawn_director.enemies.size():
				var enemy_pos = spawn_director.enemies[enemy_index].pos
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
						"enemies_killed": 1,  # Simple count for now
						"zone": event_data.zone.name
					}

					EventBus.event_completed.emit(event_def.event_type, event_data.zone, performance_data)

					Logger.info("Event completed: %s in zone %s" % [
						event_def.event_type, event_data.zone.name
					], "events")

	# Remove completed events (iterate backwards to maintain indices)
	for i in range(completed_events.size() - 1, -1, -1):
		active_events.remove_at(completed_events[i])
