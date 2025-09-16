class_name UnderworldArena
extends "res://scenes/arena/Arena.gd"

## Underworld-themed arena with volcanic/demonic atmosphere
## Extends BaseArena with underworld-specific features and configuration

@export var map_config: MapConfig: ## Underworld arena configuration
	set(value):
		map_config = value
		if is_node_ready():
			_apply_map_config()

@export_group("Underworld Atmosphere")
## Enable ember/fire particle effects
@export var enable_fire_particles: bool = true
## Enable heat haze visual effects
@export var enable_heat_distortion: bool = true
## Intensity of lava glow effects
@export var lava_glow_intensity: float = 1.5

@export_group("Environmental Hazards")
## Enable lava pit damage (future feature)
@export var enable_lava_damage: bool = false
## Damage dealt by lava hazards
@export var lava_damage_per_second: float = 15.0

# Visual effects nodes (to be set up in scene)
@onready var ambient_light: CanvasModulate = get_node_or_null("CanvasModulate")
@onready var fire_particles: GPUParticles2D = get_node_or_null("FireParticles")
@onready var heat_distortion: Node2D = get_node_or_null("HeatDistortion")

# Spawn zone management
@onready var spawn_zones_container: Node2D = $SpawnZones
var _spawn_zone_areas: Array[Area2D] = []

func _ready() -> void:
	Logger.info("=== UNDERWORLDARENA._READY() STARTING ===", "debug")
	
	# Apply underworld-specific configuration first
	if map_config:
		_apply_map_config()
	else:
		# Load default underworld config if none assigned
		_load_default_config()
	
	# Call parent Arena initialization (this does the heavy lifting)
	super._ready()
	
	# Setup underworld-specific atmosphere after Arena systems are ready
	_setup_underworld_atmosphere()

	# Initialize spawn zone cache
	_initialize_spawn_zones()

	Logger.info("UnderworldArena initialization complete: %s" % arena_name, "arena")

func _load_default_config() -> void:
	"""Load default underworld configuration if none is set"""
	var config_path = "res://data/content/maps/underworld_config.tres"
	if ResourceLoader.exists(config_path):
		map_config = load(config_path) as MapConfig
		if map_config:
			Logger.info("Loaded default underworld config", "arena")
		else:
			Logger.warn("Failed to load underworld config from %s" % config_path, "arena")

func _apply_map_config() -> void:
	"""Apply map configuration to arena properties"""
	if not map_config or not map_config.is_valid():
		Logger.warn("Invalid map config for UnderworldArena", "arena")
		return
	
	# Apply basic arena properties
	arena_id = map_config.map_id
	arena_name = map_config.display_name
	arena_bounds = map_config.arena_bounds_radius
	spawn_radius = map_config.spawn_radius
	
	# Apply underworld-specific properties from custom_properties
	if map_config.custom_properties.has("lava_damage_per_second"):
		lava_damage_per_second = map_config.custom_properties.lava_damage_per_second
	
	# Apply ambient lighting
	if ambient_light:
		ambient_light.color = map_config.ambient_light_color
		# Note: energy property doesn't exist on CanvasModulate, handled by lighting nodes
	
	Logger.debug("Applied map config: %s" % map_config.display_name, "arena")

func _setup_underworld_atmosphere() -> void:
	"""Configure underworld-specific visual atmosphere"""
	
	# Setup fire particle effects
	if fire_particles and enable_fire_particles:
		fire_particles.emitting = true
		# Particle configuration would be done in the scene editor
		Logger.debug("Fire particles enabled", "arena")
	
	# Setup heat distortion effects
	if heat_distortion and enable_heat_distortion:
		heat_distortion.visible = true
		# Heat distortion shaders would be configured in scene
		Logger.debug("Heat distortion enabled", "arena")

## Override spawn radius from map config
func get_spawn_radius() -> float:
	if map_config:
		return map_config.spawn_radius
	return spawn_radius

## Override arena bounds from map config  
func get_arena_bounds() -> float:
	if map_config:
		return map_config.arena_bounds_radius
	return arena_bounds

## Get spawn zones for enemy spawning (scene-only approach)
func get_spawn_zones() -> Array[Area2D]:
	return _spawn_zone_areas

## Get boss spawn positions
func get_boss_spawn_positions() -> Array[Vector2]:
	if map_config:
		return map_config.boss_spawn_positions
	return []

## Check if arena has environmental hazards
func has_environmental_hazards() -> bool:
	if map_config:
		return map_config.has_environmental_hazards
	return enable_lava_damage

## Get lava damage amount (future feature)
func get_lava_damage() -> float:
	return lava_damage_per_second

## Future method for lava damage application
func _apply_lava_damage_to_entity(entity_id: EntityId) -> void:
	"""Apply lava damage to entity (future environmental hazard system)"""
	if not enable_lava_damage:
		return
	
	# Future implementation would integrate with DamageService
	Logger.debug("Lava damage applied to entity: %s" % entity_id, "arena")

## Get arena theme tags for future modifier/effect systems
func get_theme_tags() -> Array[StringName]:
	if map_config:
		return map_config.theme_tags
	return [&"underworld"]

## Initialize spawn zone cache for efficient access
func _initialize_spawn_zones() -> void:
	if spawn_zones_container:
		for child in spawn_zones_container.get_children():
			if child is Area2D:
				_spawn_zone_areas.append(child)
		Logger.debug("Initialized %d spawn zones" % _spawn_zone_areas.size(), "arena")

## Override spawn position to use proximity-based zone selection from scene Area2D nodes
func get_random_spawn_position() -> Vector2:
	# Scene-only approach: Use Area2D zones exclusively
	if _spawn_zone_areas.is_empty():
		Logger.warn("No scene spawn zones available, using radius fallback", "arena")
		# Final fallback to simple radius spawning
		var angle := randf() * TAU
		var distance := randf() * get_spawn_radius()
		return Vector2(cos(angle), sin(angle)) * distance

	# Get player position for proximity-based zone filtering
	var player_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	if player_pos == Vector2.ZERO:
		Logger.debug("Auto spawn: No valid player position, using all scene zones", "arena")
		return select_random_scene_zone(_spawn_zone_areas)

	# Filter scene zones by min/max distance range (prevent spawning too close)
	var auto_spawn_range = 800.0  # Default max
	var auto_spawn_min_distance = 300.0  # Default min
	if map_config:
		auto_spawn_range = map_config.auto_spawn_range
		auto_spawn_min_distance = map_config.auto_spawn_min_distance if "auto_spawn_min_distance" in map_config else 300.0

	var zones_in_range = filter_zones_by_distance_range(_spawn_zone_areas, player_pos, auto_spawn_min_distance, auto_spawn_range)

	if zones_in_range.is_empty():
		return Vector2.ZERO

	# Select random zone from those in range
	var selected_zone = zones_in_range[randi() % zones_in_range.size()]
	Logger.debug("Auto spawn: Selected scene zone %s in range" % selected_zone.name, "arena")
	return generate_position_in_scene_zone(selected_zone)
