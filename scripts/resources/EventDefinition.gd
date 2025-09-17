class_name EventDefinition
extends Resource

## Data-driven event configuration resource for the Event System.
## Defines event properties, spawning parameters, and reward configuration.
## Used by EventMasterySystem to spawn and configure events with mastery modifiers.

@export_group("Basic Information")
@export var id: StringName = "" ## Unique identifier for this event type
@export var display_name: String = "" ## Human-readable name for UI display
@export var description: String = "" ## Brief description of event mechanics
@export var event_type: StringName = "" ## Event category: "breach", "ritual", "pack_hunt", "boss"

@export_group("Event Configuration")
@export var duration: float = 30.0 ## Base duration in seconds (can be modified by passives)
@export var base_config: Dictionary = {
	"monster_count": 8,          # Base number of enemies to spawn
	"spawn_interval": 2.0,       # Seconds between enemy spawns
	"xp_multiplier": 3.0,        # XP reward multiplier vs normal enemies
	"formation": "circle"        # Formation type for enemy placement
} ## Base spawning and gameplay parameters

@export_group("Reward Configuration")
@export var reward_config: Dictionary = {
	"mastery_points": 1,         # Mastery points awarded for completion
	"xp_bonus": 1.5,            # Additional XP multiplier bonus
	"loot_chance": 0.15         # Chance for special loot drops
} ## Rewards for completing this event

@export_group("Visual Configuration")
@export var visual_config: Dictionary = {
	"spawn_effect": "portal",    # Visual effect when event starts
	"completion_effect": "burst", # Visual effect when event completes
	"ui_color": Color.CYAN,      # UI color theme for this event type
	"icon_path": ""              # Path to event icon for UI
} ## Visual and UI presentation settings

## Get configuration value with fallback
func get_config_value(key: String, fallback = null):
	return base_config.get(key, fallback)

## Get reward value with fallback
func get_reward_value(key: String, fallback = null):
	return reward_config.get(key, fallback)

## Get visual value with fallback
func get_visual_value(key: String, fallback = null):
	return visual_config.get(key, fallback)

## Apply mastery modifier to base configuration
func apply_mastery_modifier(modifier_key: String, multiplier: float) -> Dictionary:
	var modified_config = base_config.duplicate()

	if modified_config.has(modifier_key):
		var current_value = modified_config[modifier_key]
		if current_value is int:
			modified_config[modifier_key] = int(current_value * multiplier)
		elif current_value is float:
			modified_config[modifier_key] = current_value * multiplier

	return modified_config

## Get event display information for UI
func get_display_info() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"description": description,
		"type": event_type,
		"duration": duration,
		"color": visual_config.get("ui_color", Color.WHITE)
	}

## Validate event definition
func is_valid() -> bool:
	# Required fields check
	if id == "" or display_name == "" or event_type == "":
		return false

	# Duration must be positive
	if duration <= 0.0:
		return false

	# Event type must be one of the supported types
	var valid_types = ["breach", "ritual", "pack_hunt", "boss"]
	if not valid_types.has(event_type):
		return false

	# Base config must have required keys
	var required_config_keys = ["monster_count", "spawn_interval", "xp_multiplier"]
	for key in required_config_keys:
		if not base_config.has(key):
			return false

	return true

## Create a copy with applied modifiers (for runtime use)
func create_modified_copy(modifiers: Dictionary) -> EventDefinition:
	var copy = EventDefinition.new()
	copy.id = id
	copy.display_name = display_name
	copy.description = description
	copy.event_type = event_type
	copy.duration = duration
	copy.base_config = base_config.duplicate()
	copy.reward_config = reward_config.duplicate()
	copy.visual_config = visual_config.duplicate()

	# Apply modifiers
	for modifier_key in modifiers:
		var modifier_value = modifiers[modifier_key]
		if copy.base_config.has(modifier_key):
			copy.base_config[modifier_key] = modifier_value
		elif modifier_key == "duration":
			copy.duration = modifier_value

	return copy