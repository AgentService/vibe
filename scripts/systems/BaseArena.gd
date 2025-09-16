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

## Helper method to filter scene zones by proximity
func filter_zones_by_proximity(spawn_zone_areas: Array[Area2D], player_pos: Vector2, proximity_range: float) -> Array[Area2D]:
	var zones_in_range: Array[Area2D] = []

	for zone_area in spawn_zone_areas:
		var zone_pos = zone_area.global_position
		var distance = player_pos.distance_to(zone_pos)
		if distance <= proximity_range:
			zones_in_range.append(zone_area)

	return zones_in_range
