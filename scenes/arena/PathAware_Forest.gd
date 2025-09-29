extends "res://scenes/arena/Arena.gd"

## PathAware_Forest - PathAware Arena Generator forest scene
## Handles arena randomization on entry from hideout and manages player spawn
## Uses PathAwareMapConfig for generated arenas with path-aware spawning capabilities

@onready var arena_generator: PathAwareArenaGenerator = $PathAwareArenaGenerator
@onready var player_spawn: Marker2D = $PlayerSpawnPoint

@export_group("Debug Visualization")
## Show debug markers for connection points and path visualization
@export var show_path_debug: bool = true:
	set(value):
		show_path_debug = value
		_update_debug_visualization()

## Show path connection lines between points
@export var show_path_connections: bool = true:
	set(value):
		show_path_connections = value
		_update_debug_visualization()

var is_randomize_on_entry: bool = true

func _ready() -> void:
	Logger.info("PathAware_Forest scene loaded", "pathgen")

	# Call parent Arena._ready() first to setup all systems
	super._ready()

	# Check if we have context from StateManager for randomization
	_check_for_randomization_context()

	# Generate arena based on context
	_generate_arena()

	# Apply debug visualization settings AFTER generation
	_update_debug_visualization()

	# Setup player if needed
	_setup_player_spawn()


func _check_for_randomization_context() -> void:
	"""Check StateManager context for randomization settings."""
	# In a real implementation, StateManager would pass context data
	# For now, we'll always randomize on entry from hideout

	# This would be set by StateManager context in the future
	is_randomize_on_entry = true

	Logger.debug("Randomization on entry: %s" % is_randomize_on_entry, "pathgen")

func _generate_arena() -> void:
	"""Generate the arena with optional randomization."""

	if not arena_generator:
		Logger.error("PathAwareArenaGenerator not found in scene", "pathgen")
		return

	# Ensure we have a PathAwareMapConfig (prefer assigned resource over new creation)
	if not map_config:
		Logger.info("No map_config assigned, loading default PathAware forest config", "pathgen")
		map_config = load("res://data/content/maps/pathaware_forest_config.tres") as MapConfig

	if not map_config is PathAwareMapConfig:
		Logger.info("Converting to PathAwareMapConfig", "pathgen")
		var path_aware_config = PathAwareMapConfig.new()
		# Copy basic properties from the loaded config
		if map_config:
			path_aware_config.map_id = map_config.map_id
			path_aware_config.display_name = map_config.display_name
			path_aware_config.description = map_config.description
			path_aware_config.arena_bounds_radius = map_config.arena_bounds_radius
			path_aware_config.spawn_radius = map_config.spawn_radius
			path_aware_config.player_spawn_position = map_config.player_spawn_position
			path_aware_config.auto_spawn_range = map_config.auto_spawn_range
			path_aware_config.auto_spawn_min_distance = map_config.auto_spawn_min_distance
			path_aware_config.activation_method = map_config.activation_method
		else:
			_setup_default_map_config_on_instance(path_aware_config)
		map_config = path_aware_config

	if is_randomize_on_entry:
		# Use a new random seed for each entry
		var new_seed = randi()
		Logger.info("Generating PathGenerator Arena with new seed: %d" % new_seed, "pathgen")

		# Set randomization parameters for visual variety
		if arena_generator.tree_config:
			arena_generator.tree_config.placement_randomness = randf_range(0.3, 1.0)
			arena_generator.tree_config.max_random_offset = randi_range(16, 32)

		# Generate with new seed
		arena_generator.generation_seed = new_seed
		arena_generator.generate_path_aware_arena()
	else:
		Logger.info("Generating PathGenerator Arena with existing configuration", "pathgen")
		arena_generator.generate_path_aware_arena()

	# Create and populate path snapshot after generation
	_create_and_populate_path_snapshot()

	# Emit ready signal for service registration
	_emit_path_snapshot_ready_signal()

	# Update spawn zones for SpawnDirector integration
	_update_spawn_zones()


func _update_spawn_zones() -> void:
	"""Collect generated spawn zones and make them available to SpawnDirector"""
	if not arena_generator:
		Logger.warn("Arena generator not found for spawn zone collection", "spawnzones")
		return

	# Clear existing spawn zones
	_spawn_zone_areas.clear()

	# Collect Area2D spawn zones directly from SpawnZoneManager
	var spawn_zone_manager = arena_generator.spawn_zone_manager
	if spawn_zone_manager:
		var spawn_zones = spawn_zone_manager.get_spawn_zones()
		for zone in spawn_zones:
			if zone is Area2D:
				_spawn_zone_areas.append(zone)
	else:
		Logger.warn("SpawnZoneManager not found in arena generator", "spawnzones")

	Logger.info("Updated arena spawn zones: %d zones available for SpawnDirector" % _spawn_zone_areas.size(), "spawnzones")


func _setup_player_spawn() -> void:
	"""Setup player spawn point for arena entry."""

	if not player_spawn:
		Logger.warn("Player spawn point 'PlayerSpawnPoint' not found", "pathgen")
		return

	# For now, we'll just log the spawn point
	# In the future, this would coordinate with player spawning system
	Logger.debug("Player spawn point ready at: %s" % player_spawn.global_position, "pathgen")


## Public interface for external randomization requests
func regenerate_arena() -> void:
	"""Regenerate the arena with new randomization - useful for testing."""

	Logger.info("Manual arena regeneration requested", "pathgen")
	is_randomize_on_entry = true
	_generate_arena()

func set_randomization_mode(randomize: bool) -> void:
	"""Set whether arena should randomize on entry."""

	is_randomize_on_entry = randomize
	Logger.debug("Randomization mode set to: %s" % randomize, "pathgen")

## Handle return to hideout
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_return_to_hideout()

func _return_to_hideout() -> void:
	"""Return to hideout scene."""

	Logger.info("Returning to hideout from PathAware_Forest", "pathgen")
	StateManager.go_to_hideout({"source": "pathgen_arena_exit"})

## Setup default configuration for PathAwareMapConfig
func _setup_default_map_config_on_instance(path_aware_config: PathAwareMapConfig) -> void:
	"""Initialize default values for PathAwareMapConfig."""

	path_aware_config.map_id = "pathaware_forest"
	path_aware_config.display_name = "Generated Forest Arena"
	path_aware_config.description = "Procedurally generated forest arena with path-aware spawning"

	# Basic arena properties
	path_aware_config.arena_bounds_radius = 600.0
	path_aware_config.spawn_radius = 500.0
	path_aware_config.player_spawn_position = Vector2.ZERO

	# Path-aware specific settings
	path_aware_config.auto_optimize_spawns = true
	path_aware_config.generation_seed = 0  # Will be set after generation
	path_aware_config.activation_method = MapConfig.ActivationMethod.AREA_TRIGGERS  # Default to area triggers

	# Create default spawn profiles
	path_aware_config.spawn_profiles = [
		PathSpawnProfile.create_enemy_profile(),
		PathSpawnProfile.create_breach_profile(),
		PathSpawnProfile.create_powerup_profile()
	]

	Logger.debug("Setup default PathAwareMapConfig", "pathgen")

## Create and populate path snapshot from generated data
func _create_and_populate_path_snapshot() -> void:
	"""Create path snapshot from arena generator and populate map config."""

	if not arena_generator:
		Logger.warn("Cannot create path snapshot: arena_generator is null", "pathgen")
		return

	# Create snapshot from generated data
	var snapshot = arena_generator.get_path_snapshot()
	if not snapshot or not snapshot.is_valid():
		Logger.warn("Failed to create valid path snapshot", "pathgen")
		return

	# Populate PathAwareMapConfig
	map_config.path_snapshot = snapshot
	map_config.generation_seed = arena_generator.generation_seed

	# Update arena bounds from snapshot
	if snapshot.total_arena_bounds != Rect2():
		map_config.arena_bounds_radius = max(
			snapshot.total_arena_bounds.size.x,
			snapshot.total_arena_bounds.size.y
		) * 0.5

	Logger.info("Created path snapshot: %s" % snapshot.get_debug_summary(), "pathgen")

## Emit path snapshot ready signal for spawning systems
func _emit_path_snapshot_ready_signal() -> void:
	"""Emit EventBus signal for PathAwareSpaceService registration."""

	if not map_config or not map_config.path_snapshot:
		Logger.warn("Cannot emit path snapshot ready: missing map_config or path_snapshot", "pathgen")
		return

	var arena_id = get_arena_id()
	var payload = EventBus.ArenaPathSnapshotReadyPayload_Type.new(arena_id, map_config.path_snapshot)

	EventBus.arena_path_snapshot_ready.emit(payload)
	Logger.debug("Emitted arena_path_snapshot_ready signal for arena: %s" % arena_id, "pathgen")

## Get unique arena identifier for this scene instance
func get_arena_id() -> String:
	"""Get unique identifier for this arena instance."""

	# Use scene instance ID as unique identifier
	return "pathaware_forest_%d" % get_instance_id()

## Update debug visualization settings in arena generator
func _update_debug_visualization() -> void:
	"""Update PathAwareArenaGenerator debug settings when properties change."""

	# Check if we're initialized yet (@onready variables available)
	if not is_node_ready():
		Logger.debug("_update_debug_visualization called before _ready(), deferring", "pathdebug")
		return

	if not arena_generator:
		Logger.debug("_update_debug_visualization called but arena_generator is null", "pathdebug")
		return

	# Update arena generator debug settings
	arena_generator.show_debug_markers = show_path_debug
	arena_generator.show_path_connections = show_path_connections

	Logger.debug("Updated debug visualization: markers=%s, connections=%s" % [show_path_debug, show_path_connections], "pathdebug")

## Public interface for runtime debug toggling
func toggle_path_debug() -> void:
	"""Toggle path debug markers on/off."""
	show_path_debug = not show_path_debug

func toggle_path_connections() -> void:
	"""Toggle path connection lines on/off."""
	show_path_connections = not show_path_connections
