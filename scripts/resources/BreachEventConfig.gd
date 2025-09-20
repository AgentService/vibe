extends Resource
class_name BreachEventConfig

## Configuration resource for breach event parameters
## Allows hot-reload tuning and easy balancing adjustments

@export_group("Timing Parameters")
@export var expand_duration: float = 10.0  ## Circle expansion time in seconds
@export var shrink_duration: float = 10.0  ## Circle shrinking time in seconds

@export_group("Size Parameters")
@export var initial_radius: float = 30.0   ## Small touch circle for activation
@export var max_radius: float = 150.0      ## Full expansion size

@export_group("Phantom Enemy System")
@export var total_breach_enemies: int = 50 ## Total phantom positions distributed across the zone

@export_group("Visual Effects")
@export var enemy_modulate: Color = Color(0.8, 0.3, 1.0, 0.9)  ## Purple tint for breach enemies
@export var pulse_speed: float = 4.0       ## Pulse animation speed for waiting breaches

@export_group("Distance Controls")
@export var min_breach_distance: float = 200.0  ## Minimum distance between breaches
@export var max_simultaneous_breaches: int = 3  ## Maximum number of active breaches

@export_group("Performance Settings")
@export var redraw_frequency: int = 3      ## Redraw every N frames (higher = less smooth but better performance)

## Validate configuration values
func validate() -> bool:
	if expand_duration <= 0 or shrink_duration <= 0:
		push_error("BreachEventConfig: Duration values must be positive")
		return false

	if initial_radius <= 0 or max_radius <= initial_radius:
		push_error("BreachEventConfig: Radius values must be positive and max > initial")
		return false

	if total_breach_enemies <= 0:
		push_error("BreachEventConfig: Total breach enemies must be positive")
		return false

	return true

## Get total event duration
func get_total_duration() -> float:
	return expand_duration + shrink_duration

## Get total enemies for phantom generation
func get_total_enemies_spawned() -> int:
	return total_breach_enemies
