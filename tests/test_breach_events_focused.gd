extends Node2D

## Focused Breach Event Testing
## Tests core breach mechanics that work independently of arena spawn zones
## Validates breach calculations, lifecycle, and deterministic behavior

# Test configuration
const TEST_SEED = 12345
const BREACH_POSITIONS = [Vector2(200, 200), Vector2(500, 200), Vector2(200, 500)]

# Test state
var test_results: Dictionary = {}
var breach_handler: BreachEventHandler
var test_arena_root: Node2D

func _ready():
	print("=== FOCUSED BREACH EVENT TEST ===")
	print("Testing breach core mechanics without spawn system dependencies")

	_setup_test_environment()
	await _run_tests()
	_report_results()

	# Auto-quit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _setup_test_environment():
	print("\n--- Setting up test environment ---")

	# Verify autoloads
	assert(RNG != null, "RNG autoload required")
	assert(EventBus != null, "EventBus autoload required")

	# Seed RNG
	RNG.seed_run(TEST_SEED)
	print("RNG seeded with: %d" % TEST_SEED)

	# Create test arena
	test_arena_root = Node2D.new()
	test_arena_root.name = "TestArenaRoot"
	add_child(test_arena_root)

	# Create large test zones
	_create_test_zones()

	# Initialize minimal breach handler (no SpawnDirector dependency)
	breach_handler = BreachEventHandler.new()
	add_child(breach_handler)

	# Load breach config directly
	var config_path = "res://data/balance/breach_event_config.tres"
	var config = ResourceLoader.load(config_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	breach_handler.breach_config = config

	print("Test environment ready")

func _create_test_zones():
	"""Create test zones for breach events"""
	for i in range(BREACH_POSITIONS.size()):
		var zone = Area2D.new()
		zone.name = "TestZone_%d" % i
		zone.global_position = BREACH_POSITIONS[i]

		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(1000, 1000)  # Very large zones
		collision.shape = shape
		zone.add_child(collision)

		test_arena_root.add_child(zone)
		print("Created zone %d at %s" % [i, BREACH_POSITIONS[i]])

func _run_tests():
	print("\n=== RUNNING TESTS ===")

	# Test 1: Breach Creation & Lifecycle
	print("\n--- Test 1: Breach Creation & Lifecycle ---")
	test_results["breach_lifecycle"] = await _test_breach_lifecycle()

	# Test 2: Ring Calculation Determinism
	print("\n--- Test 2: Ring Calculation Determinism ---")
	test_results["ring_determinism"] = await _test_ring_determinism()

	# Test 3: Configuration Loading
	print("\n--- Test 3: Configuration Loading ---")
	test_results["config_loading"] = _test_config_loading()

	# Test 4: Multi-Breach Independence
	print("\n--- Test 4: Multi-Breach Independence ---")
	test_results["multi_breach"] = _test_multi_breach_independence()

func _test_breach_lifecycle() -> bool:
	"""Test breach creation and phase transitions"""
	print("Testing breach lifecycle...")

	var test_zone = test_arena_root.get_child(0) as Area2D
	var breach_event = EventInstance.new(test_zone, breach_handler.breach_config)

	# Test initial state
	if breach_event.phase != EventInstance.Phase.WAITING:
		print("ERROR: Initial phase should be WAITING")
		return false

	# Test activation
	breach_event.activate()
	if breach_event.phase != EventInstance.Phase.EXPANDING:
		print("ERROR: Phase should be EXPANDING after activation")
		return false

	# Test expansion timing
	var dt = 1.0 / 30.0
	var expansion_time = 0.0
	var initial_radius = breach_event.current_radius

	# Run expansion until it naturally completes (10+ seconds)
	print("  Waiting for natural expansion completion...")
	while breach_event.phase == EventInstance.Phase.EXPANDING and expansion_time < 12.0:
		breach_event.update_lifecycle(dt)
		expansion_time += dt
		await get_tree().process_frame

	if breach_event.current_radius <= initial_radius:
		print("ERROR: Radius should increase during expansion")
		return false

	print("  Expansion completed, radius: %.1f" % breach_event.current_radius)

	# Check if breach naturally transitioned to shrinking
	if breach_event.phase != EventInstance.Phase.SHRINKING:
		print("ERROR: Breach should transition to shrinking after expansion")
		return false

	var max_radius = breach_event.current_radius

	# Run shrinking for several seconds
	var shrink_time = 0.0
	print("  Testing shrinking phase...")
	while shrink_time < 5.0 and breach_event.phase == EventInstance.Phase.SHRINKING:
		breach_event.update_lifecycle(dt)
		shrink_time += dt
		await get_tree().process_frame

	print("  Shrinking completed, final radius: %.1f" % breach_event.current_radius)

	if breach_event.current_radius >= max_radius:
		print("ERROR: Radius should decrease during shrinking (was %.1f, now %.1f)" % [max_radius, breach_event.current_radius])
		return false

	print("✓ Breach lifecycle working correctly")
	return true

func _test_ring_determinism() -> bool:
	"""Test that ring calculations are deterministic"""
	print("Testing ring calculation determinism...")

	# Capture calculations from first run
	RNG.seed_run(TEST_SEED)
	var first_rings = await _calculate_rings_for_expansion()

	# Capture calculations from second run with same seed
	RNG.seed_run(TEST_SEED)
	var second_rings = await _calculate_rings_for_expansion()

	print("First run: %d rings calculated" % first_rings.size())
	print("Second run: %d rings calculated" % second_rings.size())

	if first_rings.size() != second_rings.size():
		print("ERROR: Different number of rings calculated")
		return false

	# Compare ring data
	var matches = 0
	for i in range(first_rings.size()):
		var ring1 = first_rings[i]
		var ring2 = second_rings[i]

		if abs(ring1.radius - ring2.radius) < 0.1 and ring1.enemy_count == ring2.enemy_count:
			matches += 1
		else:
			print("Ring %d mismatch: R1(%.1f, %d) vs R2(%.1f, %d)" % [
				i, ring1.radius, ring1.enemy_count, ring2.radius, ring2.enemy_count
			])

	if matches == first_rings.size():
		print("✓ Ring calculations are deterministic (%d rings matched)" % matches)
		return true
	else:
		print("ERROR: Ring calculations not deterministic (%d/%d matched)" % [matches, first_rings.size()])
		return false

func _calculate_rings_for_expansion() -> Array:
	"""Calculate ring data during breach expansion"""
	var rings = []
	var test_zone = test_arena_root.get_child(0) as Area2D
	var breach_event = EventInstance.new(test_zone, breach_handler.breach_config)

	breach_event.activate()

	var dt = 1.0 / 30.0
	var time = 0.0
	var last_ring_radius = 0.0

	# Track when new rings would be spawned
	while time < 3.0:  # 3 seconds of expansion
		var old_radius = breach_event.current_radius
		breach_event.update_lifecycle(dt)
		time += dt

		# Check if a new ring would be spawned
		var ring_threshold = breach_handler.breach_config.ring_spawn_interval
		if breach_event.current_radius - last_ring_radius >= ring_threshold:
			# Calculate enemy count for this ring (same logic as breach system)
			var circumference = 2 * PI * breach_event.current_radius
			var edge_circumference = circumference * 0.87  # edge_spawn_factor
			var enemy_count = max(3, int(edge_circumference * breach_handler.breach_config.enemy_density))

			rings.append({
				"radius": breach_event.current_radius,
				"enemy_count": enemy_count
			})
			last_ring_radius = breach_event.current_radius

		await get_tree().process_frame

	return rings

func _test_config_loading() -> bool:
	"""Test that configuration loads properly"""
	print("Testing configuration loading...")

	var config = breach_handler.breach_config
	if not config:
		print("ERROR: No breach config loaded")
		return false

	# Check some expected values
	if config.max_radius <= 0:
		print("ERROR: Invalid max_radius: %f" % config.max_radius)
		return false

	if config.ring_spawn_interval <= 0:
		print("ERROR: Invalid ring_spawn_interval: %f" % config.ring_spawn_interval)
		return false

	if config.enemy_density <= 0:
		print("ERROR: Invalid enemy_density: %f" % config.enemy_density)
		return false

	print("✓ Configuration loaded successfully")
	print("  Max radius: %.1f" % config.max_radius)
	print("  Ring interval: %.1f" % config.ring_spawn_interval)
	print("  Enemy density: %.3f" % config.enemy_density)
	return true

func _test_multi_breach_independence() -> bool:
	"""Test that multiple breach events have unique IDs"""
	print("Testing multi-breach independence...")

	var breach_ids = []

	# Create 3 breach events
	for i in range(3):
		var zone = test_arena_root.get_child(i) as Area2D
		var breach_event = EventInstance.new(zone, breach_handler.breach_config)
		breach_ids.append(breach_event.breach_id)
		print("Created breach %d with ID: %s" % [i, breach_event.breach_id])

	# Check all IDs are unique
	var unique_ids = {}
	for breach_id in breach_ids:
		if unique_ids.has(breach_id):
			print("ERROR: Duplicate breach ID found: %s" % breach_id)
			return false
		unique_ids[breach_id] = true

	print("✓ All breach IDs are unique")
	return true

func _report_results():
	print("\n=== TEST RESULTS ===")

	var passed = 0
	var total = test_results.size()

	for test_name in test_results:
		var result = test_results[test_name]
		var status = "✓" if result else "✗"
		print("%s %s" % [status, test_name.to_upper()])
		if result:
			passed += 1

	print("\nSUMMARY: %d/%d tests passed" % [passed, total])

	if passed == total:
		print("🎉 ALL TESTS PASSED - Breach event core mechanics validated!")
	else:
		print("⚠️ SOME TESTS FAILED - Review breach implementation")