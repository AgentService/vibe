extends Resource
class_name CombatBalance

## Combat system balance values including collision detection, damage, and critical hit mechanics.

@export var projectile_radius: float = 4.0
@export var enemy_radius: float = 12.0
@export var base_damage: float = 25.0
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export_range(1.0, 10.0) var crit_multiplier: float = 2.0

## Zero-allocation damage queue configuration
@export var use_zero_alloc_damage_queue: bool = false
@export var damage_queue_capacity: int = 4096
@export var damage_pool_size: int = 4096
@export var damage_queue_max_per_tick: int = 2048
@export var damage_queue_tick_rate_hz: float = 30.0

