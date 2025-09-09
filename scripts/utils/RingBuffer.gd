extends RefCounted
class_name RingBuffer

## Fixed-size circular buffer for zero-allocation queuing.
## Uses power-of-two sizing and bit masking for efficient wraparound.
## Thread-safe for single producer/single consumer on main thread.

var _buf: Array
var _capacity: int
var _mask: int
var _head: int = 0
var _tail: int = 0
var _count: int = 0

## Setup the ring buffer with the given capacity.
## Capacity is rounded up to next power of two for efficient masking.
func setup(capacity: int) -> void:
	# Use next power-of-two for simple masking
	_capacity = max(2, _next_pow2(capacity))
	_mask = _capacity - 1
	_buf = []
	_buf.resize(_capacity)
	_head = 0
	_tail = 0
	_count = 0

## Try to push an item to the buffer.
## Returns true if successful, false if buffer is full.
func try_push(item) -> bool:
	if _count == _capacity:
		return false
	_buf[_head] = item
	_head = (_head + 1) & _mask
	_count += 1
	return true

## Try to pop an item from the buffer.
## Returns the item if successful, null if buffer is empty.
func try_pop():
	if _count == 0:
		return null
	var item = _buf[_tail]
	_buf[_tail] = null  # Clear reference for GC
	_tail = (_tail + 1) & _mask
	_count -= 1
	return item

## Get current number of items in buffer.
func count() -> int: 
	return _count

## Check if buffer is full.
func is_full() -> bool: 
	return _count == _capacity

## Check if buffer is empty.
func is_empty() -> bool: 
	return _count == 0

## Get buffer capacity.
func capacity() -> int:
	return _capacity

## Clear all items from buffer without deallocating.
func clear() -> void:
	for i in range(_capacity):
		_buf[i] = null
	_head = 0
	_tail = 0
	_count = 0

## Calculate next power of 2 for efficient masking.
static func _next_pow2(v: int) -> int:
	v -= 1
	v |= v >> 1
	v |= v >> 2
	v |= v >> 4
	v |= v >> 8
	v |= v >> 16
	return v + 1