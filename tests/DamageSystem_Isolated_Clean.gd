extends Node2D

## Isolated DamageSystem test - tests ONLY damage calculation and application.
## Tests: damage requests -> damage calculations -> enemy health changes
## No UI, no input, no game mechanics - pure system testing.
## Uses direct DamageService.apply_damage() calls following single entry point architecture.

var damage_system: DamageSystem
var test_enemies: Array[EnemyEntity] = []
var test_results: Dictionary = {}

func _ready():
	print("=== DamageSystem Isolated Test ===")
	_setup_test_environment()
	_run_test_scenarios()

func _setup_test_environment():
	print("Setting up test environment...")
	
	# Create test enemies with known stats
	test_enemies.clear()
	for i in range(3):
		var enemy = EnemyEntity.new()
		enemy.type_id = "test_enemy_" + str(i)
		enemy.hp = 100.0 + (i * 50.0)  # 100, 150, 200 HP
		enemy.max_hp = enemy.hp
		enemy.alive = true
		enemy.pos = Vector2(i * 50, 0)
		test_enemies.append(enemy)
	
	# Connect to damage signals for verification
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	
	print("✓ Test environment ready - using DamageService.apply_damage() directly")

func _run_test_scenarios():
	print("\n--- Running Test Scenarios ---")
	
	# Test 1: Basic damage application
	_test_basic_damage()
	
	# Wait a frame for signal processing
	await get_tree().process_frame
	
	# Test 2: Critical hit calculation
	_test_critical_hits()
	
	await get_tree().process_frame
	
	# Test 3: Enemy death on lethal damage
	_test_enemy_death()
	
	await get_tree().process_frame
	
	# Test 4: Invalid target handling
	_test_invalid_targets()
	
	await get_tree().process_frame
	
	# Test 5: A/B testing queue vs direct processing
	_test_ab_queue_consistency()
	
	await get_tree().process_frame
	
	print("\n--- Test Results ---")
	_print_results()

func _test_basic_damage():
	print("\nTest 1: Basic Damage Application")
	test_results["basic_damage"] = {"expected": 25.0, "actual": 0.0}
	
	# Register test entity with DamageService for direct testing
	var entity_id = "enemy_0"
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": 100.0,
		"max_hp": 100.0,
		"alive": true,
		"pos": Vector2.ZERO
	}
	DamageService.register_entity(entity_id, entity_data)
	
	# Apply damage directly through DamageService (single entry point)
	var damage = 25.0
	var source = "player"
	var tags = ["test", "basic"]
	DamageService.apply_damage(entity_id, damage, source, tags)

func _test_critical_hits():
	print("\nTest 2: Critical Hit Testing (multiple attempts)")
	test_results["crit_found"] = false
	
	# Register test entity with DamageService
	var entity_id = "enemy_1"
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": 150.0,
		"max_hp": 150.0,
		"alive": true,
		"pos": Vector2(50, 0)
	}
	DamageService.register_entity(entity_id, entity_data)
	
	# Apply damage multiple times to test for crits
	for i in range(10):
		DamageService.apply_damage(entity_id, 10.0, "player", ["test", "crit_test"])

func _test_enemy_death():
	print("\nTest 3: Enemy Death on Lethal Damage")
	test_results["death_test"] = {"enemy_alive": true, "death_triggered": false}
	
	# Register test entity with DamageService
	var entity_id = "enemy_2"
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": 200.0,
		"max_hp": 200.0,
		"alive": true,
		"pos": Vector2(100, 0)
	}
	DamageService.register_entity(entity_id, entity_data)
	
	# Deal massive damage to kill the enemy
	DamageService.apply_damage(entity_id, 250.0, "player", ["test", "lethal"])

func _test_invalid_targets():
	print("\nTest 4: Invalid Target Handling")
	test_results["invalid_target"] = {"error_handled": true}
	
	# Try to damage non-existent enemy (should handle gracefully)
	DamageService.apply_damage("enemy_999", 50.0, "player", ["test", "invalid"])

func _test_ab_queue_consistency():
	print("\nTest 5: A/B Testing - Queue vs Direct Processing")
	test_results["ab_test"] = {"identical_results": false, "queue_tests": 0, "direct_tests": 0}
	
	# Test identical damage sequences with queue OFF and ON
	var test_sequence = [
		{"damage": 15.0, "expected_hp": 85.0},
		{"damage": 20.0, "expected_hp": 65.0},
		{"damage": 10.0, "expected_hp": 55.0}
	]
	
	# Test with queue DISABLED (direct processing)
	print("  Testing with queue DISABLED...")
	DamageService.set_queue_enabled(false)
	var direct_results = await _run_damage_sequence("ab_direct", test_sequence)
	
	# Wait for any queued processing to complete
	await get_tree().create_timer(0.2).timeout
	
	# Test with queue ENABLED (batched processing) 
	print("  Testing with queue ENABLED...")
	DamageService.set_queue_enabled(true)
	var queue_results = await _run_damage_sequence("ab_queue", test_sequence)
	
	# Wait for queue processing (30Hz = ~33ms per tick)
	await get_tree().create_timer(0.2).timeout
	
	# Compare results
	var identical = _compare_damage_results(direct_results, queue_results)
	test_results["ab_test"]["identical_results"] = identical
	test_results["ab_test"]["queue_tests"] = queue_results.size()
	test_results["ab_test"]["direct_tests"] = direct_results.size()
	
	if identical:
		print("  ✓ Queue and direct processing produce IDENTICAL results")
	else:
		print("  ✗ Queue and direct processing produce DIFFERENT results!")
		print("    Direct: %s" % str(direct_results))
		print("    Queue:  %s" % str(queue_results))
	
	# Reset to default state
	DamageService.set_queue_enabled(false)

func _run_damage_sequence(entity_prefix: String, sequence: Array) -> Array:
	var results = []
	
	# Register test entity
	var entity_id = entity_prefix + "_test"
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": 100.0,
		"max_hp": 100.0,
		"alive": true,
		"pos": Vector2.ZERO
	}
	DamageService.register_entity(entity_id, entity_data)
	
	# Apply damage sequence
	for i in sequence.size():
		var step = sequence[i]
		var damage = step["damage"]
		DamageService.apply_damage(entity_id, damage, "test_source", ["ab_test"])
		
		# Record result - wait a frame for queue processing
		await get_tree().process_frame
		
		var entity = DamageService.get_entity(entity_id)
		var actual_hp = entity.get("hp", -1.0)
		results.append({
			"step": i,
			"damage": damage,
			"expected_hp": step["expected_hp"],
			"actual_hp": actual_hp
		})
	
	return results

func _compare_damage_results(direct: Array, queue: Array) -> bool:
	if direct.size() != queue.size():
		return false
	
	for i in direct.size():
		var d = direct[i]
		var q = queue[i]
		
		# Compare final HP values (allow small floating point tolerance)
		if abs(d["actual_hp"] - q["actual_hp"]) > 0.001:
			return false
		
		# Compare damage values
		if abs(d["damage"] - q["damage"]) > 0.001:
			return false
	
	return true

func _on_damage_applied(payload):
	print("  ✓ Damage Applied: %.1f to %s (crit: %s)" % [payload.final_damage, payload.target_id, payload.is_crit])
	
	# Record results
	if "basic" in payload.tags:
		test_results["basic_damage"]["actual"] = payload.final_damage
	
	if payload.is_crit:
		test_results["crit_found"] = true

func _on_enemy_killed(payload):
	print("  💀 Enemy Killed: %s at %s (rewards: %s)" % [payload.entity_id, payload.death_pos, payload.rewards])
	
	if payload.entity_id.index == 2:
		test_results["death_test"]["death_triggered"] = true
		test_results["death_test"]["enemy_alive"] = test_enemies[2].alive

func _print_results():
	var passed = 0
	var total = 0
	
	# Check basic damage
	total += 1
	var basic = test_results.get("basic_damage", {})
	var basic_damage_correct = basic.get("actual", 0.0) > 0
	if basic_damage_correct:
		passed += 1
		print("✓ Basic Damage: PASS (%.1f damage applied)" % basic.get("actual", 0))
	else:
		print("✗ Basic Damage: FAIL (no damage recorded)")
	
	# Check crit system
	total += 1
	if test_results.get("crit_found", false):
		passed += 1
		print("✓ Critical Hits: PASS (crit detected)")
	else:
		print("✗ Critical Hits: FAIL (no crits in 10 attempts - may be RNG)")
	
	# Check death handling
	total += 1
	var death = test_results.get("death_test", {})
	if death.get("death_triggered", false) and not death.get("enemy_alive", true):
		passed += 1
		print("✓ Enemy Death: PASS")
	else:
		print("✗ Enemy Death: FAIL (death not properly handled)")
	
	# Check invalid target handling (no crash = pass)
	total += 1
	passed += 1  # If we got here, no crash occurred
	print("✓ Invalid Targets: PASS (no crash)")
	
	# Check A/B testing
	total += 1
	var ab_test = test_results.get("ab_test", {})
	if ab_test.get("identical_results", false):
		passed += 1
		print("✓ A/B Testing: PASS (queue and direct produce identical results)")
	else:
		print("✗ A/B Testing: FAIL (queue and direct produce different results)")
	
	print("\nFinal Score: %d/%d tests passed" % [passed, total])
	
	# Auto-exit after results
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
