@tool
extends Node2D
class_name PathAwareArenaGenerator

## Dedicated arena generator for testing path-aware boundary generation
## Completely separate from existing ProceduralArenaGenerator

@export_group("Configuration")
@export var path_config: PathConfiguration
@export var tree_config: TreeBoundaryConfiguration
@export var generation_seed: int = 54321
@export var auto_generate_on_ready: bool = false
@export var arena_base_radius: float = 600.0

@export_group("Spawn Zones")
@export var spawn_zone_radius: float = 100.0

@export_group("Visual Debug")
@export var show_debug_markers: bool = true
@export var show_path_connections: bool = true
@export var marker_size: float = 118.0
@export var line_width: float = 5.0

# Visual debug nodes
var debug_markers: Array[Node2D] = []
var debug_lines: Array[Line2D] = []

# System components
var path_generator: DungeonPathGenerator
var tree_generator: Node
var spawn_zone_manager: SpawnZoneManager
var spawn_zone_container: Node2D
var path_snapshot_analyzer: PathSnapshotAnalyzer
var arena_tile_manager: ArenaTileManager

# Generated data
var current_path_data: Dictionary = {}
var current_tree_data: Array[Vector2] = []
var rng: RandomNumberGenerator

func _ready():
	# Initialize system components
	_initialize_systems()

	if auto_generate_on_ready:
		generate_path_aware_arena()

## Initialize the two-system architecture
func _initialize_systems():
	# Ensure we have valid configurations first
	if not path_config:
		Logger.info("Creating default PathConfiguration", "pathgen")
		path_config = PathConfiguration.new()

	if not tree_config:
		Logger.info("Creating default TreeBoundaryConfiguration", "treegen")
		tree_config = TreeBoundaryConfiguration.new()

	# Create path generator system
	path_generator = DungeonPathGenerator.new()
	path_generator.path_config = path_config
	add_child(path_generator)

	# Create tree boundary generator system (using script resource to avoid class registration issues)
	var tree_script = load("res://scripts/systems/arena_generation/TreeBoundaryGenerator.gd")
	var tree_node = Node.new()
	tree_node.set_script(tree_script)
	tree_node.tree_config = tree_config
	add_child(tree_node)
	tree_generator = tree_node

	# Create spawn zone container for organizing spawn zones
	spawn_zone_container = Node2D.new()
	spawn_zone_container.name = "SpawnZones"
	add_child(spawn_zone_container)

	# Create spawn zone manager system (not used yet, preserving existing behavior)
	spawn_zone_manager = SpawnZoneManager.new()
	spawn_zone_manager.name = "SpawnZoneManager"
	add_child(spawn_zone_manager)

	# Configure SpawnZoneManager to use PathAwareArenaGenerator radius setting
	spawn_zone_manager.default_zone_radius = spawn_zone_radius
	spawn_zone_manager.show_visual_indicators = false

	# Create path snapshot analyzer for creating PathAwarePathSnapshot instances
	path_snapshot_analyzer = PathSnapshotAnalyzer.new()

	# Create arena tile manager for all tile placement operations
	arena_tile_manager = ArenaTileManager.new()

	Logger.debug("Initialized DungeonPathGenerator, TreeBoundaryGenerator, SpawnZoneManager, SpawnZone container, PathSnapshotAnalyzer, and ArenaTileManager", "pathgen")

func generate_path_aware_arena():
	Logger.info("🛤️ Starting path-aware arena generation...", "pathgen")

	# Clear previous generation
	clear_arena()

	# Ensure systems are initialized
	if not path_generator or not tree_generator:
		Logger.warn("Systems not initialized, calling _initialize_systems()", "pathgen")
		_initialize_systems()

	# Initialize RNG
	rng = RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Validate configurations
	if not _validate_configurations():
		Logger.warn("Invalid configurations, aborting generation", "pathgen")
		return

	# Phase 1: Generate paths using DungeonPathGenerator
	if not path_generator:
		Logger.error("DungeonPathGenerator is null, cannot generate paths", "pathgen")
		return

	current_path_data = path_generator.generate_dungeon_paths(generation_seed)
	if current_path_data.is_empty():
		Logger.warn("No path data generated, aborting arena generation", "pathgen")
		return

	# Phase 2: Generate tree boundaries using TreeBoundaryGenerator (Path Drives → Boundary Responds)
	if not tree_generator:
		Logger.error("TreeBoundaryGenerator is null, cannot generate trees", "treegen")
		return

	# Trees should avoid the complete visual area (path corridors only) for natural boundaries
	# path_extension_width parameter removed - no extension data needed
	current_tree_data = tree_generator.generate_tree_boundaries(current_path_data, generation_seed, {})

	# Phase 3: Create visual debug markers using dedicated renderer
	Logger.debug("Debug settings: show_debug_markers=%s, show_path_connections=%s" % [show_debug_markers, show_path_connections], "pathdebug")
	PathAwareDebugRenderer.render_debug_visualization(self)

	# Phase 4: Generate tiles using ArenaTileManager
	if not arena_tile_manager:
		Logger.warn("ArenaTileManager not initialized, creating default manager", "pathgen")
		arena_tile_manager = ArenaTileManager.new()

	arena_tile_manager.generate_all_tiles(self, current_path_data, current_tree_data)

	# Phase 5: Generate spawn zones at branch endpoints
	Logger.debug("About to call _generate_spawn_zones()...", "spawnzones")
	_generate_spawn_zones()
	Logger.debug("Finished calling _generate_spawn_zones()", "spawnzones")

	Logger.info("🛤️ Path-aware arena generation completed!", "pathgen")
	Logger.info("  - Points generated: %d" % current_path_data.get("points", []).size(), "pathgen")
	Logger.info("  - Paths generated: %d" % current_path_data.get("paths", []).size(), "pathgen")
	Logger.info("  - Trees generated: %d" % current_tree_data.size(), "pathgen")
	Logger.info("  - Spawn zones generated: %d" % spawn_zone_manager.get_spawn_zone_count(), "pathgen")

func clear_arena():
	"""Clear all generated content"""
	# Clear debug markers
	for marker in debug_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	debug_markers.clear()

	# Clear debug lines
	for line in debug_lines:
		if is_instance_valid(line):
			line.queue_free()
	debug_lines.clear()

	# Clear spawn zones using SpawnZoneManager
	if spawn_zone_manager:
		spawn_zone_manager.clear_managed_zones()

	# Clear tile map layers using ArenaTileManager
	if arena_tile_manager:
		# Note: Could add a clear_all_tiles method to ArenaTileManager if needed
		# For now, the next generation will clear tiles as needed
		pass

## Validate that both configurations are properly assigned
func _validate_configurations() -> bool:
	var is_valid = true

	if not path_config:
		Logger.warn("No PathConfiguration assigned, creating default", "pathgen")
		path_config = PathConfiguration.new()
		# Only set if path_generator exists
		if path_generator:
			path_generator.path_config = path_config

	if not tree_config:
		Logger.warn("No TreeBoundaryConfiguration assigned, creating default", "treegen")
		tree_config = TreeBoundaryConfiguration.new()
		# Only set if tree_generator exists
		if tree_generator:
			tree_generator.tree_config = tree_config

	if not path_config or not path_config.enable_path_generation:
		Logger.warn("Path generation disabled in configuration", "pathgen")
		is_valid = false

	return is_valid

# Editor tool functionality
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not path_config:
		warnings.append("PathConfiguration is required for path generation")

	if not tree_config:
		warnings.append("TreeBoundaryConfiguration is required for tree boundary generation")

	return warnings

# Manual generation trigger for testing
func generate_with_new_seed():
	generation_seed += 1
	generate_path_aware_arena()

# Get generated data for external use
func get_path_points() -> Array:
	return current_path_data.get("points", [])

func get_path_connections() -> Array:
	return current_path_data.get("paths", [])

func get_boundary_tree_positions() -> Array[Vector2]:
	return current_tree_data

## Create a comprehensive path snapshot for spawning systems
func get_path_snapshot() -> PathAwarePathSnapshot:
	# Delegate to PathSnapshotAnalyzer for all snapshot creation logic
	if not path_snapshot_analyzer:
		Logger.warn("PathSnapshotAnalyzer not initialized, creating default analyzer", "pathgen")
		path_snapshot_analyzer = PathSnapshotAnalyzer.new()

	return path_snapshot_analyzer.create_snapshot(current_path_data, current_tree_data, generation_seed)

## Get comprehensive debug information from both systems
func get_system_debug_info() -> Dictionary:
	var debug_info = {
		"path_system": {},
		"tree_system": {},
		"orchestration": {
			"generation_seed": generation_seed,
			"path_data_size": current_path_data.size(),
			"tree_data_size": current_tree_data.size()
		}
	}

	if path_generator:
		debug_info.path_system = path_generator.get_debug_info()

	if tree_generator:
		debug_info.tree_system = tree_generator.get_debug_info()

	return debug_info

## Generate spawn zones at branch endpoints
func _generate_spawn_zones() -> void:
	"""Generate circular spawn zones at all branch endpoint positions"""
	Logger.debug("🎯 Starting spawn zone generation...", "spawnzones")

	# Use the same logic as PathAwareMapConfig to get branch endpoint positions
	var snapshot = get_path_snapshot()
	if not snapshot:
		Logger.warn("No path snapshot available for spawn zone generation", "spawnzones")
		return

	# Create a temporary PathAwareMapConfig to get consistent endpoint positions
	var temp_config = PathAwareMapConfig.new()
	temp_config.path_snapshot = snapshot

	# Get branch endpoint positions that match the red markers
	var endpoint_positions = temp_config._get_branch_endpoint_positions()

	if endpoint_positions.is_empty():
		Logger.debug("No branch endpoints found for spawn zone generation", "spawnzones")
		return

	# Create spawn zones directly in the generator
	_create_spawn_zones_directly(endpoint_positions)

	Logger.debug("✅ Spawn zone generation completed: %d zones created" % spawn_zone_manager.get_spawn_zone_count(), "spawnzones")

## Create spawn zones directly without separate script
func _create_spawn_zones_directly(endpoint_positions: Array) -> void:
	"""Create functional Area2D spawn zones with visual indicators at endpoint positions"""
	# Use SpawnZoneManager to create functional zones with visual indicators
	Logger.info("Creating spawn zones using SpawnZoneManager...", "spawnzones")
	spawn_zone_manager.create_spawn_zones_at_positions(
		endpoint_positions, spawn_zone_container, spawn_zone_radius
	)

	Logger.info("✅ SpawnZoneManager created %d functional zones successfully" % spawn_zone_manager.get_spawn_zone_count(), "spawnzones")