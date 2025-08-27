extends Resource
class_name WavesBalance

## Wave director balance values including enemy spawning, movement, health, and arena constraints.

@export_range(1, 10000) var max_enemies: int = 100
@export var spawn_interval: float = 1.0
@export var arena_center: Vector2 = Vector2.ZERO
# spawn_radius moved to ArenaConfig - enemies spawn using arena configuration
@export var enemy_speed_min: float = 10.0
@export var enemy_speed_max: float = 20.0
@export_range(1, 100) var spawn_count_min: int = 3
@export_range(1, 100) var spawn_count_max: int = 8
@export var arena_bounds: float = 2500.0
@export var target_distance: float = 10.0
@export var enemy_culling_distance: float = 2000.0
@export_range(100, 20000) var enemy_transform_cache_size: int = 100
@export var enemy_viewport_cull_margin: float = 100.0
@export var enemy_update_distance: float = 2800.0
@export_range(0.1, 2.0) var camera_min_zoom: float = 1.0

# Enemy V2 System Configuration
@export var use_enemy_v2_system: bool = false
@export var v2_template_weights: Dictionary = {}

