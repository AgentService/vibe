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

static func from_dictionary(enemy_dict: Dictionary, enemy_type: EnemyType = null) -> EnemyEntity:
	var entity := EnemyEntity.new()
	
	# Core fields from existing dictionary structure
	entity.pos = enemy_dict.get("pos", Vector2.ZERO)
	entity.vel = enemy_dict.get("vel", Vector2.ZERO)
	entity.hp = enemy_dict.get("hp", 10.0)
	entity.alive = enemy_dict.get("alive", false)
	
	# New fields for typed system
	entity.type_id = enemy_dict.get("type_id", "grunt_basic")
	entity.max_hp = enemy_dict.get("max_hp", entity.hp)
	entity.speed = enemy_dict.get("speed", 60.0)
	entity.size = enemy_dict.get("size", Vector2(24, 24))
	
	# If enemy type provided, use it to set defaults
	if enemy_type != null:
		entity.max_hp = enemy_type.health
		entity.speed = enemy_type.speed
		entity.size = enemy_type.size
	
	return entity

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

static func setup_dictionary_with_type(enemy_dict: Dictionary, enemy_type: EnemyType, spawn_pos: Vector2, velocity: Vector2) -> void:
	enemy_dict["pos"] = spawn_pos
	enemy_dict["vel"] = velocity
	enemy_dict["hp"] = enemy_type.health
	enemy_dict["max_hp"] = enemy_type.health
	enemy_dict["alive"] = true
	enemy_dict["type_id"] = enemy_type.id
	enemy_dict["speed"] = enemy_type.speed
	enemy_dict["size"] = enemy_type.size
	enemy_dict["ai_type"] = enemy_type.get_ai_type()
	enemy_dict["aggro_range"] = enemy_type.get_aggro_range()

func is_valid() -> bool:
	return not type_id.is_empty() and max_hp > 0.0 and speed >= 0.0