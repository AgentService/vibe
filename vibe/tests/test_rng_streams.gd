extends RefCounted

## Test script to verify RNG stream determinism.
## Should produce identical sequences when seeded with the same values.

class_name TestRngStreams

static func run_test() -> void:
	print("=== RNG Stream Determinism Test ===")
	
	var test_seed := 12345
	var stream_names := ["crit", "loot", "waves", "ai", "craft"]
	
	# First run
	print("\nFirst run (seed: %d):" % test_seed)
	var first_results := _generate_sequence(test_seed, stream_names)
	
	# Second run with same seed
	print("\nSecond run (seed: %d):" % test_seed)
	var second_results := _generate_sequence(test_seed, stream_names)
	
	# Verify they match
	var all_match := true
	for stream_name in stream_names:
		if not _arrays_match(first_results[stream_name], second_results[stream_name]):
			print("ERROR: Stream '%s' produced different results!" % stream_name)
			all_match = false
	
	if all_match:
		print("\n✓ SUCCESS: All streams produced identical sequences")
	else:
		print("\n✗ FAILURE: Some streams were non-deterministic")
	
	# Test different seed produces different results
	print("\nThird run (seed: %d):" % (test_seed + 1))
	var third_results := _generate_sequence(test_seed + 1, stream_names)
	
	var any_differ := false
	for stream_name in stream_names:
		if not _arrays_match(first_results[stream_name], third_results[stream_name]):
			any_differ = true
			break
	
	if any_differ:
		print("✓ SUCCESS: Different seed produced different results")
	else:
		print("✗ FAILURE: Different seed produced identical results")

static func _generate_sequence(seed_value: int, stream_names: Array) -> Dictionary:
	var results := {}
	
	# Create fresh RNG instance for testing
	var rng_node: RngService
	if Engine.has_singleton("RNG"):
		rng_node = Engine.get_singleton("RNG")
	else:
		# Fallback: create instance manually for headless mode
		rng_node = load("res://autoload/RNG.gd").new()
	rng_node.seed_run(seed_value)
	
	for stream_name in stream_names:
		var sequence := []
		
		# Generate various types of random values
		sequence.append(rng_node.randf(stream_name))
		sequence.append(rng_node.randi_range(stream_name, 1, 100))
		sequence.append(rng_node.randf_range(stream_name, 0.0, 10.0))
		sequence.append(rng_node.randi(stream_name))
		sequence.append(rng_node.randf(stream_name))
		
		results[stream_name] = sequence
		
		print("  %s: [%.3f, %d, %.3f, %d, %.3f]" % [
			stream_name,
			sequence[0], sequence[1], sequence[2], sequence[3], sequence[4]
		])
	
	return results

static func _arrays_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	
	for i in range(a.size()):
		if typeof(a[i]) != typeof(b[i]):
			return false
		
		# Use epsilon comparison for floats
		if typeof(a[i]) == TYPE_FLOAT:
			if abs(a[i] - b[i]) > 1e-6:
				return false
		else:
			if a[i] != b[i]:
				return false
	
	return true
