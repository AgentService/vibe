class_name ForestArena
extends Arena

## Forest-themed arena with procedural generation capabilities
## Extends Arena with forest-specific features and procedural terrain generation
## Integrates ProceduralArenaGenerator as a component for modular design

@export var map_config: MapConfig: ## Forest arena configuration
	set(value):
		map_config = value
		if is_node_ready():
			_apply_map_config()

@export_group("Forest Atmosphere")
## Enable forest ambient sounds
@export var enable_forest_sounds: bool = true
## Enable wind particle effects
@export var enable_wind_particles: bool = true
## Intensity of forest lighting effects
@export var forest_lighting_intensity: float = 1.0

@export_group("Procedural Generation")
## Enable procedural generation on startup
@export var auto_generate_on_ready: bool = true
## Forest biome preference for generation
@export var biome_preference: String = ""
## Size preference for generation
@export var size_preference: String = "standard"

# Procedural generation component
var procedural_generator: ProceduralArenaGenerator

# Visual effects nodes
@onready var ambient_light: CanvasModulate = get_node_or_null("CanvasModulate")

func _ready() -> void:
	Logger.info("=== FORESTARENA._READY() STARTING ===", "debug")

	# Apply forest configuration first
	if map_config and map_config.is_valid():
		_apply_map_config()
	else:
		# Load default forest config if none assigned or invalid
		_load_default_config()

	# Setup procedural generation component first
	_setup_procedural_generator()

	# Apply procedural generation if context available
	_apply_procedural_generation()

	# Call parent Arena initialization (handles player spawning, systems, etc.)
	super._ready()

	# Setup forest-specific atmosphere after Arena systems are ready
	_setup_forest_atmosphere()

	Logger.info("ForestArena initialization complete: %s" % arena_name, "arena")

func _setup_procedural_generator() -> void:
	"""Initialize the procedural generator component."""

	Logger.info("Starting procedural generator setup", "debug")

	# Use existing ProceduralArenaGenerator node from scene
	procedural_generator = get_node_or_null("ProceduralArenaGenerator")
	if not procedural_generator:
		Logger.error("ProceduralArenaGenerator node not found in scene", "debug")
		return

	Logger.debug("Found existing ProceduralArenaGenerator node", "debug")

	# Pass arena reference to generator so it can find nodes
	Logger.debug("Checking for set_arena_reference method", "debug")
	if procedural_generator.has_method("set_arena_reference"):
		Logger.debug("Method exists, calling set_arena_reference", "debug")
		procedural_generator.set_arena_reference(self)
		Logger.debug("Set arena reference", "debug")
	else:
		Logger.warn("set_arena_reference method not found on procedural_generator", "debug")

	# Load default configurations if not set
	Logger.debug("About to call _setup_generator_configs", "debug")
	_setup_generator_configs()
	Logger.debug("_setup_generator_configs completed", "debug")

	Logger.debug("ProceduralArenaGenerator component ready", "debug")

func _setup_generator_configs() -> void:
	"""Setup default configurations for the procedural generator."""

	# Load BiomeConfig if not already set
	if not procedural_generator.biome_config:
		var biome_path = "res://data/content/biomes/ForestBiome.tres"
		if ResourceLoader.exists(biome_path):
			procedural_generator.biome_config = load(biome_path)
			Logger.debug("Loaded ForestBiome config", "debug")

	# Load or create GenerationParams - make a copy to avoid modifying the resource file
	if not procedural_generator.generation_params:
		var params_path = "res://data/content/biomes/DefaultGenerationParams.tres"
		if ResourceLoader.exists(params_path):
			var template_params = load(params_path) as GenerationParams
			# Create a copy to avoid modifying the shared resource
			procedural_generator.generation_params = template_params.duplicate()
			Logger.debug("Loaded and duplicated DefaultGenerationParams", "debug")
		else:
			# Create default params if file doesn't exist
			procedural_generator.generation_params = GenerationParams.new()
			Logger.debug("Created default GenerationParams", "debug")

	# Set a unique seed for this arena visit (following plugin pattern)
	_set_unique_generation_seed()

func _set_unique_generation_seed() -> void:
	"""Set a unique generation seed for this arena visit (similar to plugin approach)."""
	if procedural_generator.generation_params:
		var unique_seed = _get_generation_seed()
		procedural_generator.generation_params.generation_seed = unique_seed
		Logger.debug("Set unique generation seed: %d" % unique_seed, "debug")

func _apply_procedural_generation() -> void:
	"""Apply procedural generation based on transition context or export settings."""

	Logger.info("Starting procedural generation application", "debug")

	# Check for procedural context from scene transition
	var context = _get_procedural_context()
	Logger.debug("Procedural context: %s" % context, "debug")

	if context and context.has("source"):
		Logger.info("Applying procedural generation from context: %s" % context.get("source"), "debug")
		_generate_from_context(context)
	elif auto_generate_on_ready:
		Logger.info("Applying auto-generation with export settings (auto_generate_on_ready=%s)" % auto_generate_on_ready, "debug")
		_generate_from_export_settings()
	else:
		Logger.warn("No procedural generation triggered - auto_generate_on_ready=%s, context=%s" % [auto_generate_on_ready, context], "debug")

func _get_procedural_context() -> Dictionary:
	"""Retrieve procedural context from StateManager or scene transition."""

	# Check if StateManager has procedural context
	if StateManager.has_method("get_transition_data"):
		var transition_data = StateManager.get_transition_data()
		if transition_data.has("procedural_context"):
			return transition_data.procedural_context

	# Check for procedural context in scene metadata (safely)
	if has_meta("procedural_context"):
		return get_meta("procedural_context")

	return {}

func _generate_from_context(context: Dictionary) -> void:
	"""Generate arena using procedural context from scene transition."""

	if not procedural_generator:
		Logger.error("ProceduralArenaGenerator not available for context generation", "debug")
		return

	# Trigger generation (seed already set in _setup_generator_configs)
	if procedural_generator.has_method("generate_arena"):
		# Add validation logging before generation
		Logger.debug("About to call generate_arena - validation check:", "debug")
		Logger.debug("  biome_config exists: %s" % str(procedural_generator.biome_config != null), "debug")
		Logger.debug("  generation_params exists: %s" % str(procedural_generator.generation_params != null), "debug")
		if procedural_generator.biome_config:
			Logger.debug("  biome_config valid: %s" % str(procedural_generator.biome_config.is_valid()), "debug")
		if procedural_generator.generation_params:
			Logger.debug("  generation_params valid: %s" % str(procedural_generator.generation_params.is_valid()), "debug")

		procedural_generator.generate_arena()
		Logger.info("Procedural generation completed from context", "debug")

		# Check if layers were found after generation attempt
		Logger.debug("Post-generation layer check:", "debug")
		Logger.debug("  Ground layer: %s" % str(procedural_generator.ground_layer != null), "debug")
		Logger.debug("  Boundaries layer: %s" % str(procedural_generator.boundaries_layer != null), "debug")

func _generate_from_export_settings() -> void:
	"""Generate arena using export property settings."""

	if not procedural_generator:
		Logger.error("ProceduralArenaGenerator not available for export generation", "debug")
		return

	# Trigger generation (seed already set in _setup_generator_configs)
	if procedural_generator.has_method("generate_arena"):
		# Add validation logging before generation
		Logger.debug("About to call generate_arena - validation check:", "debug")
		Logger.debug("  biome_config exists: %s" % str(procedural_generator.biome_config != null), "debug")
		Logger.debug("  generation_params exists: %s" % str(procedural_generator.generation_params != null), "debug")
		if procedural_generator.biome_config:
			Logger.debug("  biome_config valid: %s" % str(procedural_generator.biome_config.is_valid()), "debug")
		if procedural_generator.generation_params:
			Logger.debug("  generation_params valid: %s" % str(procedural_generator.generation_params.is_valid()), "debug")

		procedural_generator.generate_arena()
		Logger.info("Procedural generation completed from export settings", "debug")

		# Check if layers were found after generation attempt
		Logger.debug("Post-generation layer check:", "debug")
		Logger.debug("  Ground layer: %s" % str(procedural_generator.ground_layer != null), "debug")
		Logger.debug("  Boundaries layer: %s" % str(procedural_generator.boundaries_layer != null), "debug")

func _get_generation_seed() -> int:
	"""Get a seed for procedural generation with variation between visits."""

	# Create variation by combining base seed with visit counter and time
	var base_seed: int = 0
	if RNG and RNG.has_method("stream"):
		# Use the base procedural stream for consistency
		base_seed = RNG.stream("procedural").randi()
	else:
		base_seed = 12345  # Fallback base seed

	# Add variation using time to ensure different maps each visit
	var time_variation = int(Time.get_unix_time_from_system()) % 10000
	var combined_seed = base_seed + time_variation

	Logger.debug("Generated arena seed: %d (base: %d + time: %d)" % [combined_seed, base_seed, time_variation], "debug")
	return combined_seed

func _setup_forest_atmosphere() -> void:
	"""Configure forest-specific visual and audio atmosphere."""

	# Setup ambient lighting
	if ambient_light:
		# Forest lighting: greenish tint with moderate intensity
		ambient_light.color = Color(0.9, 1.0, 0.85, 1.0) * forest_lighting_intensity
		Logger.debug("Forest ambient lighting configured", "arena")

	# TODO: Setup forest sound effects when audio system is ready
	if enable_forest_sounds:
		# _setup_forest_audio()
		pass

	# TODO: Setup wind particle effects when particle system is ready
	if enable_wind_particles:
		# _setup_wind_particles()
		pass

func get_procedural_generator() -> ProceduralArenaGenerator:
	"""Get reference to the procedural generator component."""
	return procedural_generator

func regenerate_arena() -> void:
	"""Trigger arena regeneration (useful for debug/testing)."""

	if procedural_generator and procedural_generator.has_method("generate_arena"):
		procedural_generator.generate_arena()
		Logger.info("Arena regenerated", "debug")
	else:
		Logger.warn("Cannot regenerate arena - procedural generator not available", "debug")

func _load_default_config() -> void:
	"""Load default forest configuration if none is set"""
	var config_path = "res://data/content/maps/forest_config.tres"
	if ResourceLoader.exists(config_path):
		map_config = load(config_path) as MapConfig
		if map_config:
			Logger.info("Loaded default forest config", "arena")
			_apply_map_config()
		else:
			Logger.warn("Failed to load forest config from %s" % config_path, "arena")
			_create_default_config()
			_apply_map_config()
	else:
		# Create a default config if file doesn't exist
		_create_default_config()
		_apply_map_config()

func _create_default_config() -> void:
	"""Create a default forest configuration"""
	map_config = MapConfig.new()

	# Basic information
	map_config.map_id = "forest_arena"
	map_config.display_name = "Forest Arena"
	map_config.description = "A procedurally generated forest arena with dynamic terrain"

	# Visual configuration
	map_config.theme_tags = ["forest", "procedural", "nature"]
	map_config.ambient_light_color = Color(0.9, 1.0, 0.85, 1.0)  # Greenish forest lighting
	map_config.ambient_light_energy = 0.8

	# Gameplay configuration
	map_config.arena_bounds_radius = 600.0  # Larger for procedural areas
	map_config.spawn_radius = 500.0
	map_config.player_spawn_position = Vector2.ZERO

	# Spawning configuration
	map_config.max_concurrent_enemies = 60  # Higher for open forest areas
	map_config.auto_spawn_range = 900.0
	map_config.auto_spawn_min_distance = 350.0

	# Event system
	map_config.event_spawn_enabled = true
	map_config.available_events = ["breach", "ritual", "pack_hunt"]  # No boss events for procedural
	map_config.event_reward_multiplier = 2.5

	# Custom properties for forest
	map_config.custom_properties = {
		"procedural_generation": true,
		"biome_type": "forest",
		"terrain_density": 0.7,
		"tree_coverage": 0.4
	}

	Logger.info("Created default forest config", "arena")

func _apply_map_config() -> void:
	"""Apply map configuration to arena properties"""
	if not map_config:
		Logger.warn("No map config for ForestArena", "arena")
		return

	if not map_config.is_valid():
		Logger.warn("Invalid map config for ForestArena:", "arena")
		Logger.warn("  map_id: '%s'" % map_config.map_id, "arena")
		Logger.warn("  display_name: '%s'" % map_config.display_name, "arena")
		Logger.warn("  arena_bounds_radius: %s" % map_config.arena_bounds_radius, "arena")
		return

	# Apply basic arena properties
	arena_id = map_config.map_id
	arena_name = map_config.display_name
	arena_bounds = map_config.arena_bounds_radius
	spawn_radius = map_config.spawn_radius

	# Apply forest-specific properties from custom_properties
	if map_config.custom_properties.has("biome_type"):
		biome_preference = map_config.custom_properties.biome_type

	# Apply ambient lighting
	if ambient_light:
		ambient_light.color = map_config.ambient_light_color

	Logger.debug("Applied map config: %s" % map_config.display_name, "arena")

# Override arena properties for forest-specific defaults
func _apply_default_config() -> void:
	"""Apply forest-specific default configuration."""

	arena_id = "forest_arena"
	arena_name = "Forest Arena"
	# Arena bounds and spawn radius will be set by procedural generator or parent
