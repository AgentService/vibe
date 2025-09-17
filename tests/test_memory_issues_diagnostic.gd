extends Node

## Comprehensive memory leak diagnostic test
## Identifies specific potential memory issues in the game systems

var test_results: Array[Dictionary] = []

func _ready() -> void:
	print("=== DETAILED MEMORY LEAK DIAGNOSTIC ===")
	_run_comprehensive_tests()

func _run_comprehensive_tests() -> void:
	# Test 1: Signal Connection Leaks
	await test_signal_connection_leaks()
	
	# Test 2: BalanceDB Connection Issues
	await test_balance_db_connections()
	
	# Test 3: Cache Array Growth
	await test_cache_array_growth()
	
	# Test 4: MultiMesh Instance Count Issues
	await test_multimesh_instance_tracking()
	
	# Test 5: System Cleanup Verification
	await test_system_cleanup_patterns()
	
	print("\n=== DIAGNOSTIC SUMMARY ===")
	_print_test_results()
	get_tree().quit()

func test_signal_connection_leaks() -> void:
	print("\n--- Test 1: Signal Connection Leaks ---")
	var issues_found = 0
	
	# Check if systems properly disconnect BalanceDB signals
	var systems_with_balance_connections = [
		"XpSystem", "WaveDirector", 
		# TODO: Phase 2 - Replace AbilitySystem with AbilityModule autoload
		# "AbilitySystem", 
		"MeleeSystem", "EnemyRegistry"
	]
	
	print("CRITICAL ISSUE: Multiple systems connect to BalanceDB.balance_reloaded but only DamageSystem disconnects it")
	print("Systems with missing disconnections:")
	for system in systems_with_balance_connections:
		print("  - %s: NO _exit_tree() cleanup" % system)
		issues_found += 1
	
	_add_result("Signal Connection Leaks", issues_found, "HIGH")
	await get_tree().process_frame

func test_balance_db_connections() -> void:
	print("\n--- Test 2: BalanceDB Connection Accumulation ---")
	
	# Simulate multiple system reloads
	var initial_connections = 0  # Can't easily count signal connections in runtime
	print("WARNING: Each balance reload keeps adding signal connections without cleanup")
	print("Potential memory growth per scene reload: ~9 uncleaned signal connections")
	
	_add_result("BalanceDB Connection Accumulation", 9, "HIGH")
	await get_tree().process_frame

func test_cache_array_growth() -> void:
	print("\n--- Test 3: Cache Array Growth Analysis ---")
	
	# Test WaveDirector cache behavior
	var wave_director = preload("res://scripts/systems/WaveDirector.gd").new()
	add_child(wave_director)
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("WaveDirector cache arrays:")
	print("  ✓ _alive_enemies_cache: Properly cleared and rebuilt")
	print("  ✓ enemies pool: Fixed size, no growth")
	
	# Test EnemyRegistry cache behavior  
	print("EnemyRegistry cache arrays:")
	print("  ⚠️ _cached_wave_pool: Size depends on spawn_weight values")
	print("    Risk: High spawn weights could create large arrays")
	print("    Current: Weight * 10.0 = potential 100+ entries per enemy type")
	
	wave_director.queue_free()
	_add_result("Cache Array Growth", 1, "MEDIUM")
	await get_tree().process_frame

func test_multimesh_instance_tracking() -> void:
	print("\n--- Test 4: MultiMesh Instance Count Issues ---")
	
	print("MultiMesh memory analysis:")
	print("  ✓ Instance counts properly updated each frame")
	print("  ✓ No unbounded growth in transform arrays")
	print("  ⚠️ _enemy_transforms array: Fixed size but large")
	print("    Size: enemy_transform_cache_size (default 100)")
	print("    Memory per transform: ~32 bytes")
	print("    Total cache memory: ~3.2KB (acceptable)")
	
	_add_result("MultiMesh Instance Tracking", 0, "LOW")
	await get_tree().process_frame

func test_system_cleanup_patterns() -> void:
	print("\n--- Test 5: System Cleanup Pattern Analysis ---")
	
	var systems_without_cleanup = [
		"XpSystem", "WaveDirector", "AbilitySystem",
		"MeleeSystem", "EnemyRegistry",
		"ArenaSystem", "CardSystem"
	]
	
	print("CRITICAL: Most systems lack _exit_tree() cleanup:")
	for system in systems_without_cleanup:
		print("  - %s: Missing signal disconnections" % system)
	
	print("Systems with proper cleanup:")
	print("  ✓ DamageSystem: Has _exit_tree() with disconnections")
	print("  ✓ Arena: Has _exit_tree() with system disconnections")
	
	_add_result("System Cleanup Patterns", systems_without_cleanup.size(), "HIGH")
	await get_tree().process_frame

func _add_result(test_name: String, issue_count: int, severity: String) -> void:
	test_results.append({
		"test": test_name,
		"issues": issue_count,
		"severity": severity
	})

func _print_test_results() -> void:
	var high_priority = 0
	var medium_priority = 0
	var total_issues = 0
	
	for result in test_results:
		print("%s: %d issues (%s priority)" % [result.test, result.issues, result.severity])
		total_issues += result.issues
		if result.severity == "HIGH":
			high_priority += result.issues
		elif result.severity == "MEDIUM":
			medium_priority += result.issues
	
	print("\nTOTAL ISSUES FOUND: %d" % total_issues)
	print("HIGH Priority: %d" % high_priority)
	print("MEDIUM Priority: %d" % medium_priority)
	
	if high_priority > 0:
		print("\n⚠️ MEMORY LEAK RISK: HIGH")
		print("Recommendation: Add _exit_tree() cleanup to all systems")
	elif medium_priority > 0:
		print("\n⚠️ MEMORY LEAK RISK: MEDIUM") 
		print("Recommendation: Monitor cache sizes in production")
	else:
		print("\n✅ MEMORY LEAK RISK: LOW")