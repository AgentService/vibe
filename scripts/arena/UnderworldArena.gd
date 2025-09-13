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

## Get spawn zones for enemy spawning (future spawn system integration)
func get_spawn_zones() -> Array[Dictionary]:
	if map_config:
		return map_config.spawn_zones
	return []

## Get random spawn zone weighted by spawn zone weights
func get_weighted_spawn_zone() -> Dictionary:
	if map_config:
		return map_config.get_weighted_spawn_zone()
	return {}

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
