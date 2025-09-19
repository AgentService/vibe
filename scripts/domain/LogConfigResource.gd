extends Resource

class_name LogConfigResource

## Log configuration resource for type-safe logger settings
## Replaces log_config.json with proper type validation

@export_enum("DEBUG", "INFO", "WARN", "ERROR") var log_level: String = "DEBUG"

# Category enable/disable flags for filtering
@export_group("Core Systems")
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
@export var camera: bool = false
@export var arena: bool = true

@export_group("Game Systems")
@export var events: bool = true ## EventMasterySystem, SpawnDirector event spawning
@export var system: bool = true ## EntityClearingService, general system operations
@export var progression: bool = true ## PlayerProgression, XP and level system
@export var input: bool = false ## ArenaInputHandler, input processing
@export var session: bool = false ## Session management, player registration

## Get category state as dictionary for compatibility with Logger
func get_categories() -> Dictionary:
	return {
		# Core Systems
		"balance": balance,
		"combat": combat,
		"waves": waves,
		"player": player,
		"ui": ui,
		"abilities": abilities,
		"signals": signals,
		"performance": performance,
		"debug": debug,
		"radar": radar,
		"camera": camera,
		"arena": arena,

		# Game Systems
		"events": events,
		"system": system,
		"progression": progression,
		"input": input,
		"session": session
	}

## Validate log level is valid
func is_valid_log_level() -> bool:
	return log_level in ["DEBUG", "INFO", "WARN", "ERROR"]
