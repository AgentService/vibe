extends Resource

## Enemy entity model that extends the current dictionary structure.
## Provides typed access to enemy data while maintaining compatibility.

class_name EnemyEntity

var type_id: String
var pos: Vector2
var vel: Vector2
var hp: float
var max_hp: float
var alive: bool
var speed: float
var size: Vector2


func to_dictionary() -> Dictionary:
	return {
		"pos": pos,
		"vel": vel,
		"hp": hp,
		"max_hp": max_hp,
		"alive": alive,
		"type_id": type_id,
		"speed": speed,
		"size": size
	}

func update_dictionary(enemy_dict: Dictionary) -> void:
	enemy_dict["pos"] = pos
	enemy_dict["vel"] = vel
	enemy_dict["hp"] = hp
	enemy_dict["max_hp"] = max_hp
	enemy_dict["alive"] = alive
	enemy_dict["type_id"] = type_id
	enemy_dict["speed"] = speed
	enemy_dict["size"] = size


# V2 method to setup EnemyEntity from SpawnConfig
func setup_with_config(spawn_config: SpawnConfig, spawn_pos: Vector2, velocity: Vector2) -> void:
	pos = spawn_pos
	vel = velocity
	hp = spawn_config.health
	max_hp = spawn_config.health
	alive = true
	type_id = str(spawn_config.template_id)
	speed = spawn_config.speed
	size = Vector2(24.0 * spawn_config.size_scale, 24.0 * spawn_config.size_scale)

func is_valid() -> bool:
	return not type_id.is_empty() and max_hp > 0.0 and speed >= 0.0
