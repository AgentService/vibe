class_name InteractiveObjectConfig
extends Resource

## Configuration for interactive objects like chests, shrines, and harvestable nodes
## Supports both tile-based and scene-based objects

@export var object_name: String = ""
@export var object_type: String = ""  # "chest", "shrine", "harvestable", "decoration"

# Visual configuration
@export var use_tile: bool = true  # Use tile or scene
@export var tile_coords: Vector2i = Vector2i(0, 0)  # If using tile
@export var object_scene: PackedScene  # If using scene

# Placement parameters
@export var placement_weight: float = 1.0
@export var placement_density: float = 0.02  # Chance per eligible tile
@export var min_distance_from_spawn: float = 100.0  # Minimum distance from player spawn
@export var requires_clear_area: bool = true  # Needs empty space around it
@export var clear_area_radius: float = 32.0

# Interaction configuration
@export var is_interactive: bool = true
@export var interaction_radius: float = 48.0
@export var interaction_prompt: String = "Press E to interact"

# Zone restrictions
@export var allowed_zones: Array[String] = []  # Empty = all zones allowed
@export var avoid_boundaries: bool = true  # Don't place near arena edges

# Gameplay configuration
@export var loot_table: String = ""  # Reference to loot table resource
@export var respawn_time: float = 0.0  # 0 = doesn't respawn
@export var one_time_use: bool = false

func can_place_at_position(pos: Vector2, arena_bounds: Rect2i, existing_objects: Array[Vector2]) -> bool:
	"""Check if this object can be placed at the given position"""

	# Check arena boundaries
	if avoid_boundaries:
		var margin = clear_area_radius
		var bounds_with_margin = Rect2(
			arena_bounds.position.x + margin,
			arena_bounds.position.y + margin,
			arena_bounds.size.x - (margin * 2),
			arena_bounds.size.y - (margin * 2)
		)
		if not bounds_with_margin.has_point(pos):
			return false

	# Check distance from spawn (assuming spawn at center)
	var spawn_pos = Vector2(arena_bounds.get_center())
	if pos.distance_to(spawn_pos) < min_distance_from_spawn:
		return false

	# Check distance from existing objects
	if requires_clear_area:
		for existing_pos in existing_objects:
			if pos.distance_to(existing_pos) < clear_area_radius:
				return false

	return true

func create_interactive_area() -> Area2D:
	"""Create an Area2D for interaction detection"""
	var area = Area2D.new()
	area.name = object_name + "_InteractionArea"

	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = interaction_radius
	collision_shape.shape = circle_shape

	area.add_child(collision_shape)
	return area

func is_valid() -> bool:
	"""Validate that this object configuration is complete"""
	return not object_name.is_empty() and \
	       not object_type.is_empty() and \
	       placement_weight > 0.0 and \
	       (use_tile or object_scene != null)