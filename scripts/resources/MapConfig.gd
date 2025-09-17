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

@export_group("Proximity Spawning")
@export var auto_spawn_range: float = 800.0 ## Auto spawn proximity range (max distance)
@export var auto_spawn_min_distance: float = 300.0 ## Auto spawn minimum distance (prevent spawning too close)
@export var pack_spawn_range: float = 1600.0 ## Pack pre-spawn proximity range (max distance, out of view)
@export var pack_spawn_min_distance: float = 800.0 ## Pack spawn minimum distance (prefer off-screen spawning)
@export var use_viewport_culling: bool = false ## Additional viewport-based culling for performance
@export var viewport_margin: float = 200.0 ## Extra margin around viewport for spawn culling
@export var activation_method: ActivationMethod = ActivationMethod.DISTANCE ## Proximity detection method

enum ActivationMethod {
	DISTANCE,           ## Simple radius check around player
	VIEWPORT,          ## Camera frustum + margin
	AREA_TRIGGERS,     ## Area2D collision detection
	HYBRID             ## Distance + viewport combined
}

@export_group("Base Spawn Scaling")
@export var base_spawn_scaling: Dictionary = {
	"time_scaling_rate": 0.1,        # 10% per minute base
	"wave_scaling_rate": 0.15,       # 15% per wave base
	"pack_base_size_min": 5,
	"pack_base_size_max": 10,
	"max_scaling_multiplier": 2.5,
	"pack_spawn_interval": 5.0      # Seconds between pack spawns
}

@export_group("Arena-Specific Scaling")
@export var arena_scaling_overrides: Dictionary = {} ## Override any base scaling values per arena

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

## Get zones within range of player position
func get_zones_in_range(player_pos: Vector2, range_override: float = -1.0) -> Array[Dictionary]:
	var check_range = range_override if range_override > 0.0 else auto_spawn_range
	var zones_in_range: Array[Dictionary] = []

	for zone in spawn_zones:
		var zone_pos = zone.get("position", Vector2.ZERO)
		var distance = player_pos.distance_to(zone_pos)

		if distance <= check_range:
			zones_in_range.append(zone)

	return zones_in_range

## Check if specific zone is in range of player (uses auto spawn range)
func is_zone_in_range(zone_name: String, player_pos: Vector2) -> bool:
	var zone_data = get_spawn_zone(zone_name)
	if zone_data.is_empty():
		return false

	var zone_pos = zone_data.get("position", Vector2.ZERO)
	return player_pos.distance_to(zone_pos) <= auto_spawn_range

## Get weighted spawn zone from only zones in player range
func get_weighted_spawn_zone_in_range(player_pos: Vector2) -> Dictionary:
	var zones_in_range = get_zones_in_range(player_pos)

	if zones_in_range.is_empty():
		return {}

	# Apply same weighted selection logic but only to zones in range
	var total_weight: float = 0.0
	for zone in zones_in_range:
		total_weight += zone.get("weight", 1.0)

	var random_value: float = randf() * total_weight
	var current_weight: float = 0.0

	for zone in zones_in_range:
		current_weight += zone.get("weight", 1.0)
		if random_value <= current_weight:
			return zone

	return zones_in_range[0]  # Fallback to first zone in range

## Get effective scaling combining base + arena overrides
func get_effective_scaling() -> Dictionary:
	var effective = base_spawn_scaling.duplicate()
	for key in arena_scaling_overrides:
		effective[key] = arena_scaling_overrides[key]
	return effective

## Get zones within pack spawn range (larger range for pre-spawning)
func get_zones_in_pack_range(player_pos: Vector2) -> Array[Dictionary]:
	return get_zones_in_range(player_pos, pack_spawn_range)

## Get zones within auto spawn range (smaller range for immediate spawning)
func get_zones_in_auto_range(player_pos: Vector2) -> Array[Dictionary]:
	return get_zones_in_range(player_pos, auto_spawn_range)

## Get random event type from available events
func get_random_event_type() -> StringName:
	if available_events.is_empty():
		return ""
	return available_events[randi() % available_events.size()]

## Check if specific event type is available in this arena
func is_event_type_available(event_type: StringName) -> bool:
	return available_events.has(event_type)

## Get zones suitable for event spawning (considers preferences)
func get_event_spawn_zones(all_zones: Array[Dictionary]) -> Array[Dictionary]:
	if event_zone_preference.is_empty():
		return all_zones

	var preferred_zones: Array[Dictionary] = []
	for zone in all_zones:
		var zone_name = zone.get("name", "")
		if event_zone_preference.has(zone_name):
			preferred_zones.append(zone)

	# Fallback to all zones if no preferred zones found
	return preferred_zones if not preferred_zones.is_empty() else all_zones

## Validate configuration
func is_valid() -> bool:
	return map_id != "" and display_name != "" and arena_bounds_radius > 0.0
