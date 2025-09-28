extends Node
class_name SpawnZoneManager

## Dedicated spawn zone management system for creating functional Area2D spawn zones
## Provides reusable spawn zone creation and management across different arena types
## Integrates with SpawnDirector system for enemy spawning functionality

signal spawn_zones_created(zones: Array[Area2D])
signal spawn_zones_cleared()

# Configuration
@export_group("Spawn Zone Configuration")
@export var default_zone_radius: float = 100.0
@export var zone_color: Color = Color.CYAN
@export var zone_alpha: float = 0.5
@export var show_visual_indicators: bool = true

# Managed spawn zones
var managed_spawn_zones: Array[Area2D] = []

## Create functional Area2D spawn zones at specified positions
func create_spawn_zones_at_positions(positions, parent_node: Node, zone_radius: float = 0.0) -> Array[Area2D]:
	"""Create functional Area2D spawn zones at the provided positions"""

	# Use default radius if not specified
	var actual_radius = zone_radius if zone_radius > 0.0 else default_zone_radius

	# Clear any existing managed zones
	clear_managed_zones()

	Logger.info("🎯 Creating %d spawn zones with %.0fpx radius..." % [positions.size(), actual_radius], "spawnzones")

	for i in range(positions.size()):
		var position = positions[i]
		var zone = _create_single_spawn_zone(position, i, actual_radius)

		if zone and parent_node:
			parent_node.add_child(zone)
			managed_spawn_zones.append(zone)
			Logger.debug("Created spawn zone %d at %s" % [i, position], "spawnzones")

	Logger.info("✅ Spawn zone creation completed: %d zones created" % managed_spawn_zones.size(), "spawnzones")
	spawn_zones_created.emit(managed_spawn_zones)

	return managed_spawn_zones

## Create a single functional spawn zone at a position
func _create_single_spawn_zone(position: Vector2, zone_id: int, radius: float) -> Area2D:
	"""Create a single functional Area2D spawn zone"""

	# Create Area2D spawn zone (required by SpawnDirector)
	var spawn_zone = Area2D.new()
	spawn_zone.name = "SpawnZone_%d" % zone_id
	spawn_zone.global_position = position

	# Add CollisionShape2D with CircleShape2D for functional area detection
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	spawn_zone.add_child(collision_shape)

	# Add visual indicators if enabled
	if show_visual_indicators:
		_add_visual_indicators(spawn_zone, zone_id, radius)

	return spawn_zone

## Add visual indicators to a spawn zone
func _add_visual_indicators(spawn_zone: Area2D, zone_id: int, radius: float) -> void:
	"""Add cyan circle visual indicators to spawn zone"""

	# Create visual indicator container
	var visual_container = Node2D.new()
	visual_container.name = "VisualIndicator"
	spawn_zone.add_child(visual_container)

	# Create visual circle using Line2D
	var circle_line = Line2D.new()
	circle_line.name = "SpawnZoneCircle"
	circle_line.width = 4.0
	circle_line.default_color = Color(zone_color.r, zone_color.g, zone_color.b, zone_alpha)
	circle_line.antialiased = true

	# Create circle points
	var segments = 32
	for j in range(segments + 1):
		var angle = (float(j) / segments) * TAU
		var point = Vector2.from_angle(angle) * radius
		circle_line.add_point(point)

	visual_container.add_child(circle_line)

	# Add center dot
	var center_dot = ColorRect.new()
	center_dot.name = "CenterDot"
	center_dot.size = Vector2(8, 8)
	center_dot.position = Vector2(-4, -4)
	center_dot.color = zone_color
	visual_container.add_child(center_dot)

	# Add zone ID label
	var label = Label.new()
	label.name = "ZoneLabel"
	label.text = "Z%d" % zone_id
	label.position = Vector2(-12, radius + 10)
	label.add_theme_color_override("font_color", zone_color)
	visual_container.add_child(label)

## Clear all managed spawn zones
func clear_managed_zones() -> void:
	"""Clear all managed spawn zones from the scene"""
	for zone in managed_spawn_zones:
		if is_instance_valid(zone):
			zone.queue_free()

	managed_spawn_zones.clear()
	spawn_zones_cleared.emit()
	Logger.debug("Cleared all managed spawn zones", "spawnzones")

## Get all managed spawn zones
func get_spawn_zones() -> Array[Area2D]:
	"""Get all managed spawn zones"""
	return managed_spawn_zones

## Get spawn zone count
func get_spawn_zone_count() -> int:
	"""Get the number of managed spawn zones"""
	return managed_spawn_zones.size()

## Get spawn zone by index
func get_spawn_zone_by_index(index: int) -> Area2D:
	"""Get a specific spawn zone by index"""
	if index < 0 or index >= managed_spawn_zones.size():
		Logger.warn("Invalid spawn zone index: %d (available: %d)" % [index, managed_spawn_zones.size()], "spawnzones")
		return null
	return managed_spawn_zones[index]

## Get random spawn zone
func get_random_spawn_zone() -> Area2D:
	"""Get a random spawn zone from managed zones"""
	if managed_spawn_zones.is_empty():
		Logger.warn("No spawn zones available for random selection", "spawnzones")
		return null

	var spawn_rng = RNG.stream("spawn")
	var random_index = spawn_rng.randi() % managed_spawn_zones.size()
	return managed_spawn_zones[random_index]

## Get positions of all spawn zones
func get_spawn_zone_positions() -> Array[Vector2]:
	"""Get positions of all managed spawn zones"""
	var positions: Array[Vector2] = []
	for zone in managed_spawn_zones:
		if is_instance_valid(zone):
			positions.append(zone.global_position)
	return positions

## Get random spawn position from any zone
func get_random_spawn_position() -> Vector2:
	"""Get a random spawn position from any available spawn zone"""
	var zone = get_random_spawn_zone()
	if not zone:
		return Vector2.ZERO

	return _get_random_position_in_zone(zone)

## Get random spawn position in specific zone
func get_spawn_position_in_zone(zone_index: int) -> Vector2:
	"""Get a random spawn position within a specific zone"""
	var zone = get_spawn_zone_by_index(zone_index)
	if not zone:
		return Vector2.ZERO

	return _get_random_position_in_zone(zone)

## Generate random position within a zone's collision shape
func _get_random_position_in_zone(zone: Area2D) -> Vector2:
	"""Generate a random position within the zone's collision shape"""
	if not zone:
		return Vector2.ZERO

	# Get collision shape
	var collision_shape = zone.get_node("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return zone.global_position

	var shape = collision_shape.shape as CircleShape2D
	if not shape:
		return zone.global_position

	# Generate random position within circle
	var spawn_rng = RNG.stream("spawn")
	var angle = spawn_rng.randf() * TAU
	var distance = spawn_rng.randf() * shape.radius * 0.9  # Stay slightly inside radius
	var offset = Vector2.from_angle(angle) * distance

	return zone.global_position + offset

## Configure visual appearance
func set_zone_appearance(color: Color, alpha: float = 0.5) -> void:
	"""Configure the visual appearance of spawn zones"""
	zone_color = color
	zone_alpha = alpha

## Update existing zones with new appearance
func update_zone_appearance() -> void:
	"""Update visual appearance of existing zones"""
	for zone in managed_spawn_zones:
		if is_instance_valid(zone):
			var visual_container = zone.get_node("VisualIndicator")
			if visual_container:
				_update_zone_visuals(visual_container, zone_color, zone_alpha)

func _update_zone_visuals(visual_container: Node2D, color: Color, alpha: float) -> void:
	"""Update visual components of a zone"""
	var circle_line = visual_container.get_node("SpawnZoneCircle")
	if circle_line and circle_line is Line2D:
		circle_line.default_color = Color(color.r, color.g, color.b, alpha)

	var center_dot = visual_container.get_node("CenterDot")
	if center_dot and center_dot is ColorRect:
		center_dot.color = color

	var label = visual_container.get_node("ZoneLabel")
	if label and label is Label:
		label.add_theme_color_override("font_color", color)