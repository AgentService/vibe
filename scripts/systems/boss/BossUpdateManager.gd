extends Node

## Boss Update Manager - Centralized boss processing for performance optimization
## Replaces individual boss signal connections with single batched update system
## Uses ring buffer + object pool with zero-allocation patterns for handling 500+ bosses

const RingBuffer = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")
const PayloadReset = preload("res://scripts/utils/PayloadReset.gd")

# Array-backed registry for zero-alloc iteration and O(1) removal (swap-remove)
var _boss_ids: PackedStringArray = PackedStringArray()
var _boss_nodes: Array[CharacterBody2D] = []
var _boss_index: Dictionary = {} # id -> index

# STAGGERED AI UPDATES: Spread boss processing across frames to reduce per-frame load
# At 400 bosses with batch_size=50: 50 bosses/frame × 30Hz = 1500 updates/sec (down from 12K)
# This also staggers move_and_slide() calls, spreading physics queries across 8 frames
var _boss_update_offset: int = 0  # Current batch offset in boss array
const BOSS_UPDATE_BATCH_SIZE: int = 20  # Bosses processed per frame (tune based on performance)

# Track accumulated time for each boss since their last update
var _boss_time_accumulators: PackedFloat32Array = PackedFloat32Array()

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
	
	Logger.info("BossUpdateManager ready - ring buffer capacity: %d, pool size: %d" % [_boss_update_queue.capacity(), _batched_payload_pool.available_count()], "performance")

## Register boss with centralized manager
## @param boss: CharacterBody2D boss node
## @param boss_id: String unique identifier (from existing boss pattern)
func register_boss(boss: CharacterBody2D, boss_id: String) -> void:
	if _boss_index.has(boss_id):
		Logger.warn("Boss already registered: %s" % boss_id, "performance")
		return

	var idx: int = _boss_ids.size()
	_boss_index[boss_id] = idx
	_boss_ids.push_back(boss_id)
	_boss_nodes.push_back(boss)
	_boss_time_accumulators.push_back(0.0)  # Initialize accumulator for this boss

	Logger.info("Boss registered: %s (index: %d, total: %d)" % [boss_id, idx, _boss_ids.size()], "performance")

## Unregister boss using O(1) swap-remove
## @param boss_id: String unique identifier
func unregister_boss(boss_id: String) -> void:
	if not _boss_index.has(boss_id):
		Logger.warn("Boss not found for unregistration: %s" % boss_id, "performance")
		return

	var idx: int = _boss_index[boss_id]
	var last_idx: int = _boss_ids.size() - 1

	if idx != last_idx:
		# Swap with last element to maintain contiguous array
		var last_id: String = _boss_ids[last_idx]
		_boss_ids[idx] = last_id
		_boss_nodes[idx] = _boss_nodes[last_idx]
		_boss_time_accumulators[idx] = _boss_time_accumulators[last_idx]  # Swap accumulator too
		_boss_index[last_id] = idx

	# Remove last element
	_boss_ids.resize(last_idx)
	_boss_nodes.resize(last_idx)
	_boss_time_accumulators.resize(last_idx)  # Remove accumulator
	_boss_index.erase(boss_id)

	Logger.info("Boss unregistered: %s (remaining: %d)" % [boss_id, _boss_ids.size()], "performance")

## Central combat step handler - replaces individual boss connections
## STAGGERED UPDATES: Only processes BOSS_UPDATE_BATCH_SIZE bosses per frame
func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	var count: int = _boss_ids.size()

	if count == 0:
		return  # No bosses to process

	# PERFORMANCE: Get player position ONCE for entire batch (shared across all 20 bosses)
	if not PlayerState.has_player_reference():
		return  # No player, skip AI updates
	var player_pos: Vector2 = PlayerState.position  # Single lookup instead of 20

	# Accumulate time for ALL bosses every frame (even those not in current batch)
	for i in range(count):
		_boss_time_accumulators[i] += dt

	# Clear reusable buffers without reallocations
	_ids_buf.resize(0)
	_pos_buf.resize(0)
	_ai_flags_buf.resize(0)

	# STAGGERED AI: Calculate batch range for this frame
	# Example: 400 bosses / 50 batch = 8 frames to update all
	# Each boss updates every ~266ms (8 frames × 33ms) instead of every 33ms
	var batch_start: int = _boss_update_offset
	var batch_end: int = min(_boss_update_offset + BOSS_UPDATE_BATCH_SIZE, count)

	# PERFORMANCE: Only process bosses in current batch window
	# This also staggers move_and_slide() calls, spreading physics queries across frames
	for i in range(batch_start, batch_end):
		var boss := _boss_nodes[i]
		if not is_instance_valid(boss):
			# Mark for cleanup but don't modify arrays during iteration
			continue

		# Collect boss data for batch processing
		_ids_buf.push_back(_boss_ids[i])
		_pos_buf.push_back(boss.global_position)
		_ai_flags_buf.push_back(1) # true - boss is active

		# Pass accumulated time since last update (typically 1.65s for batch size 20)
		var accumulated_dt: float = _boss_time_accumulators[i]

		# MINIMAL AI: Call ultra-simple AI with shared player position
		# This triggers move_and_slide() inside the boss, spreading physics across frames
		if boss.has_method("_update_ai_minimal"):
			boss._update_ai_minimal(accumulated_dt, player_pos)  # Pass player_pos to avoid per-boss lookup
		elif boss.has_method("_update_ai_batch"):
			boss._update_ai_batch(accumulated_dt)  # Fallback to old AI
		else:
			Logger.warn("Boss %s missing AI methods - using fallback" % _boss_ids[i], "performance")
			if boss.has_method("_update_ai"):
				boss._update_ai(accumulated_dt)

		# Reset accumulator after update
		_boss_time_accumulators[i] = 0.0

	# STAGGERED AI: Advance batch offset for next frame
	_boss_update_offset += BOSS_UPDATE_BATCH_SIZE
	if _boss_update_offset >= count:
		_boss_update_offset = 0  # Wrap around to start
	
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

## Get debug info about manager state
func get_debug_info() -> Dictionary:
	return {
		"registered_bosses": _boss_ids.size(),
		"queue_count": _boss_update_queue.count(),
		"queue_capacity": _boss_update_queue.capacity(),
		"pool_available": _batched_payload_pool.available_count(),
		"boss_ids": _boss_ids
	}

# Note: Boss batch payload factory and reset functions are now handled by PayloadReset utility class
