extends Node

## Enemy registry system managing enemy type definitions.
## Loads all enemy .tres resources and provides weighted random selection.

class_name EnemyRegistry

var enemy_types: Dictionary = {}
var _cached_wave_pool: Array[EnemyType] = []
var _wave_pool_dirty: bool = true

signal enemy_types_loaded()

func _ready() -> void:
	Logger.info("EnemyRegistry._ready() starting", "enemies")
	load_all_enemy_types()
	Logger.info("EnemyRegistry._ready() finished loading types: " + str(enemy_types.size()), "enemies")
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _exit_tree() -> void:
	# Cleanup signal connections
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	Logger.debug("EnemyRegistry: Cleaned up signal connections", "systems")

func _on_balance_reloaded() -> void:
	load_all_enemy_types()
	Logger.info("Reloaded enemy types", "enemies")

func load_all_enemy_types() -> void:
	Logger.info("Loading enemy types from directory...", "enemies")
	enemy_types.clear()
	_wave_pool_dirty = true
	
	
	var enemies_dir := "res://vibe/data/content/enemies/"
	Logger.info("Trying to open directory: " + enemies_dir, "enemies")
	var dir := DirAccess.open(enemies_dir)
	
	if dir == null:
		Logger.warn("Could not open enemies directory: " + enemies_dir, "enemies")
		_load_fallback_types()
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_count := 0
	var total_files := 0
	
	while file_name != "":
		total_files += 1
		if file_name.ends_with(".tres"):
			var file_path := enemies_dir + file_name
			if _load_enemy_type_from_file(file_path):
				loaded_count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	Logger.debug("Found " + str(total_files) + " files, loaded " + str(loaded_count) + " .tres enemies", "enemies")
	
	if loaded_count == 0:
		Logger.warn("No enemy types loaded, using fallback", "enemies")
		_load_fallback_types()
	else:
		Logger.info("SUCCESS: Loaded " + str(loaded_count) + " .tres enemy types", "enemies")
		
		# Debug: List all loaded enemy types
		for type_id in enemy_types.keys():
			var enemy_type: EnemyType = enemy_types[type_id]
			Logger.debug("Loaded enemy: " + type_id + " (size: " + str(enemy_type.size) + ", weight: " + str(enemy_type.spawn_weight) + ")", "enemies")
	
	enemy_types_loaded.emit()

func _load_enemy_type_from_file(file_path: String) -> bool:
	# Load .tres resource directly
	var enemy_type: EnemyType = load(file_path) as EnemyType
	
	if enemy_type == null:
		Logger.warn("Failed to load .tres resource: " + file_path, "enemies")
		return false
	
	# Validate enemy type
	var validation_errors := enemy_type.validate()
	if validation_errors.size() > 0:
		Logger.warn("Enemy type validation failed for " + file_path + ": " + str(validation_errors), "enemies")
		return false
	
	enemy_types[enemy_type.id] = enemy_type
	Logger.debug("Loaded enemy type: " + enemy_type.id + " (tres)", "enemies")
	return true

func _load_fallback_types() -> void:
	Logger.error("Enemy loading failed completely - no fallback available", "enemies")
	Logger.error("Ensure knight .tres files exist in res://vibe/data/content/enemies/", "enemies")

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
	
	# Build weighted pool based on spawn_weight with reasonable limits
	const MAX_POOL_SIZE: int = 500  # Prevent excessive memory usage
	const MAX_WEIGHT_PER_TYPE: int = 50  # Cap individual type weight
	
	for enemy_type in enemy_types.values():
		var type := enemy_type as EnemyType
		var raw_weight := int(type.spawn_weight * 10.0)
		var weight: int = min(raw_weight, MAX_WEIGHT_PER_TYPE)  # Cap weight per type
		
		# Stop adding if we would exceed pool size limit
		if _cached_wave_pool.size() + weight > MAX_POOL_SIZE:
			Logger.warn("Wave pool size limit reached (%d). Some enemy types may have reduced spawn rates." % MAX_POOL_SIZE, "enemies")
			break
		
		for i in range(weight):
			_cached_wave_pool.append(type)
	
	_wave_pool_dirty = false
	Logger.debug("Rebuilt wave pool with " + str(_cached_wave_pool.size()) + " weighted entries (max: %d)" % MAX_POOL_SIZE, "enemies")

func get_available_type_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in enemy_types.keys():
		ids.append(id as String)
	return ids

func has_enemy_type(type_id: String) -> bool:
	return type_id in enemy_types

func get_total_types() -> int:
	return enemy_types.size()
