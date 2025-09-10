extends Resource

class_name LogConfigResource

## Log configuration resource for type-safe logger settings
## Replaces log_config.json with proper type validation

@export_enum("DEBUG", "INFO", "WARN", "ERROR") var log_level: String = "DEBUG"

# Category enable/disable flags for filtering
@export_group("Categories")
@export var balance: bool = true
@export var combat: bool = true
@export var waves: bool = true
@export var player: bool = true
@export var ui: bool = true
@export var abilities: bool = true
@export var signals: bool = true
@export var performance: bool = false
@export var debug: bool = true
@export var radar: bool = false

## Get category state as dictionary for compatibility with Logger
func get_categories() -> Dictionary:
	return {
		"balance": balance,
		"combat": combat,
		"waves": waves,
		"player": player,
		"ui": ui,
		"abilities": abilities,
		"signals": signals,
		"performance": performance,
		"debug": debug,
		"radar": radar
	}

## Validate log level is valid
func is_valid_log_level() -> bool:
	return log_level in ["DEBUG", "INFO", "WARN", "ERROR"]
