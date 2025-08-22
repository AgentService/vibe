extends Node

## Wave director managing pooled enemies and spawning mechanics.
## Spawns enemies from outside the arena moving toward center.
## Updates on fixed combat step (30 Hz) for deterministic behavior.

class_name WaveDirector

var enemies: Array[Dictionary] = []
var max_enemies: int
var spawn_timer: float = 0.0
var spawn_interval: float
var arena_center: Vector2
var spawn_radius: float
var enemy_hp: float
var enemy_speed_min: float
var enemy_speed_max: float
var spawn_count_min: int
var spawn_count_max: int
var arena_bounds: float
var target_distance: float

# Cached alive enemies list for performance
var _alive_enemies_cache: Array[Dictionary] = []
var _cache_dirty: bool = true
var _last_cache_frame: int = -1

# Free enemy slot tracking for faster spawning
var _last_free_index: int = 0

# Enemy registry data
var _enemy_registry: Dictionary = {}
var _enemy_configs: Dictionary = {}
var _weighted_enemy_types: Array[String] = []

signal enemies_updated(alive_enemies: Array[Dictionary])

func _ready() -> void:
	_load_balance_values()
	_load_enemy_registry()
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _load_balance_values() -> void:
	max_enemies = BalanceDB.get_waves_value("max_enemies")
	spawn_interval = BalanceDB.get_waves_value("spawn_interval")
	var center_data: Dictionary = BalanceDB.get_waves_value("arena_center")
	arena_center = Vector2(center_data.get("x", 400.0), center_data.get("y", 300.0))
	spawn_radius = BalanceDB.get_waves_value("spawn_radius")
	enemy_hp = BalanceDB.get_waves_value("enemy_hp")
	enemy_speed_min = BalanceDB.get_waves_value("enemy_speed_min")
	enemy_speed_max = BalanceDB.get_waves_value("enemy_speed_max")
	spawn_count_min = BalanceDB.get_waves_value("spawn_count_min")
	spawn_count_max = BalanceDB.get_waves_value("spawn_count_max")
	arena_bounds = BalanceDB.get_waves_value("arena_bounds")
	target_distance = BalanceDB.get_waves_value("target_distance")

func _load_enemy_registry() -> void:
	var registry_path = "res://data/enemies/enemy_registry.json"
	
	if not FileAccess.file_exists(registry_path):
		Logger.warn("Enemy registry not found, using fallback enemy types", "waves")
		_setup_fallback_enemy_data()
		return
	
	var file = FileAccess.open(registry_path, FileAccess.READ)
	if not file:
		Logger.warn("Failed to open enemy registry, using fallback", "waves")
		_setup_fallback_enemy_data()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		Logger.warn("Failed to parse enemy registry, using fallback", "waves")
		_setup_fallback_enemy_data()
		return
	
	_enemy_registry = json.data
	var enemy_types = _enemy_registry.get("enemy_types", {})
	
	# Load individual enemy configs and build weighted spawn list
	_weighted_enemy_types.clear()
	_enemy_configs.clear()
	
	for enemy_type in enemy_types.keys():
		var enemy_data = enemy_types[enemy_type]
		var config_path = enemy_data.get("config_path", "")
		var spawn_weight = enemy_data.get("spawn_weight", 1)
		
		# Load enemy config
		var enemy_config = _load_enemy_config(config_path)
		if enemy_config:
			_enemy_configs[enemy_type] = enemy_config
			
			# Add to weighted list based on spawn weight
			for i in range(spawn_weight):
				_weighted_enemy_types.append(enemy_type)
	
	Logger.info("Loaded " + str(_enemy_configs.size()) + " enemy types from registry", "waves")
	Logger.debug("Weighted spawn distribution: " + str(_weighted_enemy_types), "waves")

func _load_enemy_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		Logger.warn("Enemy config not found: " + config_path, "waves")
		return {}
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		Logger.warn("Failed to open enemy config: " + config_path, "waves")
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		Logger.warn("Failed to parse enemy config: " + config_path, "waves")
		return {}
	
	return json.data

func _setup_fallback_enemy_data() -> void:
	# Fallback to hardcoded enemy data if registry fails
	_weighted_enemy_types = ["green_slime", "green_slime", "green_slime", "scout"]  # 75% green_slime, 25% scout
	_enemy_configs = {
		"green_slime": {"stats": {"hp": 3.0, "speed_min": 60.0, "speed_max": 120.0}},
		"scout": {"stats": {"hp": 1.5, "speed_min": 90.0, "speed_max": 180.0}}
	}
	Logger.info("Using fallback enemy data", "waves")

func _on_balance_reloaded() -> void:
	_load_balance_values()
	_initialize_pool()
	Logger.info("Reloaded wave balance values", "waves")

func _choose_enemy_type() -> String:
	# Use weighted selection from registry
	if _weighted_enemy_types.is_empty():
		Logger.warn("No weighted enemy types available, defaulting to green_slime", "waves")
		return "green_slime"
	
	var index = RNG.randi_range("waves", 0, _weighted_enemy_types.size() - 1)
	return _weighted_enemy_types[index]

func _get_enemy_speed(enemy_type: String) -> float:
	var enemy_config = _enemy_configs.get(enemy_type)
	if not enemy_config:
		Logger.warn("No config found for enemy type: " + enemy_type + ", using default speed", "waves")
		return RNG.randf_range("waves", enemy_speed_min, enemy_speed_max)
	
	var stats = enemy_config.get("stats", {})
	var speed_min = stats.get("speed_min", enemy_speed_min)
	var speed_max = stats.get("speed_max", enemy_speed_max)
	
	return RNG.randf_range("waves", speed_min, speed_max)

func _get_enemy_hp(enemy_type: String) -> float:
	var enemy_config = _enemy_configs.get(enemy_type)
	if not enemy_config:
		Logger.warn("No config found for enemy type: " + enemy_type + ", using default HP", "waves")
		return enemy_hp
	
	var stats = enemy_config.get("stats", {})
	return stats.get("hp", enemy_hp)

func _initialize_pool() -> void:
	enemies.resize(max_enemies)
	for i in range(max_enemies):
		enemies[i] = {
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"hp": enemy_hp,
			"alive": false,
			"type": "grunt"
		}

func _on_combat_step(payload) -> void:
	_handle_spawning(payload.dt)
	_update_enemies(payload.dt)
	var alive_enemies := get_alive_enemies()
	enemies_updated.emit(alive_enemies)

func _handle_spawning(dt: float) -> void:
	spawn_timer += dt
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var spawn_count := RNG.randi_range("waves", spawn_count_min, spawn_count_max)
		for i in spawn_count:
			_spawn_enemy()

func _spawn_enemy() -> void:
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		Logger.warn("No free enemy slots available", "waves")
		return
	
	# Use cached player position from PlayerState autoload
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	
	# Choose enemy type randomly
	var enemy_type := _choose_enemy_type()
	
	var angle := RNG.randf_range("waves", 0.0, TAU)
	var spawn_pos := target_pos + Vector2.from_angle(angle) * spawn_radius
	var direction := (target_pos - spawn_pos).normalized()
	var speed := _get_enemy_speed(enemy_type)
	
	var enemy := enemies[free_idx]
	enemy["pos"] = spawn_pos
	enemy["vel"] = direction * speed
	enemy["hp"] = _get_enemy_hp(enemy_type)
	enemy["alive"] = true
	enemy["type"] = enemy_type
	_cache_dirty = true  # Mark cache as dirty when spawning

## Public method for manual enemy spawning (debug/testing)
func spawn_enemy_at(position: Vector2, enemy_type: String = "green_slime") -> bool:
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		return false
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	var direction := (target_pos - position).normalized()
	var speed := _get_enemy_speed(enemy_type)
	
	var enemy := enemies[free_idx]
	enemy["pos"] = position
	enemy["vel"] = direction * speed
	enemy["hp"] = _get_enemy_hp(enemy_type)
	enemy["alive"] = true
	enemy["type"] = enemy_type
	_cache_dirty = true  # Mark cache as dirty when spawning
	return true

func _find_free_enemy() -> int:
	# Start search from last known free index for better performance
	for i in range(_last_free_index, max_enemies):
		if not enemies[i]["alive"]:
			_last_free_index = i
			return i
	
	# If not found, search from beginning to last free index
	for i in range(0, _last_free_index):
		if not enemies[i]["alive"]:
			_last_free_index = i
			return i
	
	return -1

func _update_enemies(dt: float) -> void:
	# Use cached player position from PlayerState autoload
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	var update_distance: float = BalanceDB.get_waves_value("enemy_update_distance")
	
	# Only update alive enemies to improve performance
	var alive_enemies = get_alive_enemies()
	for enemy in alive_enemies:
		var dist_to_target: float = enemy["pos"].distance_to(target_pos)
		
		# Only update enemies within update distance for performance
		if dist_to_target <= update_distance:
			# Update enemy direction to always move toward player/center
			var direction: Vector2 = (target_pos - enemy["pos"]).normalized()
			var speed: float = enemy["vel"].length()
			enemy["vel"] = direction * speed
			enemy["pos"] += enemy["vel"] * dt
		
		# Kill enemy if it reaches target or goes out of bounds
		if dist_to_target < target_distance or _is_out_of_bounds(enemy["pos"]):
			enemy["alive"] = false
			_cache_dirty = true  # Mark cache as dirty when enemy dies

func _is_out_of_bounds(pos: Vector2) -> bool:
	return abs(pos.x) > arena_bounds or abs(pos.y) > arena_bounds

func get_alive_enemies() -> Array[Dictionary]:
	var current_frame = Engine.get_process_frames()
	
	# Use cached list if available and not dirty, or if already rebuilt this frame
	if (not _cache_dirty and not _alive_enemies_cache.is_empty()) or _last_cache_frame == current_frame:
		return _alive_enemies_cache
	
	# Rebuild cache - only once per frame maximum
	_alive_enemies_cache.clear()
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy["alive"]:
			# Only add pool index if not already set to avoid modifying original
			if not enemy.has("_pool_index"):
				enemy["_pool_index"] = i
			_alive_enemies_cache.append(enemy)
	
	_cache_dirty = false
	_last_cache_frame = current_frame
	return _alive_enemies_cache

# Player reference no longer needed - using PlayerState autoload for position

func damage_enemy(enemy_index: int, damage: float) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return
	
	enemy["hp"] -= damage
	if enemy["hp"] <= 0.0:
		var death_pos: Vector2 = enemy["pos"]
		enemy["alive"] = false
		_cache_dirty = true  # Mark cache as dirty when enemy dies from damage
		var payload := EventBus.EnemyKilledPayload.new(death_pos, 1)
		EventBus.enemy_killed.emit(payload)
