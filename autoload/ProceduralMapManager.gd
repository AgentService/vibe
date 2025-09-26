extends Node

## ProceduralMapManager - Runtime procedural arena generation system
## Coordinates with MapDevice and StateManager for on-demand map creation

signal procedural_arena_generated(arena_scene: Node2D)
signal generation_failed(error_message: String)

# Available biome configurations for procedural generation
var _available_biomes: Dictionary = {}
var _generation_templates: Dictionary = {}

# Current generation settings
var _default_generation_params: GenerationParams
var _current_seed_base: int = 0

func _ready() -> void:
	_load_available_biomes()
	_load_generation_templates()
	_setup_default_params()
	Logger.info("ProceduralMapManager initialized with %d biomes" % _available_biomes.size(), "procedural")

func _load_available_biomes() -> void:
	"""Load all available biome configurations"""

	# Load Forest biome
	var forest_biome = load("res://data/content/biomes/ForestBiome.tres") as BiomeConfig
	if forest_biome:
		_available_biomes["forest"] = forest_biome
		Logger.debug("Loaded biome: Forest", "procedural")

	# Add more biomes here as they become available
	# var swamp_biome = load("res://data/content/biomes/SwampBiome.tres") as BiomeConfig
	# if swamp_biome:
	#     _available_biomes["swamp"] = swamp_biome

func _load_generation_templates() -> void:
	"""Load different generation parameter templates for variety"""

	# Small arena template
	var small_template = GenerationParams.new()
	small_template.arena_size = Vector2i(30, 20)
	small_template.boundary_width = 2
	small_template.decoration_density = 0.03
	small_template.camera_boundary_extension = 3
	_generation_templates["small"] = small_template

	# Standard arena template
	var standard_template = GenerationParams.new()
	standard_template.arena_size = Vector2i(40, 30)
	standard_template.boundary_width = 3
	standard_template.decoration_density = 0.05
	standard_template.camera_boundary_extension = 5
	_generation_templates["standard"] = standard_template

	# Large arena template
	var large_template = GenerationParams.new()
	large_template.arena_size = Vector2i(60, 45)
	large_template.boundary_width = 4
	large_template.decoration_density = 0.07
	large_template.camera_boundary_extension = 7
	_generation_templates["large"] = large_template

	Logger.debug("Loaded %d generation templates" % _generation_templates.size(), "procedural")

func _setup_default_params() -> void:
	"""Initialize default generation parameters"""
	_default_generation_params = load("res://data/content/biomes/DefaultGenerationParams.tres") as GenerationParams
	if not _default_generation_params:
		_default_generation_params = GenerationParams.new()
		Logger.warn("Could not load default generation params, using fallback", "procedural")

func generate_random_arena(size_hint: String = "standard") -> Node2D:
	"""Generate a random arena scene at runtime"""

	# Select random biome
	var biome_keys = _available_biomes.keys()
	if biome_keys.is_empty():
		Logger.error("No biomes available for procedural generation", "procedural")
		generation_failed.emit("No biomes configured")
		return null

	var random_biome_key = biome_keys[randi() % biome_keys.size()]
	var selected_biome = _available_biomes[random_biome_key]

	# Get generation template
	var generation_params = _generation_templates.get(size_hint, _generation_templates["standard"])

	# Generate unique seed
	_current_seed_base += 1
	var unique_seed = _current_seed_base + randi_range(1000, 9999)
	generation_params.generation_seed = unique_seed

	Logger.info("Generating procedural arena: biome=%s, size=%s, seed=%d" % [
		random_biome_key, size_hint, unique_seed
	], "procedural")

	return _create_arena_scene(selected_biome, generation_params)

func generate_arena_with_config(biome_name: String, size_hint: String = "standard", custom_seed: int = 0) -> Node2D:
	"""Generate arena with specific configuration"""

	if not _available_biomes.has(biome_name):
		Logger.error("Biome not found: %s" % biome_name, "procedural")
		generation_failed.emit("Unknown biome: " + biome_name)
		return null

	var selected_biome = _available_biomes[biome_name]
	var generation_params = _generation_templates.get(size_hint, _generation_templates["standard"])

	if custom_seed > 0:
		generation_params.generation_seed = custom_seed
	else:
		_current_seed_base += 1
		generation_params.generation_seed = _current_seed_base + randi_range(1000, 9999)

	Logger.info("Generating configured arena: biome=%s, size=%s, seed=%d" % [
		biome_name, size_hint, generation_params.generation_seed
	], "procedural")

	return _create_arena_scene(selected_biome, generation_params)

func _create_arena_scene(biome_config: BiomeConfig, generation_params: GenerationParams) -> Node2D:
	"""Create the actual arena scene with ProceduralArenaGenerator"""

	# Create the arena scene structure
	var arena_scene = Node2D.new()
	arena_scene.name = "ProceduralArena_" + str(generation_params.generation_seed)

	# Create the generator node
	var generator = ProceduralArenaGenerator.new()
	generator.name = "ProceduralArenaGenerator"
	generator.biome_config = biome_config
	generator.generation_params = generation_params.duplicate()  # Use a copy to avoid modifying template

	# Create the required layer structure
	var ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.z_index = 0
	generator.add_child(ground_layer)

	var boundaries_layer = TileMapLayer.new()
	boundaries_layer.name = "Boundaries"
	boundaries_layer.z_index = 1
	generator.add_child(boundaries_layer)

	var decorations_layer = TileMapLayer.new()
	decorations_layer.name = "Decorations"
	decorations_layer.z_index = 2
	generator.add_child(decorations_layer)

	var interactive_layer = TileMapLayer.new()
	interactive_layer.name = "Interactive"
	interactive_layer.z_index = 5
	generator.add_child(interactive_layer)

	var spawn_layer = TileMapLayer.new()
	spawn_layer.name = "Spawn"
	spawn_layer.z_index = 0
	generator.add_child(spawn_layer)

	# Create player spawn point
	var player_spawn = Marker2D.new()
	player_spawn.name = "PlayerSpawnPoint"
	player_spawn.position = Vector2.ZERO
	generator.add_child(player_spawn)

	# Add generator to arena
	arena_scene.add_child(generator)

	# Connect generation complete signal
	generator.generation_complete.connect(_on_generation_complete.bind(arena_scene))

	# Generate the arena content
	generator.generate_arena()

	return arena_scene

func _on_generation_complete(arena_scene: Node2D) -> void:
	"""Called when procedural generation completes"""
	Logger.info("Procedural arena generation completed: %s" % arena_scene.name, "procedural")
	procedural_arena_generated.emit(arena_scene)

func get_available_biomes() -> Array[String]:
	"""Get list of available biome names"""
	return _available_biomes.keys()

func get_available_sizes() -> Array[String]:
	"""Get list of available arena size templates"""
	return _generation_templates.keys()

func create_procedural_map_device_config(biome_preference: String = "", size_preference: String = "standard") -> Dictionary:
	"""Create configuration for MapDevice to use procedural generation"""

	return {
		"type": "procedural",
		"biome_preference": biome_preference,
		"size_preference": size_preference,
		"display_name": "Random Arena (%s)" % size_preference.capitalize()
	}
