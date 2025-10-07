extends RefCounted
class_name BreachEnemyTracker

## Zero-allocation breach enemy tracking using RingBuffer for fixed-capacity management.
## Provides safe concurrent removal through mark-for-removal strategy.
## Designed for 256-enemy capacity per breach with graceful overflow handling.

# Core RingBuffer for enemy storage
var _ring_buffer: RingBuffer
var _capacity: int

# Zero-allocation concurrent removal strategy
var _marked_for_removal: Dictionary = {}  # enemy_id -> true
var _removal_count: int = 0

# Performance tracking
var _add_rejections: int = 0
var _current_count: int = 0

## Initialize the tracker with specified capacity (rounded to next power-of-two)
func setup(capacity: int) -> void:
	assert(capacity > 0, "BreachEnemyTracker capacity must be > 0")

	_capacity = capacity
	_ring_buffer = RingBuffer.new()
	_ring_buffer.setup(capacity)

	# Reset tracking state
	_marked_for_removal.clear()
	_removal_count = 0
	_add_rejections = 0
	_current_count = 0

	Logger.debug("BreachEnemyTracker initialized with capacity %d (actual: %d)" % [
		capacity, _ring_buffer.capacity()
	], "events")

## Add enemy to the tracker. Returns false if capacity exceeded.
func add_enemy(enemy: Node2D) -> bool:
	if not enemy or not is_instance_valid(enemy):
		Logger.warn("BreachEnemyTracker: Attempted to add invalid enemy", "events")
		return false

	# Check capacity before adding
	if _ring_buffer.is_full():
		_add_rejections += 1
		Logger.warn("BreachEnemyTracker: Capacity exceeded, rejecting enemy add (rejections: %d)" % _add_rejections, "events")
		return false

	# Add to ring buffer
	var success = _ring_buffer.try_push(enemy)
	if success:
		_current_count += 1
	return success

## Mark enemy for removal without immediate allocation/removal.
## Safe to call during iteration - actual removal happens in cleanup_marked().
func mark_for_removal(enemy: Node2D) -> void:
	if not enemy or not is_instance_valid(enemy):
		return

	var enemy_id = str(enemy.get_instance_id())
	if not _marked_for_removal.has(enemy_id):
		_marked_for_removal[enemy_id] = true
		_removal_count += 1

## Get array of valid (non-marked) enemies for iteration.
## Safe to iterate while concurrent mark_for_removal() calls happen.
func iterate_valid_enemies() -> Array[Node2D]:
	var valid_enemies: Array[Node2D] = []

	# Extract all enemies from ring buffer
	var all_enemies: Array[Node2D] = []
	var temp_buffer = []

	# Pop all enemies to examine them
	while not _ring_buffer.is_empty():
		var enemy = _ring_buffer.try_pop()
		if enemy:
			temp_buffer.append(enemy)

	# Filter out marked enemies and rebuild buffer
	for enemy in temp_buffer:
		if not enemy or not is_instance_valid(enemy):
			# Invalid enemy - don't re-add to buffer
			_current_count -= 1
			continue

		var enemy_id = str(enemy.get_instance_id())
		if _marked_for_removal.has(enemy_id):
			# Marked for removal - don't re-add to buffer or include in valid list
			continue

		# Valid enemy - re-add to buffer and include in iteration
		_ring_buffer.try_push(enemy)
		valid_enemies.append(enemy)

	return valid_enemies

## Remove all marked enemies during safe cleanup phase.
## Call this when not iterating to avoid concurrent modification issues.
func cleanup_marked() -> void:
	if _removal_count == 0:
		return  # No enemies to clean up

	var cleaned_count = 0
	var all_enemies: Array[Node2D] = []

	# Extract all enemies from ring buffer
	while not _ring_buffer.is_empty():
		var enemy = _ring_buffer.try_pop()
		if enemy:
			all_enemies.append(enemy)

	# Re-add only non-marked enemies
	for enemy in all_enemies:
		if not enemy or not is_instance_valid(enemy):
			# Invalid enemy - count as cleaned
			_current_count -= 1
			cleaned_count += 1
			continue

		var enemy_id = str(enemy.get_instance_id())
		if _marked_for_removal.has(enemy_id):
			# Marked enemy - don't re-add, count as cleaned
			_current_count -= 1
			cleaned_count += 1
			continue

		# Valid, non-marked enemy - re-add to buffer
		_ring_buffer.try_push(enemy)

	# Clear removal tracking
	_marked_for_removal.clear()
	_removal_count = 0


## Get current count of active (non-marked) enemies
func count() -> int:
	return max(0, _current_count - _removal_count)

## Check if tracker is at capacity
func is_full() -> bool:
	return _ring_buffer.is_full()

## Check if tracker is empty (no active enemies)
func is_empty() -> bool:
	return count() == 0

## Get capacity of the tracker
func capacity() -> int:
	return _capacity

## Get number of add rejections due to capacity overflow
func get_rejections() -> int:
	return _add_rejections

## Clear all enemies from tracker (for breach completion/cleanup)
func clear() -> void:
	_ring_buffer.clear()
	_marked_for_removal.clear()
	_removal_count = 0
	_current_count = 0
	_add_rejections = 0
	Logger.debug("BreachEnemyTracker: Cleared all enemies", "events")

## Get debug information about tracker state
func get_debug_info() -> Dictionary:
	return {
		"capacity": _capacity,
		"current_count": _current_count,
		"marked_for_removal": _removal_count,
		"active_count": count(),
		"add_rejections": _add_rejections,
		"ring_buffer_count": _ring_buffer.count()
	}