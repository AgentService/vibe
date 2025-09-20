extends Node
class_name BreachEventHandler

## Handles all breach event logic: touch activation, circle expansion, enemy spawning
## Separated from SpawnDirector for cleaner architecture and easier maintenance
## Future event types (ritual, pack_hunt, boss) will have similar handler files

signal breach_activated(breach_event: EventInstance)
signal breach_completed(breach_event: EventInstance, performance_data: Dictionary)

# State management
var pending_breach_events: Array[EventInstance] = []
var active_breach_events: Array[EventInstance] = []

# Dependencies
var spawn_director: SpawnDirector
var mastery_system
var breach_config: BreachEventConfig

func initialize(director: SpawnDirector, mastery: EventMasterySystemImpl) -> void:
	"""Initialize with required dependencies"""
	spawn_director = director
	mastery_system = mastery

	# Load breach configuration
	breach_config = load("res://data/balance/breach_event_config.tres") as BreachEventConfig
	if not breach_config or not breach_config.validate():
		Logger.warn("Failed to load valid breach config, using defaults", "events")
		breach_config = BreachEventConfig.new()  # Create with defaults

	Logger.info("BreachEventHandler initialized with config", "events")

func update(dt: float) -> void:
	"""Main update loop called by SpawnDirector"""

	# Create pending breaches if needed
	_handle_breach_creation()

	# Check for player activation
	_check_breach_activation()

	# Update active breach lifecycles
	_update_active_breaches(dt)

	# Handle enemy spawning during expansion
	_handle_breach_enemy_spawning(dt)

	# Handle enemy cleanup during shrinking
	_handle_breach_enemy_cleanup()

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
		if spawn_director._is_zone_available(zone_area.name) and _is_zone_far_from_existing_breaches(zone_area):
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

	# Add to cleanup groups
	breach_indicator.add_to_group("arena_owned")
	breach_indicator.add_to_group("breach_indicators")

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

	# Add to cleanup groups
	breach_indicator.add_to_group("arena_owned")
	breach_indicator.add_to_group("breach_indicators")

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

			# Move from pending to active
			pending_breach_events.remove_at(i)
			active_breach_events.append(breach_event)

			# Set zone cooldown via SpawnDirector
			spawn_director._set_zone_cooldown(breach_event.zone.name)

			# Apply mastery modifiers (placeholder for now)
			_apply_breach_modifiers(breach_event)

			# Emit signals
			breach_activated.emit(breach_event)
			EventBus.event_started.emit("breach", breach_event.zone)

			Logger.info("Breach activated by player at %s" % breach_event.center_position, "events")

func _update_active_breaches(dt: float) -> void:
	"""Update lifecycle for all active breach events"""
	for breach_event in active_breach_events:
		breach_event.update_lifecycle(dt)

func _handle_breach_enemy_spawning(dt: float) -> void:
	"""Spawn enemies during breach expansion phases"""
	for breach_event in active_breach_events:
		if breach_event.should_spawn_enemies():
			_spawn_breach_enemies(breach_event)
			breach_event.reset_spawn_timer()

func _spawn_breach_enemies(breach_event: EventInstance) -> void:
	"""Spawn enemies at the edge of expanding breach circle"""
	var enemy_count = breach_config.enemies_per_spawn if breach_config else 2

	for i in enemy_count:
		# Spawn at circle perimeter
		var angle = randf() * TAU
		var spawn_distance_factor = breach_config.spawn_distance_factor if breach_config else 0.9
		var spawn_distance = breach_event.current_radius * spawn_distance_factor
		var spawn_pos = breach_event.center_position + Vector2.from_angle(angle) * spawn_distance

		# Use SpawnDirector's enemy spawning system
		_spawn_breach_enemy_at_position(spawn_pos, breach_event)

func _spawn_breach_enemy_at_position(position: Vector2, breach_event: EventInstance) -> void:
	"""Spawn a single breach enemy using existing Enemy V2 system"""
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")

	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = spawn_director.get_alive_enemies().size()

	# Spawn appropriate enemies for breach events
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": spawn_director.current_wave_level,
		"spawn_index": local_spawn_counter,
		"position": position,
		"context_tags": ["event", "breach", "bypass_zone_checks"],  # Mark as breach event spawn with zone bypass
		"spawn_type": "breach",  # Additional metadata
		"event_type": "breach",   # Event-specific context
		"force_spawn": true      # Bypass all proximity and zone validation
	}

	# Use weighted enemy selection for breach events
	var cfg: SpawnConfig = EnemyFactoryScript.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("Breach spawning: Failed to generate enemy config", "events")
		return

	# Apply purple modulation for breach enemies
	cfg.modulate = breach_config.enemy_modulate if breach_config else Color(0.8, 0.3, 1.0, 0.9)

	# Convert to legacy EnemyType for existing system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()

	# Use SpawnDirector's spawn system with zone bypass
	spawn_director._spawn_from_config_v2(legacy_enemy_type, cfg)

	# Track enemy with breach event
	var entity_id = "enemy_" + str(local_spawn_counter)  # This will match the actual entity ID
	breach_event.add_spawned_enemy(entity_id)

	Logger.debug("Breach enemy spawned at %s for breach at %s" % [position, breach_event.center_position], "events")

func _handle_breach_enemy_cleanup() -> void:
	"""Delete enemies outside shrinking breach circles"""
	for breach_event in active_breach_events:
		if breach_event.phase == EventInstance.Phase.SHRINKING:
			_cleanup_enemies_outside_breach(breach_event)

func _cleanup_enemies_outside_breach(breach_event: EventInstance) -> void:
	"""Delete enemies outside the shrinking breach circle"""
	var enemies_to_delete = []

	# Check scene-based enemies (new system)
	var arena_root = spawn_director._get_arena_root()
	if arena_root:
		for child in arena_root.get_children():
			if child.is_in_group("enemies"):
				var enemy_pos = child.global_position
				if not breach_event.is_enemy_inside_circle(enemy_pos):
					# Check if this is a breach-spawned enemy
					if child.has_meta("breach_spawned") and child.get_meta("breach_spawned"):
						enemies_to_delete.append(child)

	# Delete enemies with purple dissolve effect
	for enemy_node in enemies_to_delete:
		_delete_breach_enemy_with_effect(enemy_node)

func _delete_breach_enemy_with_effect(enemy_node: Node2D) -> void:
	"""Delete breach enemy with purple dissolve effect (no XP)"""
	# Apply purple dissolve effect
	if enemy_node.has_method("modulate"):
		# Fade to purple then disappear
		var tween = enemy_node.create_tween()
		tween.tween_property(enemy_node, "modulate", Color(0.8, 0.0, 1.0, 0.0), 0.5)
		tween.tween_callback(enemy_node.queue_free)
	else:
		enemy_node.queue_free()

	# Unregister from EntityTracker if it has an entity ID
	if enemy_node.has_meta("entity_id"):
		EntityTracker.unregister_entity(enemy_node.get_meta("entity_id"))

	Logger.debug("Breach cleanup: Enemy dissolved by shrinking circle (no XP)", "events")

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

			# Clean up visual indicator
			_cleanup_breach_visual_indicator(breach_event)

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
	Logger.info("All breach events cleared", "events")
