extends Resource
class_name VisualFeedbackConfig

## Configuration resource for visual feedback effects (flash, knockback, etc.)
## Data-driven approach for tuning hit feedback parameters

@export_group("Flash Effect")
@export var flash_duration: float = 0.12
@export var flash_fade_duration: float = 0.08
@export var flash_intensity: float = 1.0
@export var flash_color: Color = Color.WHITE
@export var flash_curve: Curve

@export_group("Knockback Effect")
@export var knockback_duration: float = 0.15
@export var knockback_curve: Curve
@export var knockback_friction: float = 0.8

@export_group("Boss Flash Override")
@export var boss_flash_duration: float = 0.2  ## Flash duration override for bosses
@export var boss_flash_intensity: float = 15.0  ## Flash intensity override for bosses

@export_group("Performance Limits")
@export var max_boss_effects: int = 50  ## Maximum number of boss effects to track
@export var boss_scanner_interval: float = 3.0  ## How often to scan for new bosses (seconds)

func _init() -> void:
	# Set default curves if not provided
	if not flash_curve:
		flash_curve = Curve.new()
		flash_curve.add_point(Vector2(0.0, 1.0))  # Start at full intensity
		flash_curve.add_point(Vector2(0.6, 0.8))  # Hold high
		flash_curve.add_point(Vector2(1.0, 0.0))  # Fade to normal
	
	if not knockback_curve:
		knockback_curve = Curve.new()
		knockback_curve.add_point(Vector2(0.0, 1.0))  # Start at full force
		knockback_curve.add_point(Vector2(0.3, 0.6))  # Quick falloff
		knockback_curve.add_point(Vector2(1.0, 0.0))  # Stop
