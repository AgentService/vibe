class_name PathSpawnProfile
extends Resource

## Configuration for specific spawn system behaviors in path-aware arenas
## Defines how different systems (enemies, breaches, powerups) interact with path geometry
## Used by PathAwareMapConfig to configure spawn preferences for each system

@export_group("System Configuration")
## Unique identifier for the spawn system (e.g., "enemies", "breach", "powerups", "items")
@export var system_name: String = ""

## Categories of path locations this system can spawn in
@export var spawn_categories: Array = []

## Priority weight for this system when multiple systems compete for spawn locations
@export_range(0.1, 5.0, 0.1) var priority_weight: float = 1.0

@export_group("Timing Configuration")
## Cooldown and timing hints for this spawn system
## Dictionary format: {"min_interval": 5.0, "burst_cooldown": 30.0, "max_concurrent": 10}
@export var cooldown_hints: Dictionary = {}

@export_group("Spatial Constraints")
## Minimum distance from other spawns of the same system
@export var min_spawn_distance: float = 50.0

## Maximum distance from player for this system to be active
@export var max_spawn_range: float = 800.0

## Whether this system prefers to spawn near the player or far from them
@export var proximity_preference: ProximityPreference = ProximityPreference.BALANCED

@export_group("Category Weights")
## Custom weights for each spawn category (overrides default category weights)
@export var category_weights: Dictionary = {}

## Path spawn categories defining where systems can spawn relative to path geometry
enum PathSpawnCategory {
	ALONG_MAIN_PATH,    ## Along the primary path spine (interpolated 64px intervals)
	ALONG_BRANCHES,     ## Along branch paths extending from main path
	AT_ENDPOINTS,       ## At the ends of paths (good for bosses, special events)
	AT_BRANCH_ENDPOINTS, ## At the ends of branch paths (specialized branch termination points)
	MAIN_CHECKPOINTS,   ## At main path control points/waypoints (strategic spawn locations)
	IN_CLEARINGS,       ## In open areas between path boundaries
	AROUND_PATHS        ## In buffer zones around paths but not directly on them
}

## Proximity preferences for spawn positioning relative to player
enum ProximityPreference {
	NEAR_PLAYER,        ## Prefer spawning close to player (e.g., immediate threats)
	FAR_FROM_PLAYER,    ## Prefer spawning away from player (e.g., ambush spawns)
	BALANCED,           ## No strong preference (default)
	ON_SCREEN,          ## Must be visible to player
	OFF_SCREEN          ## Must be outside player viewport
}

## Check if this profile can spawn in a specific category
func can_spawn_in_category(category: PathSpawnCategory) -> bool:
	return spawn_categories.has(category)

## Get weight for a specific category (custom weight or default)
func get_category_weight(category: PathSpawnCategory) -> float:
	if category_weights.has(category):
		return category_weights[category]

	# Default weights by category
	match category:
		PathSpawnCategory.ALONG_MAIN_PATH:
			return 1.0
		PathSpawnCategory.ALONG_BRANCHES:
			return 0.8
		PathSpawnCategory.AT_ENDPOINTS:
			return 1.5
		PathSpawnCategory.AT_BRANCH_ENDPOINTS:
			return 1.3  # Slightly lower than main endpoints but higher than regular spawns
		PathSpawnCategory.IN_CLEARINGS:
			return 1.2
		PathSpawnCategory.AROUND_PATHS:
			return 0.0  # Disabled - logic removed
		_:
			return 1.0

## Get cooldown value for a specific timing parameter
func get_cooldown_hint(hint_name: String, default_value: float = 0.0) -> float:
	return cooldown_hints.get(hint_name, default_value)

## Set cooldown hint (useful for runtime configuration)
func set_cooldown_hint(hint_name: String, value: float) -> void:
	cooldown_hints[hint_name] = value

## Check if system should be active based on player distance
func is_in_spawn_range(player_position: Vector2, spawn_position: Vector2) -> bool:
	var distance = player_position.distance_to(spawn_position)
	return distance <= max_spawn_range

## Get proximity score for a position relative to player (higher = better match for preference)
func get_proximity_score(player_position: Vector2, spawn_position: Vector2) -> float:
	var distance = player_position.distance_to(spawn_position)
	var normalized_distance = distance / max_spawn_range  # 0.0 to 1.0

	match proximity_preference:
		ProximityPreference.NEAR_PLAYER:
			return 1.0 - normalized_distance  # Closer = higher score
		ProximityPreference.FAR_FROM_PLAYER:
			return normalized_distance  # Farther = higher score
		ProximityPreference.BALANCED:
			return 1.0  # No preference
		ProximityPreference.ON_SCREEN:
			# This would need viewport information - placeholder for now
			return 1.0
		ProximityPreference.OFF_SCREEN:
			# This would need viewport information - placeholder for now
			return 1.0
		_:
			return 1.0

## Get human-readable category name for debugging
func get_category_name(category: PathSpawnCategory) -> String:
	match category:
		PathSpawnCategory.ALONG_MAIN_PATH:
			return "MainPath"
		PathSpawnCategory.ALONG_BRANCHES:
			return "Branches"
		PathSpawnCategory.AT_ENDPOINTS:
			return "Endpoints"
		PathSpawnCategory.AT_BRANCH_ENDPOINTS:
			return "BranchEndpoints"
		PathSpawnCategory.IN_CLEARINGS:
			return "Clearings"
		PathSpawnCategory.AROUND_PATHS:
			return "AroundPaths"  # Enum preserved, logic removed
		_:
			return "Unknown"

## Get human-readable proximity preference name
func get_proximity_preference_name() -> String:
	match proximity_preference:
		ProximityPreference.NEAR_PLAYER:
			return "NearPlayer"
		ProximityPreference.FAR_FROM_PLAYER:
			return "FarFromPlayer"
		ProximityPreference.BALANCED:
			return "Balanced"
		ProximityPreference.ON_SCREEN:
			return "OnScreen"
		ProximityPreference.OFF_SCREEN:
			return "OffScreen"
		_:
			return "Unknown"

## Create default profile for enemy spawning
static func create_enemy_profile() -> PathSpawnProfile:
	var profile = PathSpawnProfile.new()
	profile.system_name = "enemies"
	profile.spawn_categories.clear()
	profile.spawn_categories.append(PathSpawnCategory.ALONG_MAIN_PATH)
	profile.spawn_categories.append(PathSpawnCategory.ALONG_BRANCHES)
	profile.spawn_categories.append(PathSpawnCategory.IN_CLEARINGS)
	# profile.spawn_categories.append(PathSpawnCategory.AROUND_PATHS)  # Disabled - logic removed
	profile.priority_weight = 1.0
	profile.proximity_preference = ProximityPreference.BALANCED
	profile.max_spawn_range = 800.0
	profile.min_spawn_distance = 60.0
	profile.cooldown_hints = {
		"min_interval": 2.0,
		"burst_cooldown": 10.0,
		"max_concurrent": 50
	}
	return profile

## Create default profile for breach events
static func create_breach_profile() -> PathSpawnProfile:
	var profile = PathSpawnProfile.new()
	profile.system_name = "breach"
	profile.spawn_categories.clear()
	profile.spawn_categories.append(PathSpawnCategory.AT_ENDPOINTS)
	profile.spawn_categories.append(PathSpawnCategory.IN_CLEARINGS)
	profile.priority_weight = 2.0  # Higher priority for special events
	profile.proximity_preference = ProximityPreference.FAR_FROM_PLAYER
	profile.max_spawn_range = 1200.0
	profile.min_spawn_distance = 200.0
	profile.cooldown_hints = {
		"min_interval": 45.0,
		"max_concurrent": 3
	}
	# Higher weight for endpoints (breach events prefer path terminals)
	profile.category_weights = {
		PathSpawnCategory.AT_ENDPOINTS: 2.0,
		PathSpawnCategory.IN_CLEARINGS: 1.0
	}
	return profile

## Create default profile for powerup spawning
static func create_powerup_profile() -> PathSpawnProfile:
	var profile = PathSpawnProfile.new()
	profile.system_name = "powerups"
	profile.spawn_categories.clear()
	profile.spawn_categories.append(PathSpawnCategory.ALONG_MAIN_PATH)
	profile.spawn_categories.append(PathSpawnCategory.AT_ENDPOINTS)
	profile.spawn_categories.append(PathSpawnCategory.IN_CLEARINGS)
	profile.priority_weight = 0.8
	profile.proximity_preference = ProximityPreference.NEAR_PLAYER
	profile.max_spawn_range = 600.0
	profile.min_spawn_distance = 100.0
	profile.cooldown_hints = {
		"min_interval": 15.0,
		"max_concurrent": 5
	}
	return profile

## Create default profile for item drops
static func create_item_profile() -> PathSpawnProfile:
	var profile = PathSpawnProfile.new()
	profile.system_name = "items"
	profile.spawn_categories = [
		PathSpawnCategory.ALONG_MAIN_PATH,
		PathSpawnCategory.IN_CLEARINGS
	]
	profile.priority_weight = 0.5  # Lower priority
	profile.proximity_preference = ProximityPreference.BALANCED
	profile.max_spawn_range = 400.0
	profile.min_spawn_distance = 30.0
	profile.cooldown_hints = {
		"min_interval": 8.0,
		"max_concurrent": 20
	}
	return profile

## Validate profile configuration
func is_valid() -> bool:
	if system_name.is_empty():
		Logger.warn("PathSpawnProfile: system_name is empty", "pathspawn")
		return false

	if spawn_categories.is_empty():
		Logger.warn("PathSpawnProfile: no spawn categories defined for system '%s'" % system_name, "pathspawn")
		return false

	if priority_weight <= 0.0:
		Logger.warn("PathSpawnProfile: invalid priority_weight for system '%s'" % system_name, "pathspawn")
		return false

	return true

## Get debug summary for logging
func get_debug_summary() -> String:
	var category_names: Array[String] = []
	for category in spawn_categories:
		category_names.append(get_category_name(category))

	return "PathSpawnProfile[%s, weight=%.1f, categories=[%s], preference=%s]" % [
		system_name,
		priority_weight,
		", ".join(category_names),
		get_proximity_preference_name()
	]
