extends Resource
class_name CombatBalance

## Combat system balance values including collision detection, damage, and critical hit mechanics.

@export var projectile_radius: float = 4.0
@export var enemy_radius: float = 12.0
@export var base_damage: float = 25.0
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export_range(1.0, 10.0) var crit_multiplier: float = 2.0
