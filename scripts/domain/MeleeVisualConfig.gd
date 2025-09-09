extends Resource
class_name MeleeVisualConfig

## Configuration for melee attack visual effects
## Controls cone color, transparency, duration, scaling

@export var cone_color: Color = Color(1.0, 0.2, 0.2, 0.3)  # Red with transparency
@export var fade_duration: float = 0.2  # How long fade-out takes
@export var max_opacity: float = 0.3  # Peak transparency during attack
@export var scale_with_range: bool = true  # Scale cone with attack range
@export var base_range_reference: float = 100.0  # What range the cone design assumes
@export var rotation_offset: float = -90.0  # Degrees to rotate cone (fix alignment)
