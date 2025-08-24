extends Resource
class_name MeleeBalance

## Melee combat balance values including damage, range, and attack properties.

@export var damage: float = 55.0
@export var range: float = 250.0
@export_range(0.0, 360.0) var cone_angle: float = 90.0
@export var attack_speed: int = 2
@export var visual_effect_duration: float = 0.5