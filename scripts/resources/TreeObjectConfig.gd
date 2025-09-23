class_name TreeObjectConfig
extends Resource

## Configuration for tree objects with proper z-ordering
## Separates tree base (collision) from tree canopy (visual)

@export var tree_name: String = ""

# Base configuration (lower z-index, collision)
@export var base_tile: Vector2i = Vector2i(0, 0)  # Tile coordinates for tree base/trunk
@export var has_collision: bool = true
@export var collision_radius: float = 16.0  # Collision area radius in pixels

# Canopy configuration (higher z-index, visual only)
@export var canopy_tile: Vector2i = Vector2i(0, 1)  # Tile coordinates for tree canopy
@export var canopy_offset: Vector2 = Vector2(0, -8)  # Offset canopy relative to base

# Placement parameters
@export var placement_weight: float = 1.0  # Relative probability of selection
@export var min_spacing: int = 2  # Minimum distance from other trees
@export var max_spacing: int = 5  # Maximum spacing for natural variation

# Visual parameters
@export var base_z_index: int = 1  # Z-index for base layer
@export var canopy_z_index: int = 10  # Z-index for canopy layer

func create_collision_shape() -> CollisionShape2D:
	"""Create a collision shape for this tree's base"""
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = collision_radius
	collision_shape.shape = circle_shape
	return collision_shape

func is_valid() -> bool:
	"""Validate that this tree configuration is complete"""
	return not tree_name.is_empty() and \
	       placement_weight > 0.0 and \
	       collision_radius > 0.0