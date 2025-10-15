extends Node

## Boss Update Manager - Centralized boss processing for performance optimization
## Replaces individual boss signal connections with single batched update system
## Uses ring buffer + object pool with zero-allocation patterns for handling 500+ bosses

const RingBuffer = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")
const PayloadReset = preload("res://scripts/utils/PayloadReset.gd")

# Array-backed registry for zero-alloc iteration and O(1) removal (swap-remove)
var _boss_ids: PackedStringArray = PackedStringArray()
var _boss_nodes: Array[Node2D] = []  # Node2D for physics-free movement (HitBox child handles collision)
var _boss_index: Dictionary = {} # id -> index

# Staggered AI update system - spread AI across multiple frames
var _frame_counter: int = 0
const AI_UPDATE_GROUPS: int = 20  # Divide enemies into 20 groups (1000 enemies = 50 per frame)

# Throttled position updates - balance accuracy vs performance
var _physics_update_counter: int = 0
const ENTITY_TRACKER_UPDATE_INTERVAL: int = 2  # Update every 2 physics frames (66ms @ 30Hz)

# CENTRALIZED ENEMY COUNT CACHE: Query tree ONCE per second (not per enemy per frame)
var _cached_enemy_count: int = 0
var _enemy_count_update_counter: int = 0
const ENEMY_COUNT_UPDATE_INTERVAL: int = 30  # Update every 30 frames (1 second @ 30Hz)

# Viewport culling - skip AI updates for off-screen bosses
var _viewport: Viewport = null
var _player_camera: Camera2D = null
const ENABLE_VIEWPORT_CULLING: bool = false  # Disabled: conflicts with large chase_range (5555px)

# Reusable batched payload buffers (cleared each step, not reallocated)
var _ids_buf: PackedStringArray = PackedStringArray()
var _pos_buf: PackedVector2Array = PackedVector2Array()
var _ai_flags_buf: PackedByteArray = PackedByteArray() # 1 = true, 0 = false


# Ring buffer with latest-only policy for backpressure
var _boss_update_queue: RingBuffer
var _batched_payload_pool: ObjectPool

func _ready() -> void:
	Logger.info("BossUpdateManager initializing", "performance")

	# Connect to combat step - single connection replaces 500+ individual connections
	EventBus.combat_step.connect(_on_combat_step)

	# Initialize ring buffer with 64 slots (one payload per frame is sufficient)
	_boss_update_queue = RingBuffer.new()
	_boss_update_queue.setup(64)

	# Initialize object pool for batched payloads using PayloadReset utilities
	_batched_payload_pool = ObjectPool.new()
	_batched_payload_pool.setup(8, PayloadReset.create_boss_batch_payload, PayloadReset.clear_boss_batch_payload)

	# Get viewport for culling calculations
	_viewport = get_viewport()

	Logger.info("BossUpdateManager ready - ring buffer capacity: %d, pool size: %d, viewport culling: %s" % [
		_boss_update_queue.capacity(),
		_batched_payload_pool.available_count(),
		"enabled" if ENABLE_VIEWPORT_CULLING else "disabled"
	], "performance")

## Register boss with centralized manager
## @param boss: Node2D boss node (physics-free movement, HitBox child handles collision)
## @param boss_id: String unique identifier (from existing boss pattern)
func register_boss(boss: Node2D, boss_id: String) -> void:
	if _boss_index.has(boss_id):
		Logger.warn("Boss already registered: %s" % boss_id, "performance")
		return

	var idx: int = _boss_ids.size()
	_boss_index[boss_id] = idx
	_boss_ids.push_back(boss_id)
	_boss_nodes.push_back(boss)

	Logger.info("Boss registered: %s (index: %d, total: %d)" % [boss_id, idx, _boss_ids.size()], "performance")

## Unregister boss using O(1) swap-remove
## @param boss_id: String unique identifier
func unregister_boss(boss_id: String) -> void:
	if not _boss_index.has(boss_id):
		Logger.warn("Boss not found for unregistration: %s (total: %d)" % [boss_id, _boss_ids.size()], "performance")
		return

	var idx: int = _boss_index[boss_id]
	var last_idx: int = _boss_ids.size() - 1

	if idx != last_idx:
		# Swap with last element to maintain contiguous array
		var last_id: String = _boss_ids[last_idx]
		_boss_ids[idx] = last_id
		_boss_nodes[idx] = _boss_nodes[last_idx]
		_boss_index[last_id] = idx

	# Remove last element
	_boss_ids.resize(last_idx)
	_boss_nodes.resize(last_idx)
	_boss_index.erase(boss_id)

	Logger.info("✓ Boss unregistered: %s (remaining: %d)" % [boss_id, _boss_ids.size()], "performance")

## Calculate visible viewport rect for culling
## Returns Rect2 in world coordinates with margin for off-screen buffer
func _get_visible_world_rect() -> Rect2:
	if not _viewport:
		return Rect2()  # No culling if viewport unavailable

	var viewport_size := _viewport.get_visible_rect().size
	var zoom: float = 1.0
	var camera_pos := Vector2.ZERO

	# Try to get cached camera first (fast path)
	if not _player_camera or not is_instance_valid(_player_camera):
		# Find camera via player node (slow, but only once per run)
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera is Camera2D:
				_player_camera = player_camera

	# Use camera if available
	if _player_camera and is_instance_valid(_player_camera):
		zoom = _player_camera.zoom.x
		camera_pos = _player_camera.global_position

	var margin: float = BalanceDB.waves.enemy_viewport_cull_margin
	var half_size := (viewport_size / zoom) * 0.5 + Vector2(margin, margin)
	return Rect2(camera_pos - half_size, half_size * 2)

## Central combat step handler - replaces individual boss connections
## STAGGERED AI: Processes 1/20th of bosses per frame using mod(id, 20) distribution
## VIEWPORT CULLING: Skips AI updates for off-screen bosses
func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	var count: int = _boss_ids.size()

	if count == 0:
		return  # No bosses to process

	# PERFORMANCE: Get player position ONCE for all bosses
	if not PlayerState.has_player_reference():
		return  # No player, skip AI updates
	var player_pos: Vector2 = PlayerState.position  # Single lookup for all enemies

	# CENTRALIZED ENEMY COUNT: Update cache once per second (not per enemy per frame!)
	# At 1000 enemies: 30,000 queries/sec → 1 query/sec = 99.997% reduction
	_enemy_count_update_counter += 1
	if _enemy_count_update_counter >= ENEMY_COUNT_UPDATE_INTERVAL:
		_enemy_count_update_counter = 0
		_cached_enemy_count = get_tree().get_nodes_in_group("enemies").size()

	# VIEWPORT CULLING: Calculate visible rect ONCE per frame
	var visible_rect: Rect2
	if ENABLE_VIEWPORT_CULLING:
		visible_rect = _get_visible_world_rect()

	# Calculate which AI group updates THIS frame (0-19)
	var current_group: int = _frame_counter % AI_UPDATE_GROUPS
	_frame_counter += 1

	# Clear reusable buffers without reallocations
	_ids_buf.resize(0)
	_pos_buf.resize(0)
	_ai_flags_buf.resize(0)

	# STAGGERED AI + VIEWPORT CULLING: Process subset of bosses
	# Example: 1000 bosses = 50 per frame staggered, ~12% visible = ~6 AI updates/frame
	# Frame 0: bosses 0,20,40,60... | Frame 1: bosses 1,21,41,61... | etc.
	var culled_count: int = 0
	for i in range(count):
		# Skip bosses not in this frame's group
		if i % AI_UPDATE_GROUPS != current_group:
			continue

		var boss := _boss_nodes[i]
		if not is_instance_valid(boss):
			# Mark for cleanup but don't modify arrays during iteration
			continue

		# VIEWPORT CULLING: Skip off-screen bosses
		if ENABLE_VIEWPORT_CULLING and visible_rect.size.x > 0:
			if not visible_rect.has_point(boss.global_position):
				culled_count += 1
				continue  # Boss is off-screen, skip AI update

		# Collect boss data for batch processing
		_ids_buf.push_back(_boss_ids[i])
		_pos_buf.push_back(boss.global_position)
		_ai_flags_buf.push_back(1) # true - boss is active

		# STAGGERED AI: Scale dt by group count (each boss updates every 20 frames)
		# dt = 0.0333s (30Hz) → scaled_dt = 0.0333 * 20 = 0.666s between updates
		var scaled_dt: float = dt * AI_UPDATE_GROUPS

		# Call AI with scaled delta time + cached enemy count (avoids 30k tree queries/sec)
		if boss.has_method("_update_ai_minimal"):
			boss._update_ai_minimal(scaled_dt, player_pos, _cached_enemy_count)
		elif boss.has_method("_update_ai_batch"):
			boss._update_ai_batch(scaled_dt)
		else:
			Logger.warn("Boss %s missing AI methods - using fallback" % _boss_ids[i], "performance")
			if boss.has_method("_update_ai"):
				boss._update_ai(scaled_dt)
	
	# Create single batched payload per step
	if _ids_buf.size() > 0:
		var p = _batched_payload_pool.acquire()
		p["ids"] = _ids_buf.duplicate()  # Deep copy for async processing
		p["positions"] = _pos_buf.duplicate()
		p["ai_flags"] = _ai_flags_buf.duplicate()
		
		# Push to ring buffer with backpressure policy (drop oldest if full)
		if not _boss_update_queue.try_push(p):
			# Ring buffer full - drop oldest and try again
			var dropped = _boss_update_queue.try_pop()
			if dropped:
				_batched_payload_pool.release(dropped)
			_boss_update_queue.try_push(p)
			Logger.debug("Ring buffer overflow - dropped oldest payload", "performance")
		
		# Process position updates immediately for consistency
		_process_position_updates()

	# Optional debug logging for viewport culling performance
	if ENABLE_VIEWPORT_CULLING and culled_count > 0:
		Logger.debug("Viewport culling: %d/%d bosses off-screen (%.1f%% reduction)" % [
			culled_count,
			count / AI_UPDATE_GROUPS,
			(culled_count * 100.0) / (count / AI_UPDATE_GROUPS)
		], "performance")

## Process batched position updates for EntityTracker
func _process_position_updates() -> void:
	# Use latest payload only for position updates (coalesce if multiple)
	var latest = _boss_update_queue.try_pop()
	if not latest:
		return

	# BOSS PERFORMANCE V2: Use EntityTracker batch API for zero-allocation position updates
	var ids: PackedStringArray = latest["ids"]
	var positions: PackedVector2Array = latest["positions"]

	EntityTracker.batch_update_positions(ids, positions)

	# Return payload to pool
	_batched_payload_pool.release(latest)

## THROTTLED POST-MOVEMENT POSITION UPDATES: Capture positions AFTER physics applies movement
## Updates every 2 physics frames (66ms) to balance accuracy vs performance
## This reduces EntityTracker staleness from 0.66s to 0.066s while cutting performance cost in half
func _physics_process(_delta: float) -> void:
	_physics_update_counter += 1
	if _physics_update_counter < ENTITY_TRACKER_UPDATE_INTERVAL:
		return  # Skip this frame

	_physics_update_counter = 0  # Reset counter

	var count: int = _boss_ids.size()
	if count == 0:
		return  # No bosses to update

	# Clear position buffer (reuse allocations)
	_pos_buf.resize(0)
	_ids_buf.resize(0)

	# Collect all boss positions AFTER movement has been applied
	for i in range(count):
		var boss := _boss_nodes[i]
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			_ids_buf.push_back(_boss_ids[i])
			_pos_buf.push_back(boss.global_position)  # Fresh position AFTER _physics_process

	# Batch update EntityTracker with post-movement positions
	if _ids_buf.size() > 0:
		EntityTracker.batch_update_positions(_ids_buf, _pos_buf)

## Get debug info about manager state
func get_debug_info() -> Dictionary:
	return {
		"registered_bosses": _boss_ids.size(),
		"queue_count": _boss_update_queue.count(),
		"queue_capacity": _boss_update_queue.capacity(),
		"pool_available": _batched_payload_pool.available_count(),
		"boss_ids": _boss_ids
	}

## DEBUG: Print boss count every few seconds
var _debug_timer: float = 0.0
func _process(delta: float) -> void:
	_debug_timer += delta
	if _debug_timer >= 5.0:  # Every 5 seconds
		_debug_timer = 0.0
		Logger.info("BossUpdateManager: %d bosses registered" % _boss_ids.size(), "performance")

# Note: Boss batch payload factory and reset functions are now handled by PayloadReset utility class
