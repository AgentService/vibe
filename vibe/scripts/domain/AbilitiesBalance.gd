extends Resource
class_name AbilitiesBalance

## Ability system balance values including projectile pools, speeds, time-to-live, and arena boundaries.

@export_range(1, 10000) var max_projectiles: int = 2000
@export var projectile_speed: float = 320.0
@export var projectile_ttl: float = 4.5
@export var arena_bounds: float = 3000.0
@export var projectile_culling_distance: float = 1500.0