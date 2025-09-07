extends Resource
class_name BossScaling

## BossScaling - Resource defining boss scaling multipliers for debug mode
## Used to make boss scaling configurable instead of hardcoded

@export var health_multiplier: float = 3.0
@export var damage_multiplier: float = 1.5
@export var speed_multiplier: float = 1.0
@export var size_multiplier: float = 1.2

func _init(
	p_health_multiplier: float = 3.0,
	p_damage_multiplier: float = 1.5,
	p_speed_multiplier: float = 1.0,
	p_size_multiplier: float = 1.2
) -> void:
	health_multiplier = p_health_multiplier
	damage_multiplier = p_damage_multiplier
	speed_multiplier = p_speed_multiplier
	size_multiplier = p_size_multiplier

func apply_scaling(boss_config) -> void:
	"""Apply scaling multipliers to a boss configuration object."""
	if boss_config.has("health"):
		boss_config.health *= health_multiplier
	if boss_config.has("damage"):
		boss_config.damage *= damage_multiplier
	if boss_config.has("speed"):
		boss_config.speed *= speed_multiplier
	if boss_config.has("size_scale"):
		boss_config.size_scale *= size_multiplier