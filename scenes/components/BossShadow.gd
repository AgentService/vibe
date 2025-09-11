extends Sprite2D

## Manual Boss Shadow - Simple sprite for ground shadows
## Features:
## - Fully manual positioning - drag in 2D editor or set Transform in Inspector
## - Configurable opacity and visibility
## - Renders below boss (z_index = -1)

class_name BossShadow

# Shadow configuration - visual properties only
@export var opacity: float = 0.6: set = _set_opacity  # Shadow transparency
@export var enabled: bool = true: set = _set_enabled  # Can disable shadows per-boss

func _ready() -> void:
	# Set initial properties
	z_index = -1  # Ensure shadow renders below boss
	modulate = Color(0, 0, 0, opacity)
	
	# Hide if disabled
	if not enabled:
		visible = false
		return
	
	# Shadow position and scale are now fully manual - set in scene tree

# All shadow positioning is now manual - use Transform in Inspector or drag in 2D editor

## Setters for Inspector properties
func _set_opacity(value: float) -> void:
	opacity = value
	modulate = Color(0, 0, 0, opacity)

func _set_enabled(value: bool) -> void:
	enabled = value
	visible = enabled

# Manual shadow positioning only - no automatic calculations
