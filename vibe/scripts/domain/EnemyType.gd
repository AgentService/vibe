extends Resource

## Enemy type definition as a Godot Resource (.tres format).
## Contains all static properties that define an enemy variant.
## @export annotations enable inspector editing when saved as .tres

class_name EnemyType

@export var id: String = ""
@export var display_name: String = ""
@export var health: float = 10.0
@export var speed: float = 50.0
@export var speed_min: float = 50.0
@export var speed_max: float = 100.0
@export var size: Vector2 = Vector2(24, 24)
@export var collision_radius: float = 12.0
@export var xp_value: int = 1
@export var spawn_weight: float = 1.0
@export var render_tier: String = "regular"
@export var visual_config: Dictionary = {}
@export var behavior_config: Dictionary = {}


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
	
	if speed_min < 0.0:
		errors.append("Enemy speed_min cannot be negative")
	
	if speed_max < 0.0:
		errors.append("Enemy speed_max cannot be negative")
	
	if speed_min > speed_max:
		errors.append("Enemy speed_min cannot be greater than speed_max")
	
	if collision_radius <= 0.0:
		errors.append("Enemy collision_radius must be greater than 0")
	
	if spawn_weight < 0.0:
		errors.append("Enemy spawn_weight cannot be negative")
	
	if render_tier.is_empty():
		errors.append("Enemy render_tier must be specified")
	
	var valid_tiers: Array[String] = ["swarm", "regular", "elite", "boss"]
	if not render_tier in valid_tiers:
		errors.append("Enemy render_tier must be one of: " + str(valid_tiers))
	
	return errors