extends Sprite2D

## Manual Boss Shadow - Simple sprite for ground shadows
## Features:
## - Fully manual positioning - drag in 2D editor or set Transform in Inspector
## - Configurable opacity and visibility
## - Renders below boss (z_index = -1)

class_name BossShadow

# Shadow configuration - visual properties only
@export var opacity: float = 0.6: set = _set_opacity  # Shadow transparency

func _ready() -> void:
	modulate = Color(0, 0, 0, opacity)

## Setters for Inspector properties
func _set_opacity(value: float) -> void:
	opacity = value
	modulate = Color(0, 0, 0, opacity)
