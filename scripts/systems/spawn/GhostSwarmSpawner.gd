class_name GhostSwarmSpawner
extends Node

## Ghost Swarm event spawner for visual spectacle waves
## Spawns 1000+ ghosts that charge the player with separation forces
## Uses MultiMesh rendering for maximum performance + collision detection

# Configuration
@export var ghost_count: int = 1000  ## Number of ghosts in wave
@export var spawn_radius: float = 800.0  ## Radius to spawn ghosts around player
@export var charge_speed: float = 200.0  ## Speed ghosts move toward player
@export var ghost_modulate: Color = Color(0.8, 0.9, 1.0, 0.7)  ## Ghost tint color
@export var separation_force: float = 50.0  ## Force to keep ghosts separated
@export var separation_radius: float = 24.0  ## Min distance between ghosts
@export var ghost_health: float = 10.0  ## Health per ghost

# Ghost state (simple arrays for performance)
var _ghost_positions: PackedVector2Array
var _ghost_velocities: PackedVector2Array
var _ghost_healths: PackedFloat32Array  # Health tracking for each ghost
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
	_ghost_healths.resize(spawn_count)

	# Spawn ghosts in circle around player with staggered radii for spacing
	for i in range(spawn_count):
		var angle = (i / float(spawn_count)) * TAU
		# Randomize radius slightly to create depth and prevent perfect circle
		var radius_variance = randf_range(0.8, 1.2)
		var offset = Vector2(cos(angle), sin(angle)) * (spawn_radius * radius_variance)
		_ghost_positions[i] = player_pos + offset

		# Calculate initial velocity toward player
		var direction = (player_pos - _ghost_positions[i]).normalized()
		_ghost_velocities[i] = direction * charge_speed

		# Initialize health
		_ghost_healths[i] = ghost_health

	_is_active = true
	_player_position = player_pos

	# Apply ghost visual style
	if _multimesh_manager:
		_multimesh_manager.set_ghost_modulate(ghost_modulate)
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

	Logger.info("Ghost wave spawned: %d ghosts at radius %.0f" % [spawn_count, spawn_radius], "ghost")

## Update ghost positions every frame (chase AI + separation forces)
func _process(delta: float) -> void:
	if not _is_active or _ghost_positions.size() == 0:
		return

	# Get current player position
	if not PlayerState.has_player_reference():
		return

	_player_position = PlayerState.position

	# Update all ghost positions with chase + separation
	for i in range(_ghost_positions.size()):
		# Skip dead ghosts
		if _ghost_healths[i] <= 0:
			continue

		# Chase behavior - move toward player
		var direction = (_player_position - _ghost_positions[i]).normalized()
		var chase_velocity = direction * charge_speed

		# Separation behavior - avoid stacking with nearby ghosts
		var separation_velocity = Vector2.ZERO
		var nearby_count = 0

		# Check nearby ghosts (simplified - only check subset for performance)
		var check_step = max(1, _ghost_positions.size() / 100)  # Check ~100 ghosts max
		for j in range(0, _ghost_positions.size(), check_step):
			if i == j or _ghost_healths[j] <= 0:
				continue

			var to_other = _ghost_positions[i] - _ghost_positions[j]
			var distance = to_other.length()

			if distance < separation_radius and distance > 0.1:
				# Push away from nearby ghost
				separation_velocity += to_other.normalized() * (separation_radius - distance)
				nearby_count += 1

		if nearby_count > 0:
			separation_velocity = separation_velocity / nearby_count * separation_force

		# Combine velocities
		_ghost_velocities[i] = chase_velocity + separation_velocity

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
	_ghost_healths.clear()

	if _multimesh_manager:
		_multimesh_manager.clear_ghost_swarm()

	Logger.debug("Ghost wave cleared", "ghost")

## Check if a projectile/ability hit any ghosts and apply damage
## Returns array of ghost indices that were hit
func check_hits_in_area(center: Vector2, radius: float, damage: float) -> Array[int]:
	var hit_indices: Array[int] = []

	if not _is_active:
		return hit_indices

	var radius_sq = radius * radius

	for i in range(_ghost_positions.size()):
		# Skip dead ghosts
		if _ghost_healths[i] <= 0:
			continue

		# Check if ghost is within damage radius
		var distance_sq = _ghost_positions[i].distance_squared_to(center)
		if distance_sq <= radius_sq:
			# Apply damage
			_ghost_healths[i] -= damage

			if _ghost_healths[i] <= 0:
				# Ghost died - hide it by moving off-screen
				_ghost_positions[i] = Vector2(-10000, -10000)
				Logger.debug("Ghost %d killed by ability" % i, "ghost")

			hit_indices.append(i)

	return hit_indices

## Get all living ghost positions (for ability targeting)
func get_living_ghost_positions() -> PackedVector2Array:
	var living_positions: PackedVector2Array = PackedVector2Array()

	if not _is_active:
		return living_positions

	for i in range(_ghost_positions.size()):
		if _ghost_healths[i] > 0:
			living_positions.append(_ghost_positions[i])

	return living_positions

## Get ghost position and health by index (for ability queries)
func get_ghost_at_index(index: int) -> Dictionary:
	if index < 0 or index >= _ghost_positions.size():
		return {}

	return {
		"position": _ghost_positions[index],
		"health": _ghost_healths[index],
		"is_alive": _ghost_healths[index] > 0
	}

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
