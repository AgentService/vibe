## MultiMeshProjectileManager.gd
## High-performance projectile system using MultiMesh GPU batching.
##
## Performance Target:
## - 200-500+ simultaneous projectiles at 60 FPS
## - <2ms total overhead (similar to ghost swarms)
## - GPU batching via MultiMeshManager
##
## Architecture:
## - PackedVector2Array for positions/velocities (zero allocation)
## - Distance-based collision (like ghost swarms)
## - Fixed-step physics at 30Hz (via EventBus.combat_step)
## - Listens to EventBus.ability_projectile_requested signal
##
## Use Cases:
## - Volley abilities (50-100 arrows)
## - Barrage/missile storms (200+ projectiles)
## - Particle-like projectile effects
##
## NOT For:
## - Homing projectiles (use scene-based AbilityProjectile)
## - Complex chaining/pierce logic (use scene-based)
## - Projectiles needing unique visuals per instance
##
## Integration:
## 1. ProjectileAbility sets use_multimesh=true
## 2. Emits EventBus.ability_projectile_requested with projectile_data
## 3. This manager spawns via MultiMeshManager.update_projectiles()
## 4. Collision detection via distance checks (like ghosts)
##
## Pattern Match: GhostSwarmSpawner (proven 1000+ entity performance)
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

## Maximum projectile capacity (set high to avoid limits)
const MAX_PROJECTILES := 2000

## Collision radius for projectile hits (pixels)
## NOTE: Increased from 16.0 to 32.0 for testing - projectiles move 20px/frame at 600px/s @ 30Hz
const COLLISION_RADIUS := 32.0

# ============================================================================
# PROPERTIES
# ============================================================================

## Active projectile positions
var _projectile_positions: PackedVector2Array = []

## Active projectile velocities
var _projectile_velocities: PackedVector2Array = []

## Active projectile lifetimes (seconds remaining)
var _projectile_lifetimes: PackedFloat32Array = []

## Active projectile damages
var _projectile_damages: PackedFloat32Array = []

## Active projectile damage types (indices into _damage_type_lookup)
var _projectile_damage_types: PackedByteArray = []

## Active projectile elements (indices into _element_lookup)
var _projectile_elements: PackedByteArray = []

## Active projectile ability IDs (indices into _ability_id_lookup)
var _projectile_ability_ids: PackedInt32Array = []

## Active projectile pierce counts (remaining pierce hits)
var _projectile_pierce_counts: PackedByteArray = []

## Last hit entity IDs for pierce tracking (prevents re-hitting same enemy)
## Tracks which enemy was hit last to prevent consuming pierce on same target
## This works correctly even when enemies are stacked at same position
var _projectile_last_hit_entity_ids: PackedStringArray = []

## Homing system - group-based targeting with staggered updates
var _projectile_target_ids: PackedStringArray = []       # Current target entity ID
var _projectile_group_ids: PackedByteArray = []          # Group assignment (0-9)
var _projectile_homing_counters: PackedByteArray = []    # Stagger counter per projectile
var _group_target_ids: Array[String] = []                # Shared targets per group

## Homing modes
enum HomingMode {
	NONE,               # No homing
	TRACK_TO_DEATH,     # Lock onto target, track until it dies (no retarget)
	HIT_EACH_ONCE       # Hit each target once, immediately retarget (bouncing)
}

## Homing configuration (set per ability)
var _homing_enabled: bool = false
var _homing_mode: int = HomingMode.TRACK_TO_DEATH
var _homing_strength: float = 2.0
var _homing_group_count: int = 10
var _homing_update_interval: int = 4  # Frames between homing updates

## Debug flags (set to false to disable performance optimizations)
var _use_staggered_updates: bool = false  # If false, update homing every frame
var _use_grouped_targeting: bool = false  # If false, each projectile gets unique target

## Lookup tables for string data (avoid storing strings in arrays)
var _damage_type_lookup: Array[String] = ["physical", "fire", "cold", "lightning", "chaos"]
var _element_lookup: Array[String] = ["", "fire", "cold", "lightning", "chaos"]
var _ability_id_lookup: Array[String] = []

## Reference to MultiMeshManager (injected by Arena)
var _multimesh_manager = null

## Is the system active and processing?
var _is_active: bool = false

## Current projectile count
var _active_count: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Pre-allocate arrays to max capacity
	_projectile_positions.resize(MAX_PROJECTILES)
	_projectile_velocities.resize(MAX_PROJECTILES)
	_projectile_lifetimes.resize(MAX_PROJECTILES)
	_projectile_damages.resize(MAX_PROJECTILES)
	_projectile_damage_types.resize(MAX_PROJECTILES)
	_projectile_elements.resize(MAX_PROJECTILES)
	_projectile_ability_ids.resize(MAX_PROJECTILES)
	_projectile_pierce_counts.resize(MAX_PROJECTILES)
	_projectile_last_hit_entity_ids.resize(MAX_PROJECTILES)

	# Pre-allocate homing arrays
	_projectile_target_ids.resize(MAX_PROJECTILES)
	_projectile_group_ids.resize(MAX_PROJECTILES)
	_projectile_homing_counters.resize(MAX_PROJECTILES)

	# Initialize group target array (10 groups by default)
	_group_target_ids.resize(10)
	for i in range(10):
		_group_target_ids[i] = ""

	# Connect to fixed-step physics
	EventBus.combat_step.connect(_on_combat_step)

	# Connect to projectile spawn requests
	EventBus.ability_projectile_requested.connect(_on_ability_projectile_requested)

	Logger.info("MultiMeshProjectileManager initialized (max: %d projectiles)" % MAX_PROJECTILES, "projectiles")


## Setup MultiMeshManager reference (called by Arena after MultiMeshManager initialization)
func setup(multimesh_manager) -> void:
	_multimesh_manager = multimesh_manager
	_is_active = true
	Logger.debug("MultiMeshProjectileManager: MultiMeshManager reference set", "projectiles")


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handles ability projectile spawn requests (filters for use_multimesh=true)
func _on_ability_projectile_requested(projectile_data: Dictionary) -> void:
	# Only handle MultiMesh projectiles
	if not projectile_data.get("use_multimesh", false):
		return

	# Extract homing configuration (once per ability activation)
	if projectile_data.has("is_homing"):
		_homing_enabled = projectile_data.get("is_homing", false)
		_homing_mode = projectile_data.get("homing_mode", HomingMode.TRACK_TO_DEATH)
		_homing_strength = projectile_data.get("homing_strength", 2.0)
		_homing_group_count = projectile_data.get("homing_group_count", 10)
		_homing_update_interval = projectile_data.get("homing_update_interval", 4)

	# Spawn projectile
	spawn_projectile(projectile_data)


## Fixed-step physics update (30Hz)
func _on_combat_step(payload) -> void:
	if not _is_active or _active_count == 0:
		return

	var dt: float = payload.dt

	# Update all projectiles (write index for compacting alive projectiles)
	var write_index := 0

	for read_index in range(_active_count):
		# Update lifetime
		_projectile_lifetimes[read_index] -= dt

		# Skip expired projectiles (don't write to compacted array)
		if _projectile_lifetimes[read_index] <= 0.0:
			continue

		# Homing logic (staggered updates for performance)
		if _homing_enabled:
			var target_id = _projectile_target_ids[read_index]

			# TRACK_TO_DEATH mode: Despawn when target dies (no retargeting)
			if _homing_mode == HomingMode.TRACK_TO_DEATH:
				if target_id != "" and not DamageService.is_entity_alive(target_id):
					continue  # Despawn projectile when target dies

			# HIT_EACH_ONCE mode: Retarget if current target is dead
			elif _homing_mode == HomingMode.HIT_EACH_ONCE:
				if target_id == "" or not DamageService.is_entity_alive(target_id):
					# Find new target immediately
					var new_target = _find_closest_enemy(_projectile_positions[read_index])
					_projectile_target_ids[read_index] = new_target

			# Determine if we should update homing this frame
			var should_update_homing: bool = false

			if _use_staggered_updates:
				# Staggered updates (every N frames for performance)
				_projectile_homing_counters[read_index] += 1
				if _projectile_homing_counters[read_index] >= _homing_update_interval:
					_projectile_homing_counters[read_index] = 0
					should_update_homing = true
			else:
				# Update every frame (debug mode)
				should_update_homing = true

			if should_update_homing:
				# Re-read current target from array (might have been updated by retargeting logic above)
				var current_target_id = _projectile_target_ids[read_index]

				# Update velocity toward target
				if current_target_id != "":
					var target_data = EntityTracker.get_entity(current_target_id)
					var target_pos = target_data.get("pos", Vector2.ZERO)
					if target_pos != Vector2.ZERO:
						var desired_direction = (target_pos - _projectile_positions[read_index]).normalized()
						var current_speed = _projectile_velocities[read_index].length()

						# Lerp toward desired direction (not velocity to avoid magnitude loss)
						# Adjust strength multiplier based on update mode
						# NOTE: Uses 5.0x multiplier to match scene-based homing responsiveness
						var strength_multiplier: float = _homing_strength * dt * 5.0
						if _use_staggered_updates:
							strength_multiplier *= _homing_update_interval  # Compensate for staggered updates

						var current_direction = _projectile_velocities[read_index].normalized()

						# Lerp between normalized directions, then scale to maintain speed
						var new_direction = lerp(current_direction, desired_direction, strength_multiplier).normalized()
						_projectile_velocities[read_index] = new_direction * current_speed

		# Update position
		_projectile_positions[read_index] += _projectile_velocities[read_index] * dt

		# Check collision with enemies
		var hit := _check_collision(_projectile_positions[read_index], read_index)
		if hit:
			# Projectile hit enemy, don't write to compacted array (despawn)
			continue

		# Projectile still alive, write to compacted array
		if write_index != read_index:
			_projectile_positions[write_index] = _projectile_positions[read_index]
			_projectile_velocities[write_index] = _projectile_velocities[read_index]
			_projectile_lifetimes[write_index] = _projectile_lifetimes[read_index]
			_projectile_damages[write_index] = _projectile_damages[read_index]
			_projectile_damage_types[write_index] = _projectile_damage_types[read_index]
			_projectile_elements[write_index] = _projectile_elements[read_index]
			_projectile_ability_ids[write_index] = _projectile_ability_ids[read_index]
			_projectile_pierce_counts[write_index] = _projectile_pierce_counts[read_index]
			_projectile_last_hit_entity_ids[write_index] = _projectile_last_hit_entity_ids[read_index]

			# Copy homing data
			_projectile_target_ids[write_index] = _projectile_target_ids[read_index]
			_projectile_group_ids[write_index] = _projectile_group_ids[read_index]
			_projectile_homing_counters[write_index] = _projectile_homing_counters[read_index]

		write_index += 1

	# Update active count after compacting
	_active_count = write_index

	# Update MultiMesh rendering (only render active projectiles)
	if _multimesh_manager:
		# Create PackedVector2Array slices with only active projectiles
		var active_positions := PackedVector2Array()
		var active_velocities := PackedVector2Array()
		active_positions.resize(_active_count)
		active_velocities.resize(_active_count)
		for i in range(_active_count):
			active_positions[i] = _projectile_positions[i]
			active_velocities[i] = _projectile_velocities[i]

		_multimesh_manager.update_projectiles(active_positions, active_velocities)


# ============================================================================
# SPAWNING
# ============================================================================

## Spawns a MultiMesh projectile from ability data
func spawn_projectile(projectile_data: Dictionary) -> void:
	if _active_count >= MAX_PROJECTILES:
		# Silently skip spawning beyond capacity (no spam warnings)
		return

	# Extract spawn data with explicit types (avoid Variant inference)
	var position: Vector2 = projectile_data.get("source_position", Vector2.ZERO)
	var direction: Vector2 = projectile_data.get("direction", Vector2.RIGHT)
	direction = direction.normalized()
	var speed: float = projectile_data.get("projectile_speed", 800.0)
	var damage: float = projectile_data.get("damage", 15.0)
	var lifetime: float = projectile_data.get("projectile_lifetime", 2.0)
	var damage_type: String = projectile_data.get("damage_type", "physical")
	var element: String = projectile_data.get("element", "")
	var ability_id: String = projectile_data.get("ability_id", "")
	var pierce_count: int = projectile_data.get("pierce_count", 0)

	# Get or add string lookup indices
	var damage_type_index := _get_or_add_damage_type_index(damage_type)
	var element_index := _get_or_add_element_index(element)
	var ability_id_index := _get_or_add_ability_id_index(ability_id)

	# Add to active projectiles
	_projectile_positions[_active_count] = position
	_projectile_velocities[_active_count] = direction * speed
	_projectile_lifetimes[_active_count] = lifetime
	_projectile_damages[_active_count] = damage
	_projectile_damage_types[_active_count] = damage_type_index
	_projectile_elements[_active_count] = element_index
	_projectile_ability_ids[_active_count] = ability_id_index
	_projectile_pierce_counts[_active_count] = pierce_count
	_projectile_last_hit_entity_ids[_active_count] = ""  # Empty = no previous hit

	# Initialize homing data (if homing enabled)
	if _homing_enabled:
		if _use_grouped_targeting:
			# Grouped targeting: Share targets across projectile groups
			# Example: 20 projectiles, group_count=10 → P0-P9=group0, P10-P19=group1
			var group_id = _active_count / _homing_group_count
			_projectile_group_ids[_active_count] = group_id

			# Ensure group target array is large enough
			while group_id >= _group_target_ids.size():
				_group_target_ids.append("")

			# Find initial target for this group (if not already assigned)
			if _group_target_ids[group_id] == "":
				_group_target_ids[group_id] = _find_closest_enemy(position)

			# Assign group target to projectile
			_projectile_target_ids[_active_count] = _group_target_ids[group_id]
		else:
			# Debug mode: Each projectile gets unique target
			_projectile_target_ids[_active_count] = _find_closest_enemy(position)
			_projectile_group_ids[_active_count] = 0

		# Random stagger offset for smooth updates (only if using staggered updates)
		if _use_staggered_updates:
			_projectile_homing_counters[_active_count] = randi() % _homing_update_interval
		else:
			_projectile_homing_counters[_active_count] = 0
	else:
		_projectile_target_ids[_active_count] = ""
		_projectile_group_ids[_active_count] = 0
		_projectile_homing_counters[_active_count] = 0

	_active_count += 1


# ============================================================================
# COLLISION DETECTION
# ============================================================================

## Checks collision at given position, returns true if should despawn (and applies damage if alive)
func _check_collision(position: Vector2, projectile_index: int) -> bool:
	# Get enemy IDs near projectile - check BOTH "enemy" and "boss" types
	# NOTE: BaseBoss registers as type="boss", regular enemies as type="enemy"
	var nearby_enemies: Array[String] = EntityTracker.get_entities_in_radius(position, COLLISION_RADIUS, "enemy")
	var nearby_bosses: Array[String] = EntityTracker.get_entities_in_radius(position, COLLISION_RADIUS, "boss")

	# Combine both arrays into one
	var nearby_targets: Array[String] = []
	nearby_targets.append_array(nearby_enemies)
	nearby_targets.append_array(nearby_bosses)

	if nearby_targets.is_empty():
		return false  # No collision

	# Hit first target found (enemy or boss)
	var target_id: String = nearby_targets[0]

	# Check if this is the same enemy we hit last frame (prevent re-hitting)
	# This works correctly even when enemies are stacked at same position
	var last_hit_id: String = _projectile_last_hit_entity_ids[projectile_index]
	if last_hit_id == target_id:
		return false  # Same enemy as last hit, continue flying

	# Apply damage only if target is alive (overkill prevention)
	if DamageService.is_entity_alive(target_id):
		var damage: float = _projectile_damages[projectile_index]
		var damage_type: String = _damage_type_lookup[_projectile_damage_types[projectile_index]]
		var element: String = _element_lookup[_projectile_elements[projectile_index]]

		# Build damage tags
		var tags: Array = [damage_type]
		if element:
			tags.append(element)

		# Use player position for knockback direction
		var player_pos: Vector2 = PlayerState.get_position() if PlayerState else position

		# Apply damage immediately (bypass queue for overkill prevention)
		DamageService._process_damage_immediate(
			target_id,
			damage,
			"player",
			tags,
			0.0,  # No knockback for MultiMesh projectiles (performance)
			player_pos
		)

	# Update last hit entity ID after collision (prevents re-hitting same enemy)
	_projectile_last_hit_entity_ids[projectile_index] = target_id

	# Handle homing retargeting based on mode
	if _homing_enabled:
		if _homing_mode == HomingMode.TRACK_TO_DEATH:
			# Only retarget after piercing through target
			pass  # Target stays locked until pierce

		elif _homing_mode == HomingMode.HIT_EACH_ONCE:
			# Immediately retarget after ANY hit (bouncing behavior)
			var new_target = _find_closest_enemy(position)
			_projectile_target_ids[projectile_index] = new_target

	# Check pierce count (hitting any enemy, dead or alive, counts as a collision)
	var pierce_count: int = _projectile_pierce_counts[projectile_index]

	if pierce_count > 0:
		# Decrement pierce and continue flying
		_projectile_pierce_counts[projectile_index] = pierce_count - 1

		# For TRACK_TO_DEATH mode, lock onto new target after piercing
		if _homing_enabled and _homing_mode == HomingMode.TRACK_TO_DEATH:
			var new_target = _find_closest_enemy(position)
			_projectile_target_ids[projectile_index] = new_target

		return false  # Continue flying

	# No pierce remaining, despawn
	return true


# ============================================================================
# UTILITY
# ============================================================================

## Gets or adds damage type to lookup table
func _get_or_add_damage_type_index(damage_type: String) -> int:
	var index := _damage_type_lookup.find(damage_type)
	if index == -1:
		_damage_type_lookup.append(damage_type)
		index = _damage_type_lookup.size() - 1
	return index


## Gets or adds element to lookup table
func _get_or_add_element_index(element: String) -> int:
	var index := _element_lookup.find(element)
	if index == -1:
		_element_lookup.append(element)
		index = _element_lookup.size() - 1
	return index


## Gets or adds ability ID to lookup table
func _get_or_add_ability_id_index(ability_id: String) -> int:
	var index := _ability_id_lookup.find(ability_id)
	if index == -1:
		_ability_id_lookup.append(ability_id)
		index = _ability_id_lookup.size() - 1
	return index


## Clears all active projectiles
func clear_all_projectiles() -> void:
	_active_count = 0
	if _multimesh_manager:
		_multimesh_manager.clear_projectiles()


## Gets current projectile count (for debugging)
func get_active_count() -> int:
	return _active_count


## Gets capacity stats (for debugging)
func get_capacity_stats() -> Dictionary:
	return {
		"active": _active_count,
		"capacity": MAX_PROJECTILES,
		"percent_full": (_active_count / float(MAX_PROJECTILES)) * 100.0
	}


# ============================================================================
# HOMING LOGIC
# ============================================================================

## Finds closest enemy to given position (for initial target assignment)
func _find_closest_enemy(from_pos: Vector2) -> String:
	var enemies: Array[String] = EntityTracker.get_entities_in_radius(from_pos, 1000.0, "enemy")
	var bosses: Array[String] = EntityTracker.get_entities_in_radius(from_pos, 1000.0, "boss")

	# Combine enemy and boss arrays
	var all_targets: Array[String] = []
	all_targets.append_array(enemies)
	all_targets.append_array(bosses)

	if all_targets.is_empty():
		return ""

	# Find closest target
	var closest_id: String = ""
	var closest_dist_sq: float = INF

	for target_id in all_targets:
		var target_data = EntityTracker.get_entity(target_id)
		var target_pos = target_data.get("pos", Vector2.ZERO)
		if target_pos == Vector2.ZERO:
			continue

		var dist_sq = from_pos.distance_squared_to(target_pos)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_id = target_id

	return closest_id
