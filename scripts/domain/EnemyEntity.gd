extends Resource

## Enemy entity model that extends the current dictionary structure.
## Provides typed access to enemy data while maintaining compatibility.
## PHASE 4 OPTIMIZATION: Now supports Dictionary-based data storage for memory efficiency

class_name EnemyEntity

# PHASE 4: Dictionary-based data reference for memory optimization
# When _data_ref is set, all properties access the shared Dictionary instead of individual vars
var _data_ref: Dictionary = {}

# PERFORMANCE OPTIMIZATION: Direct index for O(1) lookups (eliminates _find_enemy_index)
var index: int = -1

# Legacy individual variables (kept for compatibility when _data_ref is not used)
var _type_id: String
var _pos: Vector2
var _vel: Vector2
var _hp: float
var _max_hp: float
var _alive: bool
var _speed: float
var _size: Vector2
var _direction: Vector2 = Vector2.ZERO

# Property accessors that use Dictionary data when available
var type_id: String:
	get: return _data_ref.get("type_id", _type_id) if not _data_ref.is_empty() else _type_id
	set(value): 
		if not _data_ref.is_empty(): _data_ref["type_id"] = value
		else: _type_id = value

var pos: Vector2:
	get: return _data_ref.get("pos", _pos) if not _data_ref.is_empty() else _pos
	set(value):
		if not _data_ref.is_empty(): _data_ref["pos"] = value
		else: _pos = value

var vel: Vector2:
	get: return _data_ref.get("vel", _vel) if not _data_ref.is_empty() else _vel
	set(value):
		if not _data_ref.is_empty(): _data_ref["vel"] = value
		else: _vel = value

var hp: float:
	get: return _data_ref.get("hp", _hp) if not _data_ref.is_empty() else _hp
	set(value):
		if not _data_ref.is_empty(): _data_ref["hp"] = value
		else: _hp = value

var max_hp: float:
	get: return _data_ref.get("max_hp", _max_hp) if not _data_ref.is_empty() else _max_hp
	set(value):
		if not _data_ref.is_empty(): _data_ref["max_hp"] = value
		else: _max_hp = value

var alive: bool:
	get: return _data_ref.get("alive", _alive) if not _data_ref.is_empty() else _alive
	set(value):
		if not _data_ref.is_empty(): _data_ref["alive"] = value
		else: _alive = value

var speed: float:
	get: return _data_ref.get("speed", _speed) if not _data_ref.is_empty() else _speed
	set(value):
		if not _data_ref.is_empty(): _data_ref["speed"] = value
		else: _speed = value

var size: Vector2:
	get: return _data_ref.get("size", _size) if not _data_ref.is_empty() else _size
	set(value):
		if not _data_ref.is_empty(): _data_ref["size"] = value
		else: _size = value

var direction: Vector2:
	get: return _data_ref.get("direction", _direction) if not _data_ref.is_empty() else _direction
	set(value):
		if not _data_ref.is_empty(): _data_ref["direction"] = value
		else: _direction = value

static func from_dictionary(enemy_dict: Dictionary, enemy_type: EnemyType = null) -> EnemyEntity:
	var entity := EnemyEntity.new()
	
	# Core fields from existing dictionary structure
	entity.pos = enemy_dict.get("pos", Vector2.ZERO)
	entity.vel = enemy_dict.get("vel", Vector2.ZERO)
	entity.hp = enemy_dict.get("hp", 10.0)
	entity.alive = enemy_dict.get("alive", false)
	
	# New fields for typed system
	entity.type_id = enemy_dict.get("type_id", "knight_swarm")
	entity.max_hp = enemy_dict.get("max_hp", entity.hp)
	entity.speed = enemy_dict.get("speed", 60.0)
	entity.size = enemy_dict.get("size", Vector2(24, 24))
	entity.direction = enemy_dict.get("direction", Vector2.ZERO)
	
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
		"size": size,
		"direction": direction
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
	enemy_dict["direction"] = direction

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

# New method to setup EnemyEntity directly
func setup_with_type(enemy_type: EnemyType, spawn_pos: Vector2, velocity: Vector2) -> void:
	pos = spawn_pos
	vel = velocity
	hp = enemy_type.health
	max_hp = enemy_type.health
	alive = true
	type_id = enemy_type.id
	speed = enemy_type.speed
	size = enemy_type.size

func is_valid() -> bool:
	return not type_id.is_empty() and max_hp > 0.0 and speed >= 0.0

# PHASE 4: Reset method for Dictionary-based data reuse (eliminates object creation)
func reset_to_defaults() -> void:
	# PERFORMANCE: Keep index intact for O(1) lookups
	# index remains unchanged during reset
	
	if not _data_ref.is_empty():
		# Reset Dictionary data to default values for reuse
		_data_ref["pos"] = Vector2.ZERO
		_data_ref["vel"] = Vector2.ZERO
		_data_ref["hp"] = 0.0
		_data_ref["max_hp"] = 0.0
		_data_ref["alive"] = false
		_data_ref["type_id"] = ""
		_data_ref["speed"] = 60.0
		_data_ref["size"] = Vector2(24, 24)
		_data_ref["direction"] = Vector2.ZERO
	else:
		# Fallback for legacy mode
		_pos = Vector2.ZERO
		_vel = Vector2.ZERO
		_hp = 0.0
		_max_hp = 0.0
		_alive = false
		_type_id = ""
		_speed = 60.0
		_size = Vector2(24, 24)
		_direction = Vector2.ZERO
