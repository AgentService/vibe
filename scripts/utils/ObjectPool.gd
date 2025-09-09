extends RefCounted
class_name ObjectPool

## Generic object pool for zero-allocation patterns.
## Pre-allocates objects and reuses them to avoid runtime allocation.
## Uses factory callable for creating new objects and reset callable for cleanup.

var _pool: Array = []
var _factory: Callable
var _reset: Callable

## Setup the object pool with initial objects.
## @param initial_size: Number of objects to pre-allocate
## @param factory: Callable that creates new objects when pool is empty
## @param reset: Callable that clears/resets objects before returning to pool
func setup(initial_size: int, factory: Callable, reset: Callable) -> void:
	_factory = factory
	_reset = reset
	_pool.resize(0)
	for i in initial_size:
		_pool.push_back(_factory.call())

## Acquire an object from the pool.
## If pool is empty, creates a new object using factory callable.
func acquire():
	if _pool.is_empty():
		return _factory.call()
	return _pool.pop_back()

## Release an object back to the pool.
## Calls reset callable to clear object state before storing.
func release(obj) -> void:
	_reset.call(obj)
	_pool.push_back(obj)

## Get current number of available objects in pool.
func available_count() -> int:
	return _pool.size()

## Check if pool has available objects.
func is_empty() -> bool:
	return _pool.is_empty()

## Clear all objects from pool (useful for cleanup).
func clear() -> void:
	_pool.clear()

## Pre-fill pool with additional objects if needed.
func ensure_capacity(min_available: int) -> void:
	var needed = min_available - _pool.size()
	if needed > 0:
		for i in needed:
			_pool.push_back(_factory.call())