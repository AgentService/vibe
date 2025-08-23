extends Resource
class_name PlayerBalance

## Player base stats and multipliers for progression and upgrades.

@export_range(0, 100) var projectile_count_add: int = 1
@export_range(0.1, 10.0) var projectile_speed_mult: float = 1.0
@export_range(0.1, 10.0) var fire_rate_mult: float = 3.0
@export_range(0.1, 10.0) var damage_mult: float = 1.0