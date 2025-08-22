extends Node

## Balance database singleton that loads and caches all game balance data.
## Provides hot-reload capability and fallback values for missing data.

signal balance_reloaded()

var _data: Dictionary = {}
var _fallback_data: Dictionary = {}
var _schemas: Dictionary = {}

func _ready() -> void:
	_setup_fallback_data()
	_setup_schemas()
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

func _setup_schemas() -> void:
	_schemas = {
		"combat": {
			"required": {
				"projectile_radius": TYPE_FLOAT,
				"enemy_radius": TYPE_FLOAT,
				"base_damage": TYPE_FLOAT,
				"crit_chance": TYPE_FLOAT,
				"crit_multiplier": TYPE_FLOAT
			},
			"optional": {
				"_schema_version": TYPE_STRING,
				"_description": TYPE_STRING
			},
			"ranges": {
				"projectile_radius": {"min": 0.1, "max": 50.0},
				"enemy_radius": {"min": 0.1, "max": 100.0},
				"base_damage": {"min": 0.1, "max": 1000.0},
				"crit_chance": {"min": 0.0, "max": 1.0},
				"crit_multiplier": {"min": 1.0, "max": 10.0}
			}
		},
		"abilities": {
			"required": {
				"max_projectiles": TYPE_INT,
				"projectile_speed": TYPE_FLOAT,
				"projectile_ttl": TYPE_FLOAT,
				"arena_bounds": TYPE_FLOAT
			},
			"optional": {
				"projectile_culling_distance": TYPE_FLOAT,
				"_schema_version": TYPE_STRING,
				"_description": TYPE_STRING
			},
			"ranges": {
				"max_projectiles": {"min": 1, "max": 10000},
				"projectile_speed": {"min": 1.0, "max": 5000.0},
				"projectile_ttl": {"min": 0.1, "max": 60.0},
				"arena_bounds": {"min": 100.0, "max": 10000.0},
				"projectile_culling_distance": {"min": 100.0, "max": 10000.0}
			}
		},
		"waves": {
			"required": {
				"max_enemies": TYPE_INT,
				"spawn_interval": TYPE_FLOAT,
				"arena_center": TYPE_DICTIONARY,
				"spawn_radius": TYPE_FLOAT,
				"enemy_speed_min": TYPE_FLOAT,
				"enemy_speed_max": TYPE_FLOAT,
				"spawn_count_min": TYPE_INT,
				"spawn_count_max": TYPE_INT,
				"arena_bounds": TYPE_FLOAT,
				"target_distance": TYPE_FLOAT
			},
			"optional": {
				"spawn_radius_large": TYPE_FLOAT,
				"spawn_radius_mega": TYPE_FLOAT,
				"enemy_culling_distance": TYPE_FLOAT,
				"enemy_transform_cache_size": TYPE_INT,
				"enemy_viewport_cull_margin": TYPE_FLOAT,
				"enemy_update_distance": TYPE_FLOAT,
				"camera_min_zoom": TYPE_FLOAT,
				"_schema_version": TYPE_STRING,
				"_description": TYPE_STRING
			},
			"ranges": {
				"max_enemies": {"min": 1, "max": 10000},
				"spawn_interval": {"min": 0.1, "max": 60.0},
				"spawn_radius": {"min": 10.0, "max": 5000.0},
				"spawn_radius_large": {"min": 10.0, "max": 5000.0},
				"spawn_radius_mega": {"min": 10.0, "max": 5000.0},
				"enemy_speed_min": {"min": 1.0, "max": 1000.0},
				"enemy_speed_max": {"min": 1.0, "max": 1000.0},
				"spawn_count_min": {"min": 1, "max": 100},
				"spawn_count_max": {"min": 1, "max": 100},
				"arena_bounds": {"min": 100.0, "max": 10000.0},
				"target_distance": {"min": 1.0, "max": 500.0},
				"enemy_culling_distance": {"min": 100.0, "max": 10000.0},
				"enemy_transform_cache_size": {"min": 100, "max": 20000},
				"enemy_viewport_cull_margin": {"min": 0.0, "max": 1000.0},
				"enemy_update_distance": {"min": 100.0, "max": 10000.0},
				"camera_min_zoom": {"min": 0.1, "max": 2.0}
			},
			"nested": {
				"arena_center": {
					"required": {"x": TYPE_FLOAT, "y": TYPE_FLOAT}
				}
			}
		},
		"player": {
			"required": {
				"projectile_count_add": TYPE_INT,
				"projectile_speed_mult": TYPE_FLOAT,
				"fire_rate_mult": TYPE_FLOAT,
				"damage_mult": TYPE_FLOAT
			},
			"optional": {
				"_schema_version": TYPE_STRING,
				"_description": TYPE_STRING
			},
			"ranges": {
				"projectile_count_add": {"min": 0, "max": 100},
				"projectile_speed_mult": {"min": 0.1, "max": 10.0},
				"fire_rate_mult": {"min": 0.1, "max": 10.0},
				"damage_mult": {"min": 0.1, "max": 10.0}
			}
		},
		"ui.radar": {
			"required": {
				"radar_size": TYPE_DICTIONARY,
				"radar_range": TYPE_FLOAT,
				"colors": TYPE_DICTIONARY,
				"dot_sizes": TYPE_DICTIONARY
			},
			"optional": {
				"_schema_version": TYPE_STRING,
				"_description": TYPE_STRING
			},
			"ranges": {
				"radar_range": {"min": 100.0, "max": 10000.0}
			},
			"nested": {
				"radar_size": {
					"required": {"x": TYPE_INT, "y": TYPE_INT}
				},
				"colors": {
					"required": {
						"background": TYPE_DICTIONARY,
						"border": TYPE_DICTIONARY,
						"player": TYPE_DICTIONARY,
						"enemy": TYPE_DICTIONARY
					}
				},
				"dot_sizes": {
					"required": {
						"player": TYPE_FLOAT,
						"enemy_max": TYPE_FLOAT,
						"enemy_min": TYPE_FLOAT
					}
				}
			}
		}
	}

func _validate_data(data: Dictionary, schema_key: String) -> bool:
	var schema: Dictionary = _schemas.get(schema_key, {})
	if schema.is_empty():
		push_warning("No schema defined for: " + schema_key)
		return true
	
	var validation_passed: bool = true
	var required_fields: Dictionary = schema.get("required", {})
	var optional_fields: Dictionary = schema.get("optional", {})
	var ranges: Dictionary = schema.get("ranges", {})
	var nested_schemas: Dictionary = schema.get("nested", {})
	
	# Check required fields
	for field_name in required_fields:
		if not data.has(field_name):
			push_error("Missing required field '" + field_name + "' in " + schema_key + " data")
			validation_passed = false
			continue
		
		var expected_type: Variant.Type = required_fields[field_name]
		var actual_type: Variant.Type = typeof(data[field_name])
		
		# Allow float-to-int conversion for numeric types
		if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
			# Convert float to int if it's a whole number
			var float_val: float = data[field_name]
			if float_val == floor(float_val):
				# This is acceptable - JSON often parses integers as floats
				pass
			else:
				push_error("Invalid value for '" + field_name + "' in " + schema_key + " data. Expected integer, got float with decimal: " + str(float_val))
				validation_passed = false
				continue
		elif actual_type != expected_type:
			push_error("Invalid type for '" + field_name + "' in " + schema_key + " data. Expected " + type_string(expected_type) + ", got " + type_string(actual_type))
			validation_passed = false
			continue
		
		# Check ranges if defined
		if ranges.has(field_name):
			var range_config: Dictionary = ranges[field_name]
			var value: Variant = data[field_name]
			
			if range_config.has("min") and value < range_config["min"]:
				push_error("Value for '" + field_name + "' (" + str(value) + ") below minimum (" + str(range_config["min"]) + ") in " + schema_key + " data")
				validation_passed = false
			
			if range_config.has("max") and value > range_config["max"]:
				push_error("Value for '" + field_name + "' (" + str(value) + ") above maximum (" + str(range_config["max"]) + ") in " + schema_key + " data")
				validation_passed = false
		
		# Check nested structure
		if nested_schemas.has(field_name) and actual_type == TYPE_DICTIONARY:
			var nested_validation: bool = _validate_nested_data(data[field_name], nested_schemas[field_name], schema_key + "." + field_name)
			if not nested_validation:
				validation_passed = false
	
	# Check for unexpected fields (potential typos)
	var all_expected_fields: Dictionary = required_fields.duplicate()
	all_expected_fields.merge(optional_fields)
	
	for field_name in data:
		if not all_expected_fields.has(field_name):
			push_warning("Unexpected field '" + field_name + "' in " + schema_key + " data (possible typo?)")
	
	# Validate optional fields if present
	for field_name in optional_fields:
		if data.has(field_name):
			var expected_type: Variant.Type = optional_fields[field_name]
			var actual_type: Variant.Type = typeof(data[field_name])
			
			# Allow float-to-int conversion for numeric types
			if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
				var float_val: float = data[field_name]
				if float_val != floor(float_val):
					push_error("Invalid value for optional field '" + field_name + "' in " + schema_key + " data. Expected integer, got float with decimal: " + str(float_val))
					validation_passed = false
			elif actual_type != expected_type:
				push_error("Invalid type for optional field '" + field_name + "' in " + schema_key + " data. Expected " + type_string(expected_type) + ", got " + type_string(actual_type))
				validation_passed = false
	
	return validation_passed

func _validate_nested_data(data: Dictionary, nested_schema: Dictionary, context: String) -> bool:
	var validation_passed: bool = true
	var required_fields: Dictionary = nested_schema.get("required", {})
	
	for field_name in required_fields:
		if not data.has(field_name):
			push_error("Missing required nested field '" + field_name + "' in " + context)
			validation_passed = false
			continue
		
		var expected_type: Variant.Type = required_fields[field_name]
		var actual_type: Variant.Type = typeof(data[field_name])
		
		# Allow float-to-int conversion for numeric types
		if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
			var float_val: float = data[field_name]
			if float_val != floor(float_val):
				push_error("Invalid value for nested field '" + field_name + "' in " + context + ". Expected integer, got float with decimal: " + str(float_val))
				validation_passed = false
		elif actual_type != expected_type:
			push_error("Invalid type for nested field '" + field_name + "' in " + context + ". Expected " + type_string(expected_type) + ", got " + type_string(actual_type))
			validation_passed = false
	
	return validation_passed

func load_all_balance_data() -> void:
	_data.clear()
	_load_balance_file("combat")
	_load_balance_file("abilities") 
	_load_balance_file("waves")
	_load_balance_file("player")
	_load_balance_file("melee")
	_load_ui_file("radar")
	balance_reloaded.emit()

func _load_balance_file(filename: String) -> void:
	var file_path: String = "res://data/balance/" + filename + ".json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		push_warning("Balance file not found: " + file_path + ". Using fallback values.")
		_data[filename] = _fallback_data.get(filename, {})
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse balance JSON: " + file_path + ". Using fallback values.")
		_data[filename] = _fallback_data.get(filename, {})
		return
	
	# Validate the loaded data
	var data: Dictionary = json.data
	if not _validate_data(data, filename):
		push_error("Schema validation failed for: " + file_path + ". Using fallback values.")
		_data[filename] = _fallback_data.get(filename, {})
		return
	
	_data[filename] = data
	Logger.info("Successfully loaded and validated: " + filename + ".json", "balance")

func get_combat_value(key: String) -> Variant:
	return _get_value("combat", key)

func get_abilities_value(key: String) -> Variant:
	return _get_value("abilities", key)

func get_waves_value(key: String) -> Variant:
	return _get_value("waves", key)

func get_player_value(key: String) -> Variant:
	return _get_value("player", key)

func get_melee_value(key: String) -> Variant:
	return _get_value("melee", key)

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
	
	# Validate the loaded UI data
	var data: Dictionary = json.data
	var schema_key: String = "ui." + filename
	if not _validate_data(data, schema_key):
		push_error("Schema validation failed for: " + file_path + ". Using fallback values.")
		if not _data.has("ui"):
			_data["ui"] = {}
		_data["ui"][filename] = _fallback_data.get("ui", {}).get(filename, {})
		return
	
	if not _data.has("ui"):
		_data["ui"] = {}
	_data["ui"][filename] = data
	Logger.info("Successfully loaded and validated: ui/" + filename + ".json", "balance")

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

func reload_balance_data() -> void:
	Logger.info("F5 pressed - Hot-reloading balance data...", "balance")
	load_all_balance_data()
	Logger.info("Balance data reloaded successfully!", "balance")
