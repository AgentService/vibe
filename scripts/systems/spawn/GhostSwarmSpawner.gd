class_name GhostSwarmSpawner
extends Node

## Ghost Swarm event spawner for visual spectacle waves
## Spawns 1000+ ghosts that charge the player with separation forces
## Uses MultiMesh rendering for maximum performance + collision detection
## Stats loaded from EnemyTemplate resource for scaling support

# Configuration
@export var ghost_count: int = 400  ## Total number of ghosts to spawn
@export var spawn_radius: float = 1200.0  ## Radius to spawn ghosts around player
@export var ghost_template_path: String = "res://data/content/enemy-templates/ghost_swarm.tres"  ## Ghost stats resource
@export var ghost_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)  ## Ghost tint color (default: no tint)
@export var separation_force: float = 550.0  ## Force to keep ghosts separated
@export var separation_radius: float = 54.0  ## Min distance between ghosts
@export var max_ghost_count: int = 1500  ## Maximum total ghosts allowed (prevents lag)

# Wave spawning configuration
@export var wave_spawn_enabled: bool = true  ## Spawn ghosts in waves instead of all at once
@export var ghosts_per_wave: int = 30  ## Number of ghosts to spawn per wave (smaller = more challenging)
@export var wave_delay_min: float = 0.15  ## Minimum delay between waves (seconds)
@export var wave_delay_max: float = 0.55  ## Maximum delay between waves (seconds)

# Loaded stats from template
var charge_speed: float = 320.0  ## Speed ghosts move toward player (from template)
var ghost_health: float = 10.0  ## Health per ghost (from template)

# Ghost state (simple arrays for performance)
var _ghost_positions: PackedVector2Array
var _ghost_velocities: PackedVector2Array
var _ghost_healths: PackedFloat32Array  # Health tracking for each ghost
var _is_active: bool = false

# Compaction tracking (prevents memory leak from dead ghosts)
var _frames_since_compaction: int = 0
const COMPACTION_INTERVAL_FRAMES: int = 150  # ~5 seconds at 30Hz

# Wave spawning state
var _wave_spawn_timer: Timer = null
var _wave_spawn_in_progress: bool = false
var _wave_spawn_remaining: int = 0
var _wave_spawn_player_pos: Vector2 = Vector2.ZERO

# References
var _multimesh_manager: MultiMeshManager
var _player_position: Vector2

## Initialize spawner with MultiMeshManager reference
func setup(multimesh_manager: MultiMeshManager) -> void:
	_multimesh_manager = multimesh_manager
	_load_ghost_template()

	# Setup wave spawn timer
	_wave_spawn_timer = Timer.new()
	_wave_spawn_timer.one_shot = true
	_wave_spawn_timer.timeout.connect(_on_wave_spawn_timer_timeout)
	add_child(_wave_spawn_timer)

	Logger.info("GhostSwarmSpawner initialized (speed: %.0f, health: %.0f, wave_mode: %s)" % [charge_speed, ghost_health, wave_spawn_enabled], "ghost")

## Load ghost stats from EnemyTemplate resource
func _load_ghost_template() -> void:
	if not ResourceLoader.exists(ghost_template_path):
		Logger.warn("Ghost template not found: %s (using defaults)" % ghost_template_path, "ghost")
		return

	var template = load(ghost_template_path) as EnemyTemplate
	if not template:
		Logger.warn("Failed to load ghost template as EnemyTemplate", "ghost")
		return

	# Apply stats from template with RNG variation
	var spawn_rng = RNG.stream("spawn")
	charge_speed = lerp(template.speed_range.x, template.speed_range.y, spawn_rng.randf())
	ghost_health = lerp(template.health_range.x, template.health_range.y, spawn_rng.randf())

	Logger.debug("Ghost template loaded: speed=%.0f, health=%.0f" % [charge_speed, ghost_health], "ghost")

## Spawn a ghost wave around the player (additive - stacks with existing ghosts)
func spawn_ghost_wave(player_pos: Vector2, count: int = 0) -> void:
	# Use provided count or default
	var spawn_count = count if count > 0 else ghost_count

	# Wave-based spawning: Start wave sequence instead of instant spawn
	if wave_spawn_enabled and spawn_count > ghosts_per_wave:
		_start_wave_spawn_sequence(player_pos, spawn_count)
		return

	# Instant spawn (disabled wave mode or small count)
	_spawn_ghost_batch(player_pos, spawn_count)

## Start wave-based spawning sequence with random delays
func _start_wave_spawn_sequence(player_pos: Vector2, total_count: int) -> void:
	# Allow restarting wave sequence for continuous spawning
	if _wave_spawn_in_progress:
		Logger.debug("Restarting wave spawn sequence at new position", "ghost")
		_wave_spawn_timer.stop()  # Cancel current wave timer

	_wave_spawn_in_progress = true
	_wave_spawn_remaining = total_count
	_wave_spawn_player_pos = player_pos

	Logger.info("Starting wave spawn: %d ghosts in %d waves (delay: %.2f-%.2f s)" % [
		total_count,
		ceil(float(total_count) / ghosts_per_wave),
		wave_delay_min,
		wave_delay_max
	], "ghost")

	# Spawn first wave immediately
	_spawn_next_wave()

## Spawn next wave in sequence
func _spawn_next_wave() -> void:
	if _wave_spawn_remaining <= 0:
		_wave_spawn_in_progress = false
		Logger.info("Wave spawn complete", "ghost")
		return

	# Calculate wave size (last wave might be smaller)
	var wave_size = mini(_wave_spawn_remaining, ghosts_per_wave)

	# Spawn this wave
	_spawn_ghost_batch(_wave_spawn_player_pos, wave_size)

	# Update remaining count
	_wave_spawn_remaining -= wave_size

	# Schedule next wave with random delay
	if _wave_spawn_remaining > 0:
		var delay = randf_range(wave_delay_min, wave_delay_max)
		_wave_spawn_timer.start(delay)

## Timer callback for wave spawning
func _on_wave_spawn_timer_timeout() -> void:
	_spawn_next_wave()

## Spawn a batch of ghosts immediately (internal method)
func _spawn_ghost_batch(player_pos: Vector2, spawn_count: int) -> void:
	# Get current ghost count (for additive spawning)
	var current_count = _ghost_positions.size()

	# Enforce max ghost count cap (prevents lag from too many ghosts)
	if current_count >= max_ghost_count:
		Logger.warn("Ghost spawn blocked: already at max capacity (%d/%d)" % [current_count, max_ghost_count], "ghost")
		return

	# Clamp spawn count to not exceed max
	if current_count + spawn_count > max_ghost_count:
		var clamped_count = max_ghost_count - current_count
		Logger.debug("Ghost spawn clamped: %d → %d (would exceed max %d)" % [spawn_count, clamped_count, max_ghost_count], "ghost")
		spawn_count = clamped_count

	var new_total = current_count + spawn_count

	# Resize arrays to accommodate new ghosts
	_ghost_positions.resize(new_total)
	_ghost_velocities.resize(new_total)
	_ghost_healths.resize(new_total)

	# Spawn new ghosts scattered around player with randomized positions
	for i in range(spawn_count):
		var ghost_index = current_count + i  # Append after existing ghosts

		# Base angle with randomized offset for natural distribution
		var base_angle = (i / float(spawn_count)) * TAU
		var angle_jitter = randf_range(-0.3, 0.3)  # ±17 degrees of randomization
		var angle = base_angle + angle_jitter

		# Randomize radius to create depth and break perfect circle pattern
		var radius_variance = randf_range(0.7, 1.3)  # Wider variance for more spread
		var offset = Vector2(cos(angle), sin(angle)) * (spawn_radius * radius_variance)
		_ghost_positions[ghost_index] = player_pos + offset

		# Calculate initial velocity toward player
		var direction = (player_pos - _ghost_positions[ghost_index]).normalized()
		_ghost_velocities[ghost_index] = direction * charge_speed

		# Initialize health
		_ghost_healths[ghost_index] = ghost_health

	_is_active = true
	_player_position = player_pos

	# Apply ghost visual style
	if _multimesh_manager:
		_multimesh_manager.set_ghost_modulate(ghost_modulate)
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

	Logger.debug("Ghost batch spawned: +%d ghosts (total: %d)" % [spawn_count, new_total], "ghost")

## Update ghost positions at fixed timestep (30Hz via physics_process)
## PERFORMANCE: Disabled separation forces for 500+ ghosts (100k+ distance checks/frame)
func _physics_process(delta: float) -> void:
	if not _is_active or _ghost_positions.size() == 0:
		return

	# Get current player position
	if not PlayerState.has_player_reference():
		return

	_player_position = PlayerState.position

	# Performance mode: Skip separation for high ghost counts
	var use_separation = _ghost_positions.size() < 500

	# Update all ghost positions with chase AI only (separation disabled for 500+ ghosts)
	for i in range(_ghost_positions.size()):
		# Skip dead ghosts
		if _ghost_healths[i] <= 0:
			continue

		# Chase behavior - move toward player
		var direction = (_player_position - _ghost_positions[i]).normalized()
		var chase_velocity = direction * charge_speed

		# Separation behavior - only for <500 ghosts (performance)
		var separation_velocity = Vector2.ZERO
		if use_separation:
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

		# Combine velocities (separation is zero vector if disabled)
		_ghost_velocities[i] = chase_velocity + separation_velocity

		# Apply velocity
		_ghost_positions[i] += _ghost_velocities[i] * delta

	# Update rendering
	if _multimesh_manager:
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

	# Periodic compaction to remove dead ghosts (prevents memory leak)
	_frames_since_compaction += 1
	if _frames_since_compaction >= COMPACTION_INTERVAL_FRAMES and _ghost_positions.size() > 1000:
		compact_dead_ghosts()
		_frames_since_compaction = 0

## Clear the ghost wave
func clear_ghost_wave() -> void:
	_is_active = false
	_ghost_positions.clear()
	_ghost_velocities.clear()
	_ghost_healths.clear()

	if _multimesh_manager:
		_multimesh_manager.clear_ghost_swarm()

	Logger.debug("Ghost wave cleared", "ghost")

## Compact dead ghosts - removes dead entries from arrays to prevent memory bloat
## Call this periodically when using additive spawning with high death counts
func compact_dead_ghosts() -> void:
	if _ghost_positions.size() == 0:
		return

	var living_count = 0
	var total_count = _ghost_positions.size()

	# Count living ghosts first
	for i in range(total_count):
		if _ghost_healths[i] > 0:
			living_count += 1

	# If no dead ghosts, skip compaction
	if living_count == total_count:
		return

	# Create new arrays with only living ghosts
	var new_positions: PackedVector2Array = PackedVector2Array()
	var new_velocities: PackedVector2Array = PackedVector2Array()
	var new_healths: PackedFloat32Array = PackedFloat32Array()

	new_positions.resize(living_count)
	new_velocities.resize(living_count)
	new_healths.resize(living_count)

	var write_index = 0
	for read_index in range(total_count):
		if _ghost_healths[read_index] > 0:
			new_positions[write_index] = _ghost_positions[read_index]
			new_velocities[write_index] = _ghost_velocities[read_index]
			new_healths[write_index] = _ghost_healths[read_index]
			write_index += 1

	# Replace old arrays with compacted ones
	_ghost_positions = new_positions
	_ghost_velocities = new_velocities
	_ghost_healths = new_healths

	# Update rendering
	if _multimesh_manager:
		_multimesh_manager.update_ghost_swarm(_ghost_positions)

	var dead_count = total_count - living_count
	Logger.info("Ghost compaction: removed %d dead ghosts (%d alive, %d freed)" % [dead_count, living_count, dead_count], "ghost")

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

## Get closest ghost position to a given point (for homing projectiles)
func get_closest_ghost_position(from_pos: Vector2) -> Vector2:
	if not _is_active or _ghost_positions.size() == 0:
		return Vector2.ZERO

	var closest_pos = Vector2.ZERO
	var closest_dist_sq = INF

	for i in range(_ghost_positions.size()):
		# Skip dead ghosts
		if _ghost_healths[i] <= 0:
			continue

		var dist_sq = from_pos.distance_squared_to(_ghost_positions[i])
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_pos = _ghost_positions[i]

	return closest_pos

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
