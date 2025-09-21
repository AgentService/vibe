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

@export_group("Dynamic Ring Spawning")
@export var ring_spawn_interval: float = 50.0 ## Spawn new ring every N pixels of expansion
@export var enemy_density: float = 0.033     ## Enemies per pixel of circumference (~1 per 30px)
@export var edge_spawn_factor: float = 0.87  ## Spawn at 87% of radius (middle of 85-90% range)
@export var sector_count: int = 16           ## Divide circle into N sectors for distribution

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

	if ring_spawn_interval <= 0:
		push_error("BreachEventConfig: Ring spawn interval must be positive")
		return false

	if enemy_density <= 0:
		push_error("BreachEventConfig: Enemy density must be positive")
		return false

	if edge_spawn_factor <= 0 or edge_spawn_factor > 1:
		push_error("BreachEventConfig: Edge spawn factor must be between 0 and 1")
		return false

	if sector_count <= 0:
		push_error("BreachEventConfig: Sector count must be positive")
		return false

	return true

## Get total event duration
func get_total_duration() -> float:
	return expand_duration + shrink_duration

## Calculate expected rings for given expansion
func get_expected_ring_count(max_expansion: float) -> int:
	return int(max_expansion / ring_spawn_interval)

## Calculate enemies per ring at given radius
func get_ring_enemy_count(radius: float) -> int:
	var circumference = 2 * PI * radius
	var edge_circumference = circumference * edge_spawn_factor
	return max(3, int(edge_circumference * enemy_density))
