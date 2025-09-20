extends RefCounted
class_name EventInstance

## Simple event state tracking for breach events
## Manages the lifecycle: waiting → expanding → shrinking → completed
## Used by SpawnDirector to coordinate timed breach mechanics

var event_type: StringName = "breach"
var zone: Area2D
var center_position: Vector2
var phase_timer: float = 0.0

# Configuration loaded from resource
var config: BreachEventConfig
var expand_duration: float = 10.0  # Will be set from config
var shrink_duration: float = 10.0  # Will be set from config
var initial_radius: float = 30.0   # Will be set from config
var max_radius: float = 150.0      # Will be set from config
var current_radius: float = 50.0

enum Phase { WAITING, EXPANDING, SHRINKING, COMPLETED }
var phase: Phase = Phase.WAITING

# Legacy spawning vars (no longer used with phantom position system)
var spawn_timer: float = 0.0  # Kept for compatibility
var spawned_enemies: Array[String] = []  # Track spawned enemy IDs

# DYNAMIC RING SPAWNING SYSTEM: Spawn enemy rings as circle expands
var last_ring_spawn_radius: float = 0.0  # Last radius when we spawned a ring
var ring_spawn_threshold: float = 50.0  # Spawn new ring every 50px expansion
var revealed_enemies: Dictionary = {}  # position_key -> enemy_node mapping
var breach_id: String = ""  # Unique ID for this breach instance

# SECTOR TRACKING: Divide circle into sectors for even distribution
var sector_enemy_counts: Dictionary = {}  # sector_id -> enemy_count
var total_sectors: int = 16  # Divide circle into 16 sectors

# Event strategy system integration (legacy)
var strategy_id: String = ""  # ID for linked spawn strategy

func _init(zone_area: Area2D, breach_config: BreachEventConfig = null):
	zone = zone_area

	# Generate unique breach ID for ownership tracking
	breach_id = "breach_" + str(Time.get_time_dict_from_system().hour) + "_" + str(Time.get_time_dict_from_system().minute) + "_" + str(Time.get_time_dict_from_system().second) + "_" + str(randi())

	# Load configuration
	if breach_config:
		config = breach_config
	else:
		config = load("res://data/balance/breach_event_config.tres") as BreachEventConfig

	# Apply config parameters
	if config and config.validate():
		expand_duration = config.expand_duration
		shrink_duration = config.shrink_duration
		initial_radius = config.initial_radius
		max_radius = config.max_radius
		# spawn_interval removed - phantom position system doesn't use time-based spawning
	else:
		Logger.warn("Invalid breach config, using defaults", "events")

	center_position = _get_random_position_in_zone(zone_area)
	current_radius = initial_radius

func _get_random_position_in_zone(zone_area: Area2D) -> Vector2:
	"""Get a random position within the spawn zone area"""
	# Check if zone has a collision shape to determine its bounds
	var shape_owners = zone_area.get_shape_owners()
	if shape_owners.size() > 0:
		var owner_id = shape_owners[0]
		var shape = zone_area.shape_owner_get_shape(owner_id, 0)

		if shape is RectangleShape2D:
			var rect_shape = shape as RectangleShape2D
			var half_size = rect_shape.size / 2
			var random_offset = Vector2(
				randf_range(-half_size.x, half_size.x),
				randf_range(-half_size.y, half_size.y)
			)
			return zone_area.global_position + random_offset
		elif shape is CircleShape2D:
			var circle_shape = shape as CircleShape2D
			var angle = randf() * TAU
			var distance = randf() * circle_shape.radius
			var random_offset = Vector2(cos(angle), sin(angle)) * distance
			return zone_area.global_position + random_offset

	# Fallback to zone center if no recognizable shape
	return zone_area.global_position

	# Get zone radius for max expansion (use zone's collision shape if available)
	if zone.get_child_count() > 0:
		var collision_shape = zone.get_child(0) as CollisionShape2D
		if collision_shape and collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			max_radius = circle_shape.radius * 1.2  # Slightly larger than zone

func is_player_in_touch_range(player_pos: Vector2) -> bool:
	"""Check if player is close enough to activate breach"""
	if phase != Phase.WAITING:
		return false
	return player_pos.distance_to(center_position) <= initial_radius

func activate() -> void:
	"""Start breach expansion"""
	if phase == Phase.WAITING:
		phase = Phase.EXPANDING
		phase_timer = 0.0
		Logger.info("Breach activated at %s" % center_position, "events")

func update_lifecycle(dt: float) -> void:
	"""Update breach phase progression"""
	phase_timer += dt
	spawn_timer += dt

	match phase:
		Phase.EXPANDING:
			_update_expansion(dt)
		Phase.SHRINKING:
			_update_shrinking(dt)

func _update_expansion(dt: float) -> void:
	"""Handle expansion phase logic"""
	var progress = phase_timer / expand_duration
	current_radius = lerp(initial_radius, max_radius, progress)

	if phase_timer >= expand_duration:
		phase = Phase.SHRINKING
		phase_timer = 0.0
		Logger.info("Breach expansion complete, starting to close", "events")

func _update_shrinking(dt: float) -> void:
	"""Handle shrinking phase logic"""
	var progress = phase_timer / shrink_duration
	current_radius = lerp(max_radius, initial_radius, progress)

	if phase_timer >= shrink_duration:
		phase = Phase.COMPLETED
		Logger.info("Breach completed", "events")

func is_enemy_inside_circle(enemy_pos: Vector2) -> bool:
	"""Check if enemy position is inside current circle"""
	return enemy_pos.distance_to(center_position) <= current_radius

func should_spawn_enemies() -> bool:
	"""Legacy function - now using ring spawning system"""
	return should_spawn_new_ring()

func should_spawn_new_ring() -> bool:
	"""Check if we should spawn a new enemy ring at current radius"""
	return phase == Phase.EXPANDING and (current_radius - last_ring_spawn_radius >= ring_spawn_threshold)

func reset_spawn_timer() -> void:
	"""Reset spawn timer after spawning enemies"""
	spawn_timer = 0.0

func add_spawned_enemy(entity_id: String) -> void:
	"""Track an enemy spawned by this event"""
	spawned_enemies.append(entity_id)

func get_total_duration() -> float:
	"""Get total event duration (expand + shrink)"""
	return expand_duration + shrink_duration

func get_progress() -> float:
	"""Get overall event progress (0.0 to 1.0)"""
	var total_duration = get_total_duration()
	var elapsed_time = phase_timer

	match phase:
		Phase.WAITING:
			return 0.0
		Phase.EXPANDING:
			return elapsed_time / total_duration
		Phase.SHRINKING:
			return (expand_duration + elapsed_time) / total_duration
		Phase.COMPLETED:
			return 1.0
		_:
			return 0.0

# SECTOR MANAGEMENT FUNCTIONS: For even enemy distribution
func get_enemy_sector(enemy_pos: Vector2) -> int:
	"""Calculate which sector an enemy position belongs to"""
	var to_enemy = enemy_pos - center_position
	var angle = to_enemy.angle()
	if angle < 0:
		angle += TAU
	return int(angle / (TAU / total_sectors))

func increment_sector_count(sector_id: int) -> void:
	"""Add one enemy to a sector's count"""
	if sector_id >= 0 and sector_id < total_sectors:
		sector_enemy_counts[sector_id] = sector_enemy_counts.get(sector_id, 0) + 1

func get_emptiest_sectors(count: int) -> Array[int]:
	"""Get the N emptiest sectors for spawn prioritization"""
	var sector_data: Array[Dictionary] = []
	for i in range(total_sectors):
		var enemy_count = sector_enemy_counts.get(i, 0)
		sector_data.append({"id": i, "count": enemy_count})

	# Sort by enemy count (ascending)
	sector_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count < b.count)

	var result: Array[int] = []
	for i in range(min(count, sector_data.size())):
		var sector_id: int = sector_data[i]["id"]
		result.append(sector_id)
	return result

func mark_ring_spawned() -> void:
	"""Mark that we've spawned a ring at current radius"""
	last_ring_spawn_radius = current_radius
