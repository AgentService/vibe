extends Node

## Balance database singleton that loads and caches all game balance data.
## Provides hot-reload capability and fallback values for missing data.

signal balance_reloaded()

var _combat_balance: CombatBalance
  
var _melee_balance: MeleeBalance
var _player_balance: PlayerBalance
var _waves_balance: WavesBalance

var _data: Dictionary = {}  # Still needed for UI files
var _fallback_data: Dictionary = {}

# Auto hot-reload file monitoring
var _file_watcher_timer: Timer
var _balance_files: Dictionary = {}  # path -> last_modified_time
const FILE_CHECK_INTERVAL: float = 0.5

func _ready() -> void:
	_setup_fallback_data()
	load_all_balance_data()
	_setup_auto_reload()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		Logger.info("F5 pressed - Hot-reloading balance data...", "balance")
		reload_balance_data()
		Logger.info("Balance data reloaded successfully!", "balance")

func _setup_auto_reload() -> void:
	# Setup file monitoring for all balance files
	# TO ADD NEW AUTO-RELOAD FILES: Add file path to this dictionary
	_balance_files = {
		"res://data/balance/combat.tres": 0,
		"res://data/balance/melee.tres": 0,
		"res://data/balance/player.tres": 0,
		"res://data/balance/waves.tres": 0,
		"res://data/ui.tres": 0
	}
	
	# Get initial timestamps
	for file_path in _balance_files:
		if FileAccess.file_exists(file_path):
			_balance_files[file_path] = FileAccess.get_modified_time(file_path)
	
	# Setup timer
	_file_watcher_timer = Timer.new()
	_file_watcher_timer.wait_time = FILE_CHECK_INTERVAL
	_file_watcher_timer.timeout.connect(_check_balance_files)
	add_child(_file_watcher_timer)
	_file_watcher_timer.start()
	
	Logger.info("Balance auto hot-reload monitoring started", "balance")

func _check_balance_files() -> void:
	for file_path in _balance_files:
		if not FileAccess.file_exists(file_path):
			continue
			
		var current_time = FileAccess.get_modified_time(file_path)
		if current_time > _balance_files[file_path]:
			Logger.info("Balance file changed: " + file_path.get_file(), "balance")
			_balance_files[file_path] = current_time
			reload_balance_data()
			Logger.info("Balance data auto-reloaded!", "balance")
			break  # Reload all at once, don't check remaining files this cycle

func _setup_fallback_data() -> void:
	_fallback_data = {
		"combat": {
			"projectile_radius": 4.0,
			"enemy_radius": 12.0,
			"base_damage": 1.0,
			"crit_chance": 0.1,
			"crit_multiplier": 2.0,
			"use_zero_alloc_damage_queue": true,
			"damage_queue_capacity": 4096,
			"damage_pool_size": 4096,
			"damage_queue_max_per_tick": 2048,
			"damage_queue_tick_rate_hz": 30.0
		},
		"abilities": {
			"max_projectiles": 1000,
			"projectile_speed": 300.0,
			"projectile_ttl": 3.0,
			"arena_bounds": 2000.0
		},
		"waves": {
			"max_enemies": 500,
			"spawn_interval": 1.0,
			"arena_center": {"x": 400.0, "y": 300.0},
			# spawn_radius moved to ArenaConfig
			"enemy_speed_min": 60.0,
			"enemy_speed_max": 120.0,
			"spawn_count_min": 3,
			"spawn_count_max": 6,
			"arena_bounds": 1500.0,
			"target_distance": 20.0
		},
		"player": {
			"projectile_count_add": 0,
			"projectile_speed_mult": 1.0,
			"fire_rate_mult": 1.0,
			"damage_mult": 1.0
		},
		"melee": {
			"damage": 55.0,
			"range": 100.0,
			"cone_angle": 90.0,
			"attack_speed": 2,
			"lifesteal": 0.0,
			"knockback_distance": 20.0
		},
		"ui": {
			"radar": {
				"radar_size": {"x": 150, "y": 150},
				"radar_range": 1500.0,
				"colors": {
					"background": {"r": 0.1, "g": 0.1, "b": 0.2, "a": 0.7},
					"border": {"r": 0.4, "g": 0.4, "b": 0.6, "a": 1.0},
					"player": {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0},
					"enemy": {"r": 0.8, "g": 0.2, "b": 0.2, "a": 1.0}
				},
				"dot_sizes": {
					"player": 4.0,
					"enemy_max": 3.0,
					"enemy_min": 1.5
				}
			}
		}
	}



func load_all_balance_data() -> void:
	_load_balance_resources()
	_load_radar_config()
	balance_reloaded.emit()

func _load_balance_resources() -> void:
	_combat_balance = _load_resource("res://data/balance/combat.tres", "combat")
	_melee_balance = _load_resource("res://data/balance/melee.tres", "melee") 
	_player_balance = _load_resource("res://data/balance/player.tres", "player")
	_waves_balance = _load_resource("res://data/balance/waves.tres", "waves")

func _load_resource(resource_path: String, fallback_key: String) -> Resource:
	var resource: Resource = ResourceLoader.load(resource_path)
	if resource == null:
		Logger.warn("Failed to load balance resource: " + resource_path + ". Creating fallback.", "balance")
		return _create_fallback_resource(fallback_key)
	
	Logger.info("Successfully loaded balance resource: " + resource_path, "balance")
	return resource

func _create_fallback_resource(key: String) -> Resource:
	var fallback_data: Dictionary = _fallback_data.get(key, {})
	
	match key:
		"combat":
			var combat: CombatBalance = CombatBalance.new()
			combat.projectile_radius = fallback_data.get("projectile_radius", 4.0)
			combat.enemy_radius = fallback_data.get("enemy_radius", 12.0)
			combat.base_damage = fallback_data.get("base_damage", 1.0)
			combat.crit_chance = fallback_data.get("crit_chance", 0.1)
			combat.crit_multiplier = fallback_data.get("crit_multiplier", 2.0)
			combat.use_zero_alloc_damage_queue = fallback_data.get("use_zero_alloc_damage_queue", true)
			combat.damage_queue_capacity = fallback_data.get("damage_queue_capacity", 4096)
			combat.damage_pool_size = fallback_data.get("damage_pool_size", 4096)
			combat.damage_queue_max_per_tick = fallback_data.get("damage_queue_max_per_tick", 2048)
			combat.damage_queue_tick_rate_hz = fallback_data.get("damage_queue_tick_rate_hz", 30.0)
			return combat
		"melee":
			var melee: MeleeBalance = MeleeBalance.new()
			melee.damage = fallback_data.get("damage", 55.0)
			melee.range = fallback_data.get("range", 100.0)
			melee.cone_angle = fallback_data.get("cone_angle", 90.0)
			melee.attack_speed = fallback_data.get("attack_speed", 2)
			melee.visual_effect_duration = fallback_data.get("visual_effect_duration", 0.5)
			return melee
		"player":
			var player: PlayerBalance = PlayerBalance.new()
			player.projectile_count_add = fallback_data.get("projectile_count_add", 0)
			player.projectile_speed_mult = fallback_data.get("projectile_speed_mult", 1.0)
			player.fire_rate_mult = fallback_data.get("fire_rate_mult", 1.0)
			player.damage_mult = fallback_data.get("damage_mult", 1.0)
			return player
		"waves":
			var waves: WavesBalance = WavesBalance.new()
			waves.max_enemies = fallback_data.get("max_enemies", 500)
			waves.spawn_interval = fallback_data.get("spawn_interval", 1.0)
			waves.arena_center = Vector2(400.0, 300.0)
			# spawn_radius properties moved to ArenaConfig
			waves.enemy_speed_min = fallback_data.get("enemy_speed_min", 60.0)
			waves.enemy_speed_max = fallback_data.get("enemy_speed_max", 120.0)
			waves.spawn_count_min = fallback_data.get("spawn_count_min", 3)
			waves.spawn_count_max = fallback_data.get("spawn_count_max", 6)
			waves.arena_bounds = fallback_data.get("arena_bounds", 1500.0)
			waves.target_distance = fallback_data.get("target_distance", 20.0)
			waves.enemy_culling_distance = fallback_data.get("enemy_culling_distance", 2000.0)
			waves.enemy_transform_cache_size = fallback_data.get("enemy_transform_cache_size", 100)
			waves.enemy_viewport_cull_margin = fallback_data.get("enemy_viewport_cull_margin", 100.0)
			waves.enemy_update_distance = fallback_data.get("enemy_update_distance", 2800.0)
			waves.camera_min_zoom = fallback_data.get("camera_min_zoom", 1.0)
			return waves
		_:
			Logger.error("Unknown balance resource key: " + key, "balance")
			return null


func get_combat_value(key: String) -> Variant:
	if _combat_balance == null:
		return _get_fallback_value("combat", key)
	
	match key:
		"projectile_radius":
			return _combat_balance.projectile_radius
		"enemy_radius":
			return _combat_balance.enemy_radius
		"base_damage":
			return _combat_balance.base_damage
		"crit_chance":
			return _combat_balance.crit_chance
		"crit_multiplier":
			return _combat_balance.crit_multiplier
		"use_zero_alloc_damage_queue":
			return _combat_balance.use_zero_alloc_damage_queue
		"damage_queue_capacity":
			return _combat_balance.damage_queue_capacity
		"damage_pool_size":
			return _combat_balance.damage_pool_size
		"damage_queue_max_per_tick":
			return _combat_balance.damage_queue_max_per_tick
		"damage_queue_tick_rate_hz":
			return _combat_balance.damage_queue_tick_rate_hz
		_:
			Logger.error("Unknown combat balance key: " + key, "balance")
			return _get_fallback_value("combat", key)


func get_waves_value(key: String) -> Variant:
	if _waves_balance == null:
		return _get_fallback_value("waves", key)
	
	match key:
		"max_enemies":
			return _waves_balance.max_enemies
		"spawn_interval":
			return _waves_balance.spawn_interval
		"arena_center":
			return _waves_balance.arena_center
		# spawn_radius getters removed - use ArenaSystem instead
		"enemy_speed_min":
			return _waves_balance.enemy_speed_min
		"enemy_speed_max":
			return _waves_balance.enemy_speed_max
		"spawn_count_min":
			return _waves_balance.spawn_count_min
		"spawn_count_max":
			return _waves_balance.spawn_count_max
		"arena_bounds":
			return _waves_balance.arena_bounds
		"target_distance":
			return _waves_balance.target_distance
		"enemy_culling_distance":
			return _waves_balance.enemy_culling_distance
		"enemy_transform_cache_size":
			return _waves_balance.enemy_transform_cache_size
		"enemy_viewport_cull_margin":
			return _waves_balance.enemy_viewport_cull_margin
		"enemy_update_distance":
			return _waves_balance.enemy_update_distance
		"camera_min_zoom":
			return _waves_balance.camera_min_zoom
		_:
			Logger.error("Unknown waves balance key: " + key, "balance")
			return _get_fallback_value("waves", key)

## Enemy V2 System Configuration
func get_use_enemy_v2_system() -> bool:
	if _waves_balance == null:
		return false
	return _waves_balance.use_enemy_v2_system

func get_v2_template_weights() -> Dictionary:
	if _waves_balance == null:
		return {}
	return _waves_balance.v2_template_weights

# Convenience property getter for V2 system
var use_enemy_v2_system: bool:
	get:
		return get_use_enemy_v2_system()

func _get_waves_fallback_value(key: String):
	# Continue with fallback case
	match key:
		_:
			Logger.error("Unknown waves balance key: " + key, "balance")
			return _get_fallback_value("waves", key)

func get_player_value(key: String) -> Variant:
	if _player_balance == null:
		return _get_fallback_value("player", key)
	
	match key:
		"projectile_count_add":
			return _player_balance.projectile_count_add
		"projectile_speed_mult":
			return _player_balance.projectile_speed_mult
		"fire_rate_mult":
			return _player_balance.fire_rate_mult
		"damage_mult":
			return _player_balance.damage_mult
		_:
			Logger.error("Unknown player balance key: " + key, "balance")
			return _get_fallback_value("player", key)

func get_melee_value(key: String) -> Variant:
	if _melee_balance == null:
		return _get_fallback_value("melee", key)
	
	match key:
		"damage":
			return _melee_balance.damage
		"range":
			return _melee_balance.attack_range
		"cone_angle":
			return _melee_balance.cone_angle
		"attack_speed":
			return _melee_balance.attack_speed
		"visual_effect_duration":
			return _melee_balance.visual_effect_duration
		"knockback_distance":
			return _melee_balance.knockback_distance
		_:
			Logger.error("Unknown melee balance key: " + key, "balance")
			return _get_fallback_value("melee", key)

func get_ui_value(key: String) -> Variant:
	return _get_value("ui", key)

func _load_ui_file(filename: String) -> void:
	var file_path: String = "res://data/ui/" + filename + ".json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		push_warning("UI file not found: " + file_path + ". Using fallback values.")
		if not _data.has("ui"):
			_data["ui"] = {}
		_data["ui"][filename] = _fallback_data.get("ui", {}).get(filename, {})
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse UI JSON: " + file_path + ". Using fallback values.")
		if not _data.has("ui"):
			_data["ui"] = {}
		_data["ui"][filename] = _fallback_data.get("ui", {}).get(filename, {})
		return
	
	# Load the UI data (no validation needed for simple UI configs)
	var data: Dictionary = json.data
	
	if not _data.has("ui"):
		_data["ui"] = {}
	_data["ui"][filename] = data
	Logger.info("Successfully loaded and validated: ui/" + filename + ".json", "balance")

func _load_radar_config() -> void:
	var radar_config: RadarConfigResource = load("res://data/ui.tres")
	if radar_config == null:
		Logger.warn("Failed to load radar config resource. Using fallback values.", "balance")
		if not _data.has("ui"):
			_data["ui"] = {}
		_data["ui"]["radar"] = _fallback_data.get("ui", {}).get("radar", {})
		return
	
	# Convert resource to dictionary format for compatibility
	var radar_data: Dictionary = {
		"radar_size": radar_config.get_radar_size(),
		"radar_range": radar_config.radar_range,
		"colors": radar_config.get_colors(),
		"dot_sizes": radar_config.get_dot_sizes(),
		"emit_hz": radar_config.emit_hz,
		"use_new_radar_system": radar_config.use_new_radar_system
	}
	
	if not _data.has("ui"):
		_data["ui"] = {}
	_data["ui"]["radar"] = radar_data
	Logger.info("Successfully loaded radar config resource", "balance")

func _get_value(category: String, key: String) -> Variant:
	var category_data: Dictionary = _data.get(category, {})
	if category_data.has(key):
		return category_data[key]
	
	var fallback_category: Dictionary = _fallback_data.get(category, {})
	if fallback_category.has(key):
		push_warning("Using fallback value for " + category + "." + key)
		return fallback_category[key]
	
	push_error("Balance value not found: " + category + "." + key)
	return null

func _get_fallback_value(category: String, key: String) -> Variant:
	var fallback_category: Dictionary = _fallback_data.get(category, {})
	if fallback_category.has(key):
		Logger.warn("Using fallback value for " + category + "." + key, "balance")
		return fallback_category[key]
	
	Logger.error("Balance value not found: " + category + "." + key, "balance")
	return null

func reload_balance_data() -> void:
	Logger.info("F5 pressed - Hot-reloading balance data...", "balance")
	ResourceLoader.load("res://data/balance/combat.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/melee.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/player.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/waves.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/ui.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	load_all_balance_data()
	Logger.info("Balance data reloaded successfully!", "balance")
