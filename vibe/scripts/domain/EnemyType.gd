extends Resource

## Enemy type definition loaded from JSON data.
## Contains all static properties that define an enemy variant.

class_name EnemyType

var id: String
var display_name: String
var health: float
var speed: float
var size: Vector2
var collision_radius: float
var xp_value: int
var spawn_weight: float
var visual_config: Dictionary
var behavior_config: Dictionary

static func from_json(data: Dictionary) -> EnemyType:
	var type := EnemyType.new()
	
	# Required fields
	type.id = data.get("id", "unknown")
	type.display_name = data.get("display_name", "Unknown Enemy")
	type.health = data.get("health", 10.0)
	type.speed = data.get("speed", 50.0)
	
	# Size handling - accept both Vector2 and Dictionary format
	var size_data = data.get("size", {"x": 24, "y": 24})
	if size_data is Dictionary:
		type.size = Vector2(size_data.get("x", 24.0), size_data.get("y", 24.0))
	else:
		type.size = size_data as Vector2
	
	type.collision_radius = data.get("collision_radius", 12.0)
	type.xp_value = data.get("xp_value", 1)
	type.spawn_weight = data.get("spawn_weight", 1.0)
	
	# Visual configuration
	type.visual_config = data.get("visual", {
		"color": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0},
		"shape": "square"
	})
	
	# Behavior configuration
	type.behavior_config = data.get("behavior", {
		"ai_type": "chase_player",
		"aggro_range": 300.0
	})
	
	return type

func get_color() -> Color:
	var color_data: Dictionary = visual_config.get("color", {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0})
	return Color(
		color_data.get("r", 1.0),
		color_data.get("g", 0.0),
		color_data.get("b", 0.0),
		color_data.get("a", 1.0)
	)

func get_shape() -> String:
	return visual_config.get("shape", "square")

func get_ai_type() -> String:
	return behavior_config.get("ai_type", "chase_player")

func get_aggro_range() -> float:
	return behavior_config.get("aggro_range", 300.0)

func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if id.is_empty():
		errors.append("Enemy type must have an id")
	
	if health <= 0.0:
		errors.append("Enemy health must be greater than 0")
	
	if speed < 0.0:
		errors.append("Enemy speed cannot be negative")
	
	if collision_radius <= 0.0:
		errors.append("Enemy collision_radius must be greater than 0")
	
	if spawn_weight < 0.0:
		errors.append("Enemy spawn_weight cannot be negative")
	
	return errors