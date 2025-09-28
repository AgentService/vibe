@tool
extends Node2D
class_name SpawnZoneGenerator

## POC: Generates circular spawn zones at branch endpoints during map generation
## Creates visible spawn zone indicators and integrates with existing spawn system

@export_group("Spawn Zone Configuration")
@export var spawn_zone_radius: float = 100.0
@export var show_spawn_zones: bool = true
@export var zone_color: Color = Color.CYAN
@export var zone_alpha: float = 0.3

# Generated spawn zones
var spawn_zones: Array[SpawnZoneNode] = []

signal spawn_zones_generated(zones: Array[SpawnZoneNode])

func generate_spawn_zones_from_endpoints(endpoint_positions: Array) -> Array[SpawnZoneNode]:
	"""Generate circular spawn zones at the provided endpoint positions"""
	clear_existing_zones()

	Logger.info("Generating spawn zones at %d branch endpoints" % endpoint_positions.size(), "spawnzones")

	for i in range(endpoint_positions.size()):
		var endpoint_pos: Vector2 = endpoint_positions[i]
		Logger.debug("Creating spawn zone %d at position %s" % [i, endpoint_pos], "spawnzones")

		var zone = create_spawn_zone_at_position(endpoint_pos, i)
		if zone:
			spawn_zones.append(zone)
			Logger.debug("Zone %d created successfully" % i, "spawnzones")

			if show_spawn_zones:
				add_child(zone)
				Logger.debug("Zone %d added as child" % i, "spawnzones")
		else:
			Logger.warn("Failed to create zone %d" % i, "spawnzones")

	Logger.info("Generated %d spawn zones with radius %.0fpx" % [spawn_zones.size(), spawn_zone_radius], "spawnzones")
	spawn_zones_generated.emit(spawn_zones)

	return spawn_zones

func create_spawn_zone_at_position(position: Vector2, zone_id: int) -> SpawnZoneNode:
	"""Create a single spawn zone with visual indicator at the specified position"""
	var zone = SpawnZoneNode.new()
	zone.setup(position, spawn_zone_radius, zone_id)
	zone.name = "SpawnZone_%d" % zone_id

	if show_spawn_zones:
		zone.setup_visual_indicator(zone_color, zone_alpha)

	Logger.debug("Created spawn zone %d at %s (radius: %.0f)" % [zone_id, position, spawn_zone_radius], "spawnzones")
	return zone

func clear_existing_zones() -> void:
	"""Clear all previously generated spawn zones"""
	for zone in spawn_zones:
		if is_instance_valid(zone) and zone.get_parent():
			zone.queue_free()

	spawn_zones.clear()
	Logger.debug("Cleared existing spawn zones", "spawnzones")

func get_spawn_zones() -> Array[SpawnZoneNode]:
	"""Get all generated spawn zones"""
	return spawn_zones

func get_spawn_zone_positions() -> Array[Vector2]:
	"""Get positions of all spawn zones for integration with spawn systems"""
	var positions: Array[Vector2] = []
	for zone in spawn_zones:
		positions.append(zone.global_position)
	return positions

func get_random_spawn_position() -> Vector2:
	"""Get a random spawn position from any available spawn zone"""
	if spawn_zones.is_empty():
		return Vector2.ZERO

	var random_zone = spawn_zones[randi() % spawn_zones.size()]
	return random_zone.get_random_position_in_zone()

func get_spawn_position_in_zone(zone_index: int) -> Vector2:
	"""Get a random spawn position within a specific zone"""
	if zone_index < 0 or zone_index >= spawn_zones.size():
		Logger.warn("Invalid zone index: %d (available: %d)" % [zone_index, spawn_zones.size()], "spawnzones")
		return Vector2.ZERO

	return spawn_zones[zone_index].get_random_position_in_zone()

## Individual spawn zone node with visual indicator
class SpawnZoneNode extends Node2D:
	var zone_radius: float = 100.0
	var zone_id: int = 0
	var visual_circle: Node2D

	func setup(position: Vector2, radius: float, id: int) -> void:
		global_position = position
		zone_radius = radius
		zone_id = id

	func setup_visual_indicator(color: Color, alpha: float) -> void:
		"""Create a visual circle to show the spawn zone boundaries"""
		visual_circle = Node2D.new()
		visual_circle.name = "VisualIndicator"
		add_child(visual_circle)

		# Draw circle using multiple line segments
		var segments = 32
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = Color(color.r, color.g, color.b, alpha)
		line.antialiased = true

		# Create circle points
		for i in range(segments + 1):
			var angle = (float(i) / segments) * TAU
			var point = Vector2.from_angle(angle) * zone_radius
			line.add_point(point)

		visual_circle.add_child(line)

		# Add center dot
		var center_dot = ColorRect.new()
		center_dot.size = Vector2(8, 8)
		center_dot.position = Vector2(-4, -4)
		center_dot.color = color
		visual_circle.add_child(center_dot)

		# Add zone ID label
		var label = Label.new()
		label.text = "Z%d" % zone_id
		label.position = Vector2(-12, zone_radius + 10)
		label.add_theme_color_override("font_color", color)
		visual_circle.add_child(label)

	func get_random_position_in_zone() -> Vector2:
		"""Get a random position within this spawn zone's radius"""
		var angle = randf() * TAU
		var distance = randf() * zone_radius * 0.9  # Stay slightly inside radius
		var offset = Vector2.from_angle(angle) * distance
		return global_position + offset

	func contains_position(position: Vector2) -> bool:
		"""Check if a position is within this spawn zone"""
		return global_position.distance_to(position) <= zone_radius

	func get_distance_to_position(position: Vector2) -> float:
		"""Get distance from zone center to position"""
		return global_position.distance_to(position)