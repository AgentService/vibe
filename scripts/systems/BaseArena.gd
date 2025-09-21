class_name BaseArena
extends Node2D

## Base class for all arena scenes in the game
## Provides standardized interface for systems like WaveDirector, ArenaSystem, etc.
## Future arena variants (Arena2, CityArena, etc.) should extend this class

# Arena identification and configuration
@export var arena_id: String = "default_arena"
@export var arena_name: String = "Default Arena"

# Spawn configuration - can be overridden in child arenas
@export var spawn_radius: float = 400.0
@export var arena_bounds: float = 500.0

# Arena state tracking
var is_player_dead: bool = false

func _ready() -> void:
	Logger.info("BaseArena initialized: %s (%s)" % [arena_name, arena_id], "arena")

	# Register in arena group for breach monitoring and other systems
	add_to_group("arena")

	# Setup breach performance monitoring based on DebugConfig
	call_deferred("_setup_breach_monitoring")

	# Defer EventBus connection to avoid architecture boundary violation
	call_deferred("_connect_events")

## Explicit arena identification method for systems
func is_arena_scene() -> bool:
	return true

## Handle player death - common logic for all arena types
func _on_player_died() -> void:
	"""Handle player death - set death state and pause arena systems"""
	is_player_dead = true
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	Logger.info("BaseArena: Player died, disabling arena processing", "arena")

## Get spawn radius for this arena (can be overridden)
func get_spawn_radius() -> float:
	return spawn_radius

## Get arena bounds for this arena (can be overridden)
func get_arena_bounds() -> float:
	return arena_bounds

## Get arena center (default implementation, can be overridden)
func get_arena_center() -> Vector2:
	return global_position

## Connect to EventBus (deferred to avoid architecture boundary violation)
func _connect_events() -> void:
	# Connect to player death events for all arena types
	if EventBus.player_died.connect(_on_player_died) != OK:
		Logger.warn("BaseArena: Failed to connect to player_died signal", "arena")

## ============================================================================
## SHARED SPAWN ZONE HELPER METHODS - Used by all arena types
## ============================================================================

## Helper method to generate random position within a zone (config-based)
func generate_position_in_zone(zone_data: Dictionary) -> Vector2:
	var zone_pos = zone_data.get("position", Vector2.ZERO)
	var zone_radius = zone_data.get("radius", 50.0)

	var angle = randf() * TAU
	var distance = randf() * zone_radius
	return zone_pos + Vector2(cos(angle), sin(angle)) * distance

## Helper method to generate random position within a scene Area2D zone
func generate_position_in_scene_zone(zone_area: Area2D) -> Vector2:
	var zone_pos = zone_area.global_position
	var zone_radius = 50.0  # Default radius

	# Try to get radius from CollisionShape2D - support multiple shape types
	if zone_area.get_child_count() > 0:
		var collision_shape = zone_area.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape:
			if collision_shape.shape is CircleShape2D:
				var circle_shape = collision_shape.shape as CircleShape2D
				zone_radius = circle_shape.radius
				Logger.debug("Using CircleShape2D radius: %.1f for zone %s" % [zone_radius, zone_area.name], "arena")
			elif collision_shape.shape is RectangleShape2D:
				var rect_shape = collision_shape.shape as RectangleShape2D
				# Use half the smaller dimension as radius for rectangular zones
				zone_radius = minf(rect_shape.size.x, rect_shape.size.y) * 0.5
				Logger.debug("Using RectangleShape2D radius: %.1f for zone %s" % [zone_radius, zone_area.name], "arena")
			else:
				Logger.debug("Zone %s has unsupported shape type (%s), using default radius %.1f" % [zone_area.name, collision_shape.shape.get_class(), zone_radius], "arena")
		else:
			Logger.debug("Zone %s has no valid collision shape, using default radius %.1f" % [zone_area.name, zone_radius], "arena")

	var angle = randf() * TAU
	var distance = randf() * zone_radius
	return zone_pos + Vector2(cos(angle), sin(angle)) * distance

## Helper method to select random scene zone without proximity filtering
func select_random_scene_zone(spawn_zone_areas: Array[Area2D]) -> Vector2:
	if spawn_zone_areas.is_empty():
		return Vector2.ZERO

	var selected_zone = spawn_zone_areas[randi() % spawn_zone_areas.size()]
	return generate_position_in_scene_zone(selected_zone)

## Helper method to filter scene zones by proximity (legacy - max distance only)
func filter_zones_by_proximity(spawn_zone_areas: Array[Area2D], player_pos: Vector2, proximity_range: float) -> Array[Area2D]:
	return filter_zones_by_distance_range(spawn_zone_areas, player_pos, 0.0, proximity_range)

## Helper method to filter scene zones by distance range (min/max distance)
func filter_zones_by_distance_range(spawn_zone_areas: Array[Area2D], player_pos: Vector2, min_distance: float, max_distance: float) -> Array[Area2D]:
	var zones_in_range: Array[Area2D] = []

	for zone_area in spawn_zone_areas:
		var zone_pos = zone_area.global_position
		var distance = player_pos.distance_to(zone_pos)
		if distance >= min_distance and distance <= max_distance:
			zones_in_range.append(zone_area)

	return zones_in_range

## =============================================================================
## BREACH PERFORMANCE MONITORING (DebugConfig Controlled) - Available in All Arena Types
## =============================================================================

var breach_monitor_timer: Timer

func _setup_breach_monitoring() -> void:
	"""Setup breach performance monitoring based on DebugConfig settings"""
	# Load debug configuration first
	var config_path = "res://config/debug.tres"
	var debug_config: DebugConfig = null

	if ResourceLoader.exists(config_path):
		debug_config = load(config_path) as DebugConfig
	else:
		Logger.warn("DebugConfig file not found at %s" % config_path, "arena")
		return

	if not debug_config:
		Logger.warn("DebugConfig is null", "arena")
		return

	# Check if debug panels are enabled first
	if not debug_config.debug_panels_enabled:
		Logger.debug("Breach monitoring skipped: debug_panels_enabled = false", "arena")
		return

	# Setup monitoring for enabled event types
	var monitors_created = 0

	# Breach monitoring
	if debug_config.enable_breach_monitoring:
		_create_event_monitor("Breach", "res://tests/tools/monitor_breach_performance.gd")
		monitors_created += 1

	# Ritual monitoring (future)
	if debug_config.enable_ritual_monitoring:
		_create_event_monitor("Ritual", "res://tests/tools/monitor_ritual_performance_template.gd")
		monitors_created += 1

	# Pack Hunt monitoring (future)
	if debug_config.enable_packhunt_monitoring:
		_create_event_monitor("PackHunt", "res://tests/tools/monitor_packhunt_performance_template.gd")
		monitors_created += 1

	# Boss monitoring (future)
	if debug_config.enable_boss_monitoring:
		_create_event_monitor("Boss", "res://tests/tools/monitor_boss_performance_template.gd")
		monitors_created += 1

	if monitors_created == 0:
		Logger.debug("No event monitoring enabled in DebugConfig for %s" % arena_name, "arena")
		return

	# Setup periodic monitoring timer for all enabled monitors
	breach_monitor_timer = Timer.new()
	breach_monitor_timer.name = "EventMonitorTimer"
	breach_monitor_timer.wait_time = debug_config.event_monitor_interval
	breach_monitor_timer.autostart = true
	breach_monitor_timer.timeout.connect(_on_event_monitor_timeout)
	add_child(breach_monitor_timer)

	Logger.info("Event performance monitoring enabled for %s (%d monitors, interval: %.1fs)" % [arena_name, monitors_created, debug_config.event_monitor_interval], "arena")

## Helper method to create individual event monitors
func _create_event_monitor(monitor_type: String, script_path: String) -> void:
	"""Create a specific event monitor"""
	if not ResourceLoader.exists(script_path):
		Logger.warn("Monitor script not found: %s" % script_path, "arena")
		return

	Logger.info("Creating %s monitor component" % monitor_type, "arena")
	var monitor = load(script_path).new()
	monitor.name = "%sMonitor" % monitor_type
	add_child(monitor)
	Logger.debug("%s monitor added as child" % monitor_type, "arena")

func _on_event_monitor_timeout() -> void:
	"""Automatically run event performance monitoring for all enabled monitors"""
	# Find all monitor children and trigger their monitoring
	for child in get_children():
		if child.name.ends_with("Monitor") and child.has_method("monitor_event_performance"):
			child.monitor_event_performance()

# Legacy method for backward compatibility
func _on_breach_monitor_timeout() -> void:
	"""Legacy breach monitoring - redirects to new event monitoring"""
	_on_event_monitor_timeout()

## Manual monitoring function for debugging
func monitor_breach_performance_now() -> void:
	"""Manually trigger breach performance monitoring (for debugging)"""
	if has_node("BreachMonitor"):
		$BreachMonitor.monitor_breach_performance()
	else:
		Logger.warn("BreachMonitor not available in %s" % arena_name, "arena")
