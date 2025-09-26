@tool
class_name DecorationThemeConfig
extends Resource

## Configuration for themed decoration groups with clustering and weight control
## Allows fine-tuned control over decoration placement by color/theme groups

@export_group("Theme Identity")
@export var theme_name: String = ""  ## Name of this decoration theme (e.g., "Rocks", "Flowers", "Vegetation")
@export var theme_color: Color = Color.WHITE  ## Representative color for editor visualization
@export var description: String = ""  ## Brief description of this theme

@export_group("Tile Configuration")
@export var decoration_tiles: Array[Vector2i] = []  ## Tile coordinates for this theme
@export var tile_size: Vector2i = Vector2i(3, 3)  ## Size of each decoration tile (for proper spacing)

@export_group("Spawn Probability")
@export var spawn_weight: float = 1.0  ## Relative weight compared to other themes (higher = more common)
@export var rarity_modifier: float = 1.0  ## Additional rarity control (0.1 = very rare, 2.0 = very common)
@export var min_spacing: int = 2  ## Minimum tiles between decorations of this theme
@export var max_spacing: int = 8  ## Maximum spacing for this theme

@export_group("Clustering Behavior")
@export var enable_clustering: bool = true  ## Whether this theme should cluster together
@export var cluster_chance: float = 0.7  ## Chance to spawn near same theme (0.0-1.0)
@export var cluster_radius: int = 5  ## Search radius for clustering (tiles)
@export var max_cluster_size: int = 4  ## Maximum decorations in a cluster
@export var cluster_decay: float = 0.6  ## How much cluster chance decreases per existing decoration

@export_group("Environmental Preferences")
@export var prefer_edges: bool = false  ## Prefer spawning near arena edges
@export var prefer_center: bool = false  ## Prefer spawning near arena center
@export var avoid_boundaries: bool = true  ## Avoid spawning too close to tree boundaries
@export var boundary_buffer: int = 3  ## Minimum distance from boundaries (if avoiding)

@export_group("Z-Layer Configuration")
@export var z_layer: int = 1  ## Z-layer for depth sorting (0=background, 1=middle, 2=foreground)
@export var layer_name: String = ""  ## Optional custom layer name for organization

func get_effective_spawn_weight() -> float:
	"""Calculate final spawn weight including rarity modifier"""
	return spawn_weight * rarity_modifier

func get_random_tile(rng: RandomNumberGenerator) -> Vector2i:
	"""Get a random tile from this theme"""
	if decoration_tiles.is_empty():
		return Vector2i(0, 0)
	return decoration_tiles[rng.randi() % decoration_tiles.size()]

func should_cluster_near(existing_positions: Array[Vector2i], test_position: Vector2i, rng: RandomNumberGenerator) -> bool:
	"""Check if this decoration should cluster near existing ones of the same theme"""
	if not enable_clustering:
		return false

	var nearby_count := 0
	for pos in existing_positions:
		var distance := test_position.distance_to(pos)
		if distance <= cluster_radius:
			nearby_count += 1

	# Stop clustering if we hit max cluster size
	if nearby_count >= max_cluster_size:
		return false

	# Calculate cluster chance with decay
	var effective_cluster_chance := cluster_chance * pow(cluster_decay, nearby_count)
	return rng.randf() < effective_cluster_chance

func get_environmental_preference_modifier(position: Vector2i, arena_center: Vector2i, arena_bounds: Rect2i) -> float:
	"""Get spawn preference modifier based on environmental preferences"""
	var modifier := 1.0

	if prefer_edges or prefer_center:
		var center_distance := position.distance_to(arena_center)
		var max_distance := arena_bounds.size.length() / 2.0
		var distance_ratio := center_distance / max_distance

		if prefer_center:
			# Prefer positions closer to center
			modifier *= (1.0 - distance_ratio) * 2.0
		elif prefer_edges:
			# Prefer positions closer to edges
			modifier *= distance_ratio * 2.0

	return clamp(modifier, 0.1, 3.0)

func is_valid() -> bool:
	"""Validate configuration"""
	return not theme_name.is_empty() and \
		   not decoration_tiles.is_empty() and \
		   spawn_weight > 0.0 and \
		   rarity_modifier > 0.0
