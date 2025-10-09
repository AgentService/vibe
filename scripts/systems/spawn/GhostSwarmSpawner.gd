class_name GhostSwarmSpawner
extends Node

## Ghost Swarm event spawner for visual spectacle waves
## Spawns 1000+ non-interactive ghosts that charge the player
## Uses MultiMesh rendering for maximum performance

# Configuration
@export var ghost_count: int = 1000  ## Number of ghosts in wave
@export var spawn_radius: float = 800.0  ## Radius to spawn ghosts around player
@export var charge_speed: float = 200.0  ## Speed ghosts move toward player
@export var ghost_modulate: Color = Color(0.8, 0.9, 1.0, 0.7)  ## Ghost tint color

# Ghost state (simple arrays for performance)
var _ghost_positions: PackedVector2Array
var _ghost_velocities: PackedVector2Array
var _is_active: bool = false

# References
var _multimesh_manager: MultiMeshManager
var _player_position: Vector2

## Initialize spawner with MultiMeshManager reference
func setup(multimesh_manager: MultiMeshManager) -> void:
	_multimesh_manager = multimesh_manager
	Logger.info("GhostSwarmSpawner initialized", "ghost")

## Spawn a ghost wave around the player
func spawn_ghost_wave(player_pos: Vector2, count: int = 0) -> void:
	if _is_active:
		Logger.warn("Ghost wave already active, clearing previous wave first", "ghost")
		clear_ghost_wave()

	# Use provided count or default
	var spawn_count = count if count > 0 else ghost_count

	_ghost_positions.resize(spawn_count)
	_ghost_velocities.resize(spawn_count)

	# Spawn ghosts in circle around player
	for i in range(spawn_count):
		var angle = (i / float(spawn_count)) * TAU
		var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
		_ghost_positions[i] = player_pos + offset

		# Calculate initial velocity toward player
		var direction = (player_pos - _ghost_positions[i]).normalized()
		_ghost_velocities[i] = direction * charge_speed

	_is_active = true
	_player_position = player_pos

	# Apply ghost visual style
	if _multimesh_manager:
		_multimesh_manager.set_ghost_modulate(ghost_modulate)
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

	Logger.info("Ghost wave spawned: %d ghosts at radius %.0f" % [spawn_count, spawn_radius], "ghost")

## Update ghost positions every frame (simple chase AI)
func _process(delta: float) -> void:
	if not _is_active or _ghost_positions.size() == 0:
		return

	# Get current player position
	if not PlayerState.has_player_reference():
		return

	_player_position = PlayerState.position

	# Update all ghost positions (simple chase behavior)
	for i in range(_ghost_positions.size()):
		# Recalculate direction toward player
		var direction = (_player_position - _ghost_positions[i]).normalized()
		_ghost_velocities[i] = direction * charge_speed

		# Apply velocity
		_ghost_positions[i] += _ghost_velocities[i] * delta

	# Update rendering
	if _multimesh_manager:
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

## Clear the ghost wave
func clear_ghost_wave() -> void:
	_is_active = false
	_ghost_positions.clear()
	_ghost_velocities.clear()

	if _multimesh_manager:
		_multimesh_manager.clear_ghost_swarm()

	Logger.debug("Ghost wave cleared", "ghost")

## Check if ghost wave is active
func is_active() -> bool:
	return _is_active

## Get current ghost count
func get_ghost_count() -> int:
	return _ghost_positions.size()

## Set ghost color modulation
func set_ghost_color(color: Color) -> void:
	ghost_modulate = color
	if _multimesh_manager:
		_multimesh_manager.set_ghost_modulate(color)

## Set ghost charge speed
func set_charge_speed(speed: float) -> void:
	charge_speed = speed
	# Update velocities for active ghosts
	if _is_active:
		for i in range(_ghost_velocities.size()):
			var direction = (_player_position - _ghost_positions[i]).normalized()
			_ghost_velocities[i] = direction * charge_speed
