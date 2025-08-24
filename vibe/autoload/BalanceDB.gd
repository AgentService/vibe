extends Node

## Balance database singleton that loads and caches all game balance data.
## Provides hot-reload capability and fallback values for missing data.

signal balance_reloaded()

var _combat_balance: CombatBalance
var _abilities_balance: AbilitiesBalance  
var _melee_balance: MeleeBalance
var _player_balance: PlayerBalance
var _waves_balance: WavesBalance

var _data: Dictionary = {}  # Still needed for UI files
var _fallback_data: Dictionary = {}

func _ready() -> void:
	_setup_fallback_data()
	load_all_balance_data()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		Logger.info("F5 pressed - Hot-reloading balance data...", "balance")
		reload_balance_data()
		Logger.info("Balance data reloaded successfully!", "balance")

func _setup_fallback_data() -> void:
	_fallback_data = {
		"combat": {
			"projectile_radius": 4.0,
			"enemy_radius": 12.0,
			"base_damage": 1.0,
			"crit_chance": 0.1,
			"crit_multiplier": 2.0
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
			"spawn_radius": 600.0,
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
			"lifesteal": 0.0
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
	_combat_balance = _load_resource("res://data/balance/combat_balance.tres", "combat")
	_abilities_balance = _load_resource("res://data/balance/abilities_balance.tres", "abilities")
	_melee_balance = _load_resource("res://data/balance/melee_balance.tres", "melee") 
	_player_balance = _load_resource("res://data/balance/player_balance.tres", "player")
	_waves_balance = _load_resource("res://data/balance/waves_balance.tres", "waves")

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
			return combat
		"abilities":
			var abilities: AbilitiesBalance = AbilitiesBalance.new()
			abilities.max_projectiles = fallback_data.get("max_projectiles", 1000)
			abilities.projectile_speed = fallback_data.get("projectile_speed", 300.0)
			abilities.projectile_ttl = fallback_data.get("projectile_ttl", 3.0)
			abilities.arena_bounds = fallback_data.get("arena_bounds", 2000.0)
			abilities.projectile_culling_distance = fallback_data.get("projectile_culling_distance", 1500.0)
			return abilities
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
			waves.spawn_radius = fallback_data.get("spawn_radius", 600.0)
			waves.spawn_radius_large = fallback_data.get("spawn_radius_large", 600.0)
			waves.spawn_radius_mega = fallback_data.get("spawn_radius_mega", 600.0)
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
		_:
			Logger.error("Unknown combat balance key: " + key, "balance")
			return _get_fallback_value("combat", key)

func get_abilities_value(key: String) -> Variant:
	if _abilities_balance == null:
		return _get_fallback_value("abilities", key)
	
	match key:
		"max_projectiles":
			return _abilities_balance.max_projectiles
		"projectile_speed":
			return _abilities_balance.projectile_speed
		"projectile_ttl":
			return _abilities_balance.projectile_ttl
		"arena_bounds":
			return _abilities_balance.arena_bounds
		"projectile_culling_distance":
			return _abilities_balance.projectile_culling_distance
		_:
			Logger.error("Unknown abilities balance key: " + key, "balance")
			return _get_fallback_value("abilities", key)

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
		"spawn_radius":
			return _waves_balance.spawn_radius
		"spawn_radius_large":
			return _waves_balance.spawn_radius_large
		"spawn_radius_mega":
			return _waves_balance.spawn_radius_mega
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
			return _melee_balance.range
		"cone_angle":
			return _melee_balance.cone_angle
		"attack_speed":
			return _melee_balance.attack_speed
		"visual_effect_duration":
			return _melee_balance.visual_effect_duration
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
	var radar_config: RadarConfigResource = load("res://data/ui/radar_config.tres")
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
		"dot_sizes": radar_config.get_dot_sizes()
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
	ResourceLoader.load("res://data/balance/combat_balance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/abilities_balance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/melee_balance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/player_balance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/balance/waves_balance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ResourceLoader.load("res://data/ui/radar_config.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	load_all_balance_data()
	Logger.info("Balance data reloaded successfully!", "balance")
