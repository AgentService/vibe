extends Resource

## Player type definition as a Godot Resource (.tres format).
## Contains all static properties that define player character stats.
## @export annotations enable inspector editing when saved as .tres

class_name PlayerType

@export var id: String = ""
@export var display_name: String = ""
@export var max_health: int = 199
@export var move_speed: float = 110.0
@export var pickup_radius: float = 12.0
@export var roll_duration: float = 0.3
@export var roll_speed: float = 400.0
@export var collision_radius: float = 8.0
@export var attack_animation_duration: float = 0.4

func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if id.is_empty():
		errors.append("Player type must have an id")
	
	if max_health <= 0:
		errors.append("Player max_health must be greater than 0")
	
	if move_speed <= 0.0:
		errors.append("Player move_speed must be greater than 0")
	
	if pickup_radius < 0.0:
		errors.append("Player pickup_radius cannot be negative")
	
	if roll_duration <= 0.0:
		errors.append("Player roll_duration must be greater than 0")
	
	if roll_speed <= 0.0:
		errors.append("Player roll_speed must be greater than 0")
	
	if collision_radius <= 0.0:
		errors.append("Player collision_radius must be greater than 0")
	
	if attack_animation_duration <= 0.0:
		errors.append("Player attack_animation_duration must be greater than 0")
	
	return errors
