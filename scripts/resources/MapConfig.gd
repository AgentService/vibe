class_name MapConfig
extends Resource

## Configuration resource for arena maps
## Provides foundation for future Map/Arena System expansion
## Used by BaseArena extensions to configure arena-specific settings

@export_group("Basic Information")
@export var map_id: StringName = "" ## Unique identifier for this map
@export var display_name: String = "" ## Human-readable name for UI
@export var description: String = "" ## Brief description of the arena

@export_group("Visual Configuration")
@export var theme_tags: Array[StringName] = [] ## Visual theme tags (e.g., "underworld", "forest")
@export var ambient_light_color: Color = Color.WHITE ## Base ambient lighting
@export var ambient_light_energy: float = 0.3 ## Ambient light intensity
@export var background_music: AudioStream ## Background music for this arena

@export_group("Gameplay Configuration")
@export var arena_bounds_radius: float = 500.0 ## Radius for arena boundaries
@export var spawn_radius: float = 400.0 ## Radius for enemy spawning
@export var player_spawn_position: Vector2 = Vector2.ZERO ## Relative player spawn position

@export_group("Spawning Configuration")

@export_group("Proximity Spawning")
@export var auto_spawn_range: float = 800.0 ## Auto spawn proximity range (max distance)
@export var auto_spawn_min_distance: float = 300.0 ## Auto spawn minimum distance (prevent spawning too close)
# pack_spawn_range and pack_spawn_min_distance removed - pack spawning system eliminated
# use_viewport_culling and viewport_margin removed - unused in codebase
@export var activation_method: ActivationMethod = ActivationMethod.AREA_TRIGGERS ## Proximity detection method

enum ActivationMethod {
	AREA_TRIGGERS = 2     ## Area2D collision detection (zone-based spawning)
	# Future extensibility: Additional activation methods can be added here
}

# base_spawn_scaling removed - scattered scaling eliminated for unified DifficultyDirector

# arena_scaling_overrides removed - scattered scaling eliminated for unified DifficultyDirector

@export_group("Environmental Effects")
@export var has_environmental_hazards: bool = false ## Enable environmental damage/effects
@export var weather_effects: Array[StringName] = [] ## Weather/environmental effects
@export var special_mechanics: Array[StringName] = [] ## Special arena mechanics

@export_group("Event System")
@export var event_spawn_enabled: bool = true ## Enable event spawning in this arena
@export var event_spawn_interval: float = 45.0 ## Base seconds between event spawns
@export var available_events: Array[StringName] = ["breach", "ritual", "pack_hunt", "boss"] ## Event types available in this arena
@export var event_reward_multiplier: float = 3.0 ## Multiplier for event-based rewards
@export var event_zone_preference: Array[StringName] = [] ## Preferred zones for event spawning (empty = all zones)

@export_group("Future Expansion")
@export var tier_multipliers: Dictionary = {} ## Future tier scaling support
@export var modifier_support: Array[StringName] = [] ## Future modifier system support
@export var custom_properties: Dictionary = {} ## Extensible custom data



## Check if arena has specific theme
func has_theme(theme: StringName) -> bool:
	return theme_tags.has(theme)





# get_effective_scaling removed - scaling moved to unified DifficultyDirector system

# get_zones_in_pack_range removed - pack spawning system eliminated


## Get random event type from available events
func get_random_event_type() -> StringName:
	if available_events.is_empty():
		return ""
	return available_events[randi() % available_events.size()]

## Check if specific event type is available in this arena
func is_event_type_available(event_type: StringName) -> bool:
	return available_events.has(event_type)


## Validate configuration
func is_valid() -> bool:
	return map_id != "" and display_name != "" and arena_bounds_radius > 0.0
