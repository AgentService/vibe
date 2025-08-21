extends Node

## Enemy registry system managing enemy type definitions.
## Loads all enemy JSON files and provides weighted random selection.

class_name EnemyRegistry

var enemy_types: Dictionary = {}
var _cached_wave_pool: Array[EnemyType] = []
var _wave_pool_dirty: bool = true

signal enemy_types_loaded()

func _ready() -> void:
	load_all_enemy_types()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _on_balance_reloaded() -> void:
	load_all_enemy_types()
	Logger.info("Reloaded enemy types", "enemies")

func load_all_enemy_types() -> void:
	enemy_types.clear()
	_wave_pool_dirty = true
	
	var enemies_dir := "res://data/enemies/"
	var dir := DirAccess.open(enemies_dir)
	
	if dir == null:
		Logger.warn("Could not open enemies directory: " + enemies_dir, "enemies")
		_load_fallback_types()
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_count := 0
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path := enemies_dir + file_name
			if _load_enemy_type_from_file(file_path):
				loaded_count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if loaded_count == 0:
		Logger.warn("No enemy types loaded, using fallback", "enemies")
		_load_fallback_types()
	else:
		Logger.info("Loaded " + str(loaded_count) + " enemy types", "enemies")
	
	enemy_types_loaded.emit()

func _load_enemy_type_from_file(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		Logger.warn("Could not open enemy file: " + file_path, "enemies")
		return false
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	
	if parse_result != OK:
		Logger.warn("Failed to parse enemy JSON: " + file_path + " - " + json.get_error_message(), "enemies")
		return false
	
	var data: Dictionary = json.data
	var enemy_type := EnemyType.from_json(data)
	
	# Validate enemy type
	var validation_errors := enemy_type.validate()
	if validation_errors.size() > 0:
		Logger.warn("Enemy type validation failed for " + file_path + ": " + str(validation_errors), "enemies")
		return false
	
	enemy_types[enemy_type.id] = enemy_type
	Logger.debug("Loaded enemy type: " + enemy_type.id, "enemies")
	return true

func _load_fallback_types() -> void:
	# Create basic grunt enemy as fallback
	var grunt_data := {
		"id": "grunt_basic",
		"display_name": "Basic Grunt",
		"health": 3.0,
		"speed": 80.0,
		"size": {"x": 24, "y": 24},
		"collision_radius": 12.0,
		"xp_value": 1,
		"spawn_weight": 1.0,
		"visual": {
			"color": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0},
			"shape": "square"
		},
		"behavior": {
			"ai_type": "chase_player",
			"aggro_range": 300.0
		}
	}
	
	var grunt_type := EnemyType.from_json(grunt_data)
	enemy_types[grunt_type.id] = grunt_type
	Logger.info("Loaded fallback enemy type: " + grunt_type.id, "enemies")

func get_enemy_type(type_id: String) -> EnemyType:
	return enemy_types.get(type_id, null)

func get_all_enemy_types() -> Array[EnemyType]:
	var types: Array[EnemyType] = []
	for type in enemy_types.values():
		types.append(type as EnemyType)
	return types

func get_random_enemy_type(pool_name: String = "waves") -> EnemyType:
	if _wave_pool_dirty:
		_rebuild_wave_pool()
	
	if _cached_wave_pool.is_empty():
		Logger.warn("No enemy types available for spawning", "enemies")
		return null
	
	var random_index := RNG.randi_range(pool_name, 0, _cached_wave_pool.size() - 1)
	return _cached_wave_pool[random_index]

func _rebuild_wave_pool() -> void:
	_cached_wave_pool.clear()
	
	# Build weighted pool based on spawn_weight
	for enemy_type in enemy_types.values():
		var type := enemy_type as EnemyType
		var weight := int(type.spawn_weight * 10.0)  # Convert to integer for easy pooling
		
		for i in range(weight):
			_cached_wave_pool.append(type)
	
	_wave_pool_dirty = false
	Logger.debug("Rebuilt wave pool with " + str(_cached_wave_pool.size()) + " weighted entries", "enemies")

func get_available_type_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in enemy_types.keys():
		ids.append(id as String)
	return ids

func has_enemy_type(type_id: String) -> bool:
	return type_id in enemy_types

func get_total_types() -> int:
	return enemy_types.size()