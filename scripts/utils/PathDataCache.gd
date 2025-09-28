@tool
extends RefCounted
class_name PathDataCache

## Path data caching with ObjectPool integration for zero-allocation path generation
## Eliminates repeated Array[Vector2] allocations from PathSegment.get_full_path() calls
## Based on PATH_GENERATION_PERFORMANCE_OPTIMIZATION task requirements

# Cache for computed path data
var segment_cache: Dictionary = {}  # PathSegment -> PackedVector2Array
var array_pool: ObjectPool     # for Array[Vector2] reuse
var cache_hits: int = 0
var cache_misses: int = 0

func _init():
	# Initialize ObjectPool for Array instances
	array_pool = ObjectPool.new()
	array_pool.setup(50, Callable(self, "_create_array"), Callable(self, "_reset_array"))  # Pool of 50 Array instances

## Factory function for creating new arrays
func _create_array() -> Array:
	return []

## Reset function for cleaning arrays before returning to pool
func _reset_array(array: Array) -> void:
	array.clear()

## Get cached path data or compute once and cache
## @param segment: PathSegment to get full path for
## @return: PackedVector2Array with cached path points
func get_cached_path(segment) -> PackedVector2Array:
	var segment_id = segment.get_instance_id()

	if segment_cache.has(segment_id):
		cache_hits += 1
		return segment_cache[segment_id]

	# Cache miss - compute and store
	cache_misses += 1
	var path_points = segment.get_full_path()

	# Convert Array[Vector2] to PackedVector2Array for efficient storage
	var packed_path = PackedVector2Array()
	packed_path.resize(path_points.size())
	for i in range(path_points.size()):
		packed_path[i] = path_points[i]

	segment_cache[segment_id] = packed_path
	return packed_path

## Get reusable Array from pool for temporary operations
## @return: Array from object pool
func get_temp_array() -> Array:
	return array_pool.acquire()

## Return Array to pool for reuse
## @param array: Array to return to pool
func return_temp_array(array: Array) -> void:
	array_pool.release(array)

## Get cached path as reusable Array for compatibility
## @param segment: PathSegment to get full path for
## @return: Array from pool with cached data
func get_cached_path_as_array(segment) -> Array:
	var packed_path = get_cached_path(segment)
	var temp_array = get_temp_array()

	# Copy PackedVector2Array to Array
	temp_array.resize(packed_path.size())
	for i in range(packed_path.size()):
		temp_array[i] = packed_path[i]

	return temp_array

## Clear cache (useful for memory management or when paths change)
func clear_cache() -> void:
	segment_cache.clear()
	cache_hits = 0
	cache_misses = 0

## Get cache performance statistics
func get_cache_stats() -> Dictionary:
	var total_requests = cache_hits + cache_misses
	var hit_rate = float(cache_hits) / max(1, total_requests)

	return {
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_rate": hit_rate,
		"cached_segments": segment_cache.size(),
		"pool_available": array_pool.available_count()
	}

## Pre-warm cache with all path segments for optimal performance
## @param paths: Array of path objects to cache
func preload_paths(paths: Array) -> void:
	for path in paths:
		get_cached_path(path)

	# Debug: Cache performance
	if cache_misses > 0:
		var stats = get_cache_stats()
		var message = "PathDataCache preloaded: %d segments, hit rate: %.1f%%" % [
			stats.cached_segments, stats.hit_rate * 100
		]
		if Engine.is_editor_hint():
			# Use Logger even in editor mode for consistency
			if Logger:
				Logger.debug(message, "pathgen")
			else:
				print(message)  # Fallback only if Logger unavailable
		else:
			Logger.debug(message, "pathgen")

## Memory cleanup when cache no longer needed
func cleanup() -> void:
	clear_cache()
	if array_pool:
		array_pool.clear()
		array_pool = null
