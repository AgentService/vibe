extends Node

## Centralized logging system with optional categories and configurable log levels.
## Supports hot-reload configuration and F6 debug toggle for rapid development.

enum LogLevel { DEBUG, INFO, WARN, ERROR, NONE }

var current_level: LogLevel = LogLevel.DEBUG
var enabled_categories: Dictionary = {}
var config_path: String = "res://data/debug/log_config.tres"

func _ready() -> void:
	_load_config()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_config)

func _exit_tree() -> void:
	# Cleanup signal connections
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_load_config):
		BalanceDB.balance_reloaded.disconnect(_load_config)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
		toggle_debug_mode()

func debug(msg: String, category: String = "") -> void:
	_log(LogLevel.DEBUG, msg, category)

func info(msg: String, category: String = "") -> void:
	_log(LogLevel.INFO, msg, category)

func warn(msg: String, category: String = "") -> void:
	_log(LogLevel.WARN, msg, category)
	
func error(msg: String, category: String = "") -> void:
	_log(LogLevel.ERROR, msg, category)

func _log(level: LogLevel, msg: String, category: String) -> void:
	if level < current_level:
		return
	
	# Category filtering - if no category defined, all are enabled
	if not enabled_categories.is_empty() and category != "":
		if not enabled_categories.get(category, false):
			return
	
	var prefix: String = _get_prefix(level, category)
	
	match level:
		LogLevel.ERROR:
			push_error(prefix + msg)
		LogLevel.WARN:
			push_warning(prefix + msg)
		_:
			print(prefix + msg)

func _get_prefix(level: LogLevel, category: String) -> String:
	var level_str: String = ["DEBUG", "INFO", "WARN", "ERROR", "NONE"][level]
	
	if category != "":
		return "[%s:%s] " % [level_str, category.to_upper()]
	else:
		return "[%s] " % level_str

func toggle_debug_mode() -> void:
	if current_level == LogLevel.DEBUG:
		current_level = LogLevel.INFO
		info("Log level set to INFO")
	else:
		current_level = LogLevel.DEBUG
		info("Log level set to DEBUG")

func set_level(level: LogLevel) -> void:
	current_level = level
	info("Log level set to: " + ["DEBUG", "INFO", "WARN", "ERROR", "NONE"][level])

func is_debug() -> bool:
	return current_level <= LogLevel.DEBUG

func _load_config() -> void:
	var config_resource: LogConfigResource = load(config_path)
	if config_resource == null:
		warn("Failed to load log config resource: " + config_path)
		return
	
	# Validate resource
	if not config_resource.is_valid_log_level():
		warn("Invalid log level in config: " + config_resource.log_level)
		return
	
	# Load log level
	var old_level: LogLevel = current_level
	current_level = _parse_level(config_resource.log_level)
	
	# Load categories
	enabled_categories = config_resource.get_categories()
	
	if old_level != current_level:
		info("Log level updated from config: " + config_resource.log_level)

func _parse_level(level_str: String) -> LogLevel:
	match level_str.to_upper():
		"DEBUG": return LogLevel.DEBUG
		"INFO": return LogLevel.INFO
		"WARN": return LogLevel.WARN
		"ERROR": return LogLevel.ERROR
		"NONE": return LogLevel.NONE
		_: return LogLevel.INFO
