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
@export var spawn_zones: Array[Dictionary] = [] ## Spawn zone definitions [{name: String, position: Vector2, radius: float, weight: float}]
@export var boss_spawn_positions: Array[Vector2] = [] ## Predefined boss spawn locations
@export var max_concurrent_enemies: int = 50 ## Maximum enemies alive at once

@export_group("Environmental Effects")
@export var has_environmental_hazards: bool = false ## Enable environmental damage/effects
@export var weather_effects: Array[StringName] = [] ## Weather/environmental effects
@export var special_mechanics: Array[StringName] = [] ## Special arena mechanics

@export_group("Future Expansion")
@export var tier_multipliers: Dictionary = {} ## Future tier scaling support
@export var modifier_support: Array[StringName] = [] ## Future modifier system support
@export var custom_properties: Dictionary = {} ## Extensible custom data

## Get spawn zone by name
func get_spawn_zone(zone_name: String) -> Dictionary:
	for zone in spawn_zones:
		if zone.get("name", "") == zone_name:
			return zone
	return {}

## Get random boss spawn position
func get_random_boss_spawn() -> Vector2:
	if boss_spawn_positions.is_empty():
		return Vector2.ZERO
	return boss_spawn_positions[randi() % boss_spawn_positions.size()]

## Check if arena has specific theme
func has_theme(theme: StringName) -> bool:
	return theme_tags.has(theme)

## Get weighted spawn zone (for future spawn system integration)
func get_weighted_spawn_zone() -> Dictionary:
	if spawn_zones.is_empty():
		return {}
	
	var total_weight: float = 0.0
	for zone in spawn_zones:
		total_weight += zone.get("weight", 1.0)
	
	var random_value: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for zone in spawn_zones:
		current_weight += zone.get("weight", 1.0)
		if random_value <= current_weight:
			return zone
	
	return spawn_zones[0]  # Fallback to first zone

## Validate configuration
func is_valid() -> bool:
	return map_id != "" and display_name != "" and arena_bounds_radius > 0.0
