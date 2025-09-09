extends Node2D

## Unit tests for zero-allocation queue components (RingBuffer, ObjectPool, PayloadReset)
## Tests FIFO ordering, overflow policies, and pool behavior

# Preload utility classes for testing
const RingBuffer = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")
const PayloadReset = preload("res://scripts/utils/PayloadReset.gd")

func _ready() -> void:
	print("=== EventQueue Component Tests ===")
	
	test_ring_buffer()
	test_object_pool()
	test_payload_reset()
	test_integration()
	
	print("=== All EventQueue Tests Complete ===")
	get_tree().quit()

func test_ring_buffer() -> void:
	print("\n-- Testing RingBuffer --")
	
	# Test basic setup
	var ring = RingBuffer.new()
	ring.setup(4)  # Should round up to next power of 2
	
	test_assert(ring.capacity() == 4, "Capacity should be 4")
	test_assert(ring.is_empty(), "Should start empty")
	test_assert(not ring.is_full(), "Should not start full")
	test_assert(ring.count() == 0, "Count should be 0")
	
	# Test push/pop FIFO
	test_assert(ring.try_push("first"), "Should push first item")
	test_assert(ring.try_push("second"), "Should push second item")
	test_assert(ring.try_push("third"), "Should push third item")
	test_assert(ring.count() == 3, "Count should be 3")
	
	var item1 = ring.try_pop()
	test_assert(item1 == "first", "Should pop first item: " + str(item1))
	var item2 = ring.try_pop()
	test_assert(item2 == "second", "Should pop second item: " + str(item2))
	test_assert(ring.count() == 1, "Count should be 1")
	
	# Test overflow behavior
	test_assert(ring.try_push("fourth"), "Should push fourth item")
	test_assert(ring.try_push("fifth"), "Should push fifth item")
	test_assert(ring.is_full(), "Should be full")
	test_assert(not ring.try_push("sixth"), "Should reject when full")
	
	# Test wraparound
	var item3 = ring.try_pop()
	test_assert(item3 == "third", "Should pop third item")
	test_assert(ring.try_push("sixth"), "Should push after pop")
	
	# Test clear
	ring.clear()
	test_assert(ring.is_empty(), "Should be empty after clear")
	test_assert(ring.count() == 0, "Count should be 0 after clear")
	
	print("✓ RingBuffer tests passed")

func test_object_pool() -> void:
	print("\n-- Testing ObjectPool --")
	
	var pool = ObjectPool.new()
	
	# Factory function for creating dictionaries
	var dict_factory = func(): return {"test": true, "value": 0}
	var dict_reset = func(d: Dictionary): 
		d["test"] = true
		d["value"] = 0
	
	pool.setup(3, dict_factory, dict_reset)
	test_assert(pool.available_count() == 3, "Should have 3 available objects")
	
	# Test acquire
	var obj1 = pool.acquire()
	var obj2 = pool.acquire()
	var obj3 = pool.acquire()
	test_assert(pool.available_count() == 0, "Should have 0 available after acquiring 3")
	test_assert(obj1.has("test"), "Object should have test key")
	
	# Test acquire when empty (should create new)
	var obj4 = pool.acquire()
	test_assert(obj4.has("test"), "New object should have test key")
	test_assert(pool.available_count() == 0, "Should still be 0 available")
	
	# Test release
	obj1["test"] = false  # Modify object
	obj1["value"] = 99
	pool.release(obj1)
	test_assert(pool.available_count() == 1, "Should have 1 available after release")
	
	# Test reset functionality
	var reacquired = pool.acquire()
	test_assert(reacquired["test"] == true, "Reset should restore test to true")
	test_assert(reacquired["value"] == 0, "Reset should restore value to 0")
	
	print("✓ ObjectPool tests passed")

func test_payload_reset() -> void:
	print("\n-- Testing PayloadReset --")
	
	# Test damage payload creation and clearing
	var payload = PayloadReset.create_damage_payload()
	test_assert(payload.has("target"), "Should have target key")
	test_assert(payload.has("tags"), "Should have tags key")
	test_assert(payload["damage_type"] == "generic", "Should have generic damage type")
	
	# Modify payload
	payload["target"] = "enemy_5"
	payload["base_damage"] = 50.0
	payload["tags"] = ["fire", "magic"]
	
	# Test clearing
	PayloadReset.clear_damage_payload(payload)
	test_assert(payload["target"] == "", "Target should be cleared")
	test_assert(payload["base_damage"] == 0.0, "Damage should be cleared")
	test_assert(payload["tags"].size() == 0, "Tags should be empty array")
	test_assert(payload.has("target"), "Target key should still exist")
	
	# Test tag arrays
	var tags = PayloadReset.create_tags_array()
	tags.append("test1")
	tags.append("test2")
	test_assert(tags.size() == 2, "Tags should have 2 items")
	
	PayloadReset.clear_tags_array(tags)
	test_assert(tags.size() == 0, "Tags should be empty after clear")
	
	print("✓ PayloadReset tests passed")

func test_integration() -> void:
	print("\n-- Testing Integration --")
	
	# Test complete damage queue simulation
	var queue = RingBuffer.new()
	queue.setup(8)
	
	var pool = ObjectPool.new()
	pool.setup(4, PayloadReset.create_damage_payload, PayloadReset.clear_damage_payload)
	
	var tags_pool = ObjectPool.new()
	tags_pool.setup(4, PayloadReset.create_tags_array, PayloadReset.clear_tags_array)
	
	# Simulate damage enqueuing
	for i in 3:
		var payload = pool.acquire()
		payload["target"] = "enemy_%d" % i
		payload["base_damage"] = 10.0 + i * 5
		var tags = tags_pool.acquire()
		tags.append("melee")
		if i == 1:
			tags.append("crit")
		payload["tags"] = tags
		
		test_assert(queue.try_push(payload), "Should enqueue payload %d" % i)
	
	test_assert(queue.count() == 3, "Queue should have 3 items")
	
	# Simulate damage processing
	var processed_count = 0
	while not queue.is_empty():
		var payload = queue.try_pop()
		test_assert(payload != null, "Should get valid payload")
		test_assert(payload.has("target"), "Payload should have target")
		
		# Release resources back to pools
		var tags = payload.get("tags", null)
		if tags:
			tags_pool.release(tags)
			payload["tags"] = []
		pool.release(payload)
		processed_count += 1
	
	test_assert(processed_count == 3, "Should process 3 payloads")
	test_assert(pool.available_count() == 4, "All payloads should be returned to pool")
	test_assert(tags_pool.available_count() == 4, "All tag arrays should be returned to pool")
	
	print("✓ Integration tests passed")

func test_assert(condition: bool, message: String) -> void:
	if not condition:
		print("ASSERTION FAILED: " + message)
		get_tree().quit(1)