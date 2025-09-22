@tool
class_name ForestArenaGenerator
extends Node2D

## Procedural forest arena generator using the Raven Fantasy forest tileset
## Generates a simple arena with grass floor and tree borders

signal generation_complete()

@export var arena_size: Vector2i = Vector2i(40, 30)  # Size in tiles
@export var border_width: int = 3  # How many tiles deep the tree border is
@export var decoration_density: float = 0.05  # Chance of decoration per floor tile
@export var generation_seed: int = 12345  # For reproducible results

# Tree spacing controls
@export var tree_spacing_min: int = 2  # Minimum distance between trees
@export var tree_spacing_max: int = 5  # Maximum distance between trees (creates variation)
@export var tree_placement_chance: float = 0.6  # Chance to place tree (0.0-1.0, lower = more gaps)

# References to TileMapLayers
@onready var ground_layer: TileMapLayer = $Ground
@onready var trees_layer: TileMapLayer = $Boundaries
@onready var player_spawn: Marker2D = $PlayerSpawnPoint

# Tile mapping resource
var tile_mapping: ForestTileMapping

func _ready() -> void:
	# Set up Y-sorting for proper boundary element depth layering
	if trees_layer:
		trees_layer.y_sort_enabled = true

	# Only auto-generate when running the game, not in editor
	if Engine.is_editor_hint():
		return

	Logger.info("ForestArenaGenerator initializing", "map_generation")

	# Load tile mapping (we'll create this as a resource)
	tile_mapping = ForestTileMapping.new()

	# Generate on ready
	call_deferred("generate_arena")

func generate_arena() -> void:
	"""Generate the forest arena with the given parameters"""
	# Auto-increment seed for natural variation (unless called from editor)
	if not Engine.is_editor_hint():
		generation_seed += 1

	# Initialize tile mapping if not already done (for editor use)
	if not tile_mapping:
		tile_mapping = ForestTileMapping.new()

	# Ensure Y-sorting is enabled for proper boundary element depth layering
	if trees_layer:
		trees_layer.y_sort_enabled = true

	# Safe logging for editor mode
	if Engine.is_editor_hint():
		print("🌲 Starting forest arena generation with seed: ", generation_seed)
	else:
		Logger.info("Starting forest arena generation", "map_generation")

	# Set up RNG for reproducible results
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	
	# Clear existing tiles
	clear_arena()
	
	# Generate floor
	generate_floor(rng)
	
	# Generate tree borders
	generate_tree_borders(rng)
	
	# Add decorations
	add_decorations(rng)
	
	# Set player spawn point
	set_player_spawn()
	
	# Safe logging for editor mode
	if Engine.is_editor_hint():
		print("✅ Forest arena generation completed!")
	else:
		Logger.info("Forest arena generation completed", "map_generation")

	generation_complete.emit()

func clear_arena() -> void:
	"""Clear all tiles from the arena"""
	if ground_layer:
		ground_layer.clear()
	if trees_layer:
		trees_layer.clear()

func generate_floor(rng: RandomNumberGenerator) -> void:
	"""Generate grass floor tiles with natural variation"""
	if not Engine.is_editor_hint():
		Logger.debug("Generating floor tiles", "map_generation")

	if not ground_layer:
		if Engine.is_editor_hint():
			print("⚠️  Ground layer not found")
		else:
			Logger.warn("Ground layer not found", "map_generation")
		return
	
	# Fill the entire arena area with grass tiles (including tree border areas)
	var total_width = arena_size.x + (border_width * 2)
	var total_height = arena_size.y + (border_width * 2)

	for x in range(-total_width / 2, total_width / 2):
		for y in range(-total_height / 2, total_height / 2):
			var tile_pos := Vector2i(x, y)

			# Use the actual grass coordinates from your tileset
			var source_id := 0  # Main tileset source
			var atlas_coords := Vector2i(3, 0)  # Grass tile you manually placed

			ground_layer.set_cell(tile_pos, source_id, atlas_coords)

func generate_tree_borders(rng: RandomNumberGenerator) -> void:
	"""Generate tree borders around the arena perimeter"""
	if not Engine.is_editor_hint():
		Logger.debug("Generating tree borders", "map_generation")
	
	if not trees_layer:
		Logger.warn("Trees layer not found", "map_generation")
		return
	
	var half_width := arena_size.x / 2
	var half_height := arena_size.y / 2
	
	# Track all placed trees for circular spacing
	var placed_trees: Array[Vector2i] = []

	# Generate border trees with circular spacing
	for border_layer in range(border_width):
		# Calculate border bounds for this layer
		var layer_half_width := half_width + border_layer
		var layer_half_height := half_height + border_layer

		# Generate potential tree positions around the entire perimeter
		var potential_positions: Array[Vector2i] = []

		# Top and bottom borders
		for x in range(-layer_half_width, layer_half_width + 1):
			potential_positions.append(Vector2i(x, -layer_half_height))  # Top
			potential_positions.append(Vector2i(x, layer_half_height))   # Bottom

		# Left and right borders (excluding corners already added)
		for y in range(-layer_half_height + 1, layer_half_height):
			potential_positions.append(Vector2i(-layer_half_width, y))   # Left
			potential_positions.append(Vector2i(layer_half_width, y))    # Right

		# Place trees with proper circular spacing and chance
		for pos in potential_positions:
			if should_place_tree_with_spacing(pos, placed_trees, rng):
				place_border_tree(pos, rng)
				placed_trees.append(pos)

func should_place_tree_with_spacing(pos: Vector2i, placed_trees: Array[Vector2i], rng: RandomNumberGenerator) -> bool:
	"""Determine if a tree should be placed at this position with random circular spacing"""
	# First check placement chance
	if rng.randf() >= tree_placement_chance:
		return false

	# Check distance to all previously placed trees with random spacing requirement
	for existing_tree in placed_trees:
		var distance = pos.distance_to(existing_tree)
		# Each tree pair gets a random spacing requirement within the min/max range
		var required_spacing = rng.randi_range(tree_spacing_min, tree_spacing_max)
		if distance < required_spacing:
			return false  # Too close to another tree

	return true

func place_border_tree(pos: Vector2i, rng: RandomNumberGenerator) -> void:
	"""Place a tree tile at the given position with random variation"""
	if not trees_layer:
		if Engine.is_editor_hint():
			print("❌ Boundaries layer not found!")
		return

	# Tree variants for natural variety
	var tree_variants = [
		Vector2i(0, 28),   # Original tree
		Vector2i(9, 28)    # New tree variation
	]

	var source_id := 0
	var atlas_coords: Vector2i = tree_variants[rng.randi() % tree_variants.size()]

	trees_layer.set_cell(pos, source_id, atlas_coords)


func add_decorations(rng: RandomNumberGenerator) -> void:
	"""Add scattered decorative elements within the arena"""
	if not Engine.is_editor_hint():
		Logger.debug("Adding decorative elements", "map_generation")
	
	# Add decorations sparsely throughout the floor area
	for x in range(-arena_size.x / 2 + 2, arena_size.x / 2 - 2):
		for y in range(-arena_size.y / 2 + 2, arena_size.y / 2 - 2):
			if rng.randf() < decoration_density:
				var pos := Vector2i(x, y)
				
				# Small trees, bushes, etc.
				var decoration_variant := rng.randi() % 2
				var source_id := 0
				var atlas_coords := Vector2i(4 + decoration_variant, 0)  # Decoration tiles
				
				trees_layer.set_cell(pos, source_id, atlas_coords)

func set_player_spawn() -> void:
	"""Set the player spawn point at the center of the arena"""
	if player_spawn:
		player_spawn.position = Vector2.ZERO
		Logger.debug("Player spawn set to center", "map_generation")

func get_arena_bounds() -> Rect2i:
	"""Get the bounds of the generated arena"""
	var half_width := arena_size.x / 2
	var half_height := arena_size.y / 2
	return Rect2i(-half_width, -half_height, arena_size.x, arena_size.y)

func regenerate_with_seed(new_seed: int) -> void:
	"""Regenerate the arena with a new seed"""
	generation_seed = new_seed
	generate_arena()

# Debug function to test generation
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_refresh"):  # F5
		Logger.info("Regenerating arena (debug)", "map_generation")
		regenerate_with_seed(randi())
