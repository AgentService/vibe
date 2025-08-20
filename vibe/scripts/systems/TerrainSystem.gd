extends Node
class_name TerrainSystem

## Terrain system for managing floor tiles, environmental effects, and surface properties.
## Handles visual representation via MultiMeshInstance2D for performance.

signal terrain_updated(terrain_transforms: Array[Transform2D])

var terrain_transforms: Array[Transform2D] = []
var terrain_data: Dictionary = {}
var tile_size: Vector2 = Vector2(32, 32)

const TERRAIN_TEXTURE_PATH: String = "res://assets/sprites/terrain/"

func _ready() -> void:
	pass

func load_terrain(terrain_config: Dictionary) -> void:
	clear_terrain()
	terrain_data = terrain_config
	
	var tiles := terrain_config.get("tiles", []) as Array
	
	for tile_data in tiles:
		var tile := tile_data as Dictionary
		_create_terrain_tile(tile)
	
	_update_terrain_visuals()

func clear_terrain() -> void:
	terrain_transforms.clear()
	terrain_data.clear()

func _create_terrain_tile(tile_data: Dictionary) -> void:
	var position := Vector2(
		tile_data.get("x", 0.0) as float,
		tile_data.get("y", 0.0) as float
	)
	var tile_type := tile_data.get("type", "stone_floor") as String
	var rotation := tile_data.get("rotation", 0.0) as float
	
	var transform := Transform2D()
	transform.origin = position
	transform = transform.rotated(rotation)
	
	terrain_transforms.append(transform)

func _update_terrain_visuals() -> void:
	terrain_updated.emit(terrain_transforms)

func get_terrain_at_position(world_pos: Vector2) -> Dictionary:
	# Return terrain properties at given world position
	# Could include movement speed modifiers, damage over time, etc.
	return {"type": "stone_floor", "speed_modifier": 1.0}

func get_tile_bounds() -> Vector2:
	return tile_size

func cleanup() -> void:
	clear_terrain()

func _exit_tree() -> void:
	cleanup()