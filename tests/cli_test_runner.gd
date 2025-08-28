extends SceneTree

## Command-line test runner that can be executed directly by Godot.
## Usage: godot --headless --script tests/cli_test_runner.gd

func _init() -> void:
	print("=== CLI Test Runner ===")
	print("Starting tests in headless mode...")
	
	# Run tests
	run_tests()
	
	# Exit after tests complete
	quit()

func run_tests() -> void:
	print("\n=== RNG Stream Determinism Test ===")
	
	var test_seed := 12345
	var stream_names := ["crit", "loot", "waves", "ai", "craft"]
	
	# First run
	print("\nFirst run (seed: %d):" % test_seed)
	var first_results := generate_sequence(test_seed, stream_names)
	
	# Second run with same seed
	print("\nSecond run (seed: %d):" % test_seed)
	var second_results := generate_sequence(test_seed, stream_names)
	
	# Verify they match
	var all_match := true
	for stream_name in stream_names:
		if not arrays_match(first_results[stream_name], second_results[stream_name]):
			print("ERROR: Stream '%s' produced different results!" % stream_name)
			all_match = false
	
	if all_match:
		print("\n✓ SUCCESS: All streams produced identical sequences")
	else:
		print("\n✗ FAILURE: Some streams were non-deterministic")
	
	# Test different seed produces different results
	print("\nThird run (seed: %d):" % (test_seed + 1))
	var third_results := generate_sequence(test_seed + 1, stream_names)
	
	var any_differ := false
	for stream_name in stream_names:
		if not arrays_match(first_results[stream_name], third_results[stream_name]):
			any_differ = true
			break
	
	if any_differ:
		print("✓ SUCCESS: Different seed produced different results")
	else:
		print("✗ FAILURE: Different seed produced identical results")
	
	print("\n=== Monte-Carlo DPS/TTK Baseline Simulation ===")
	print("Trials: 1000 | Seed: 42")
	
	# Run a smaller simulation for CLI testing
	run_baseline_simulation(1000, 42)

func generate_sequence(seed_value: int, stream_names: Array) -> Dictionary:
	var results := {}
	
	# Create fresh RNG instance for testing
	var rng_node = load("res://autoload/RNG.gd").new()
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

func arrays_match(a: Array, b: Array) -> bool:
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

func run_baseline_simulation(trials: int, seed_value: int) -> void:
	var results: Array[float] = []  # DPS values
	var ttk_results: Array[float] = []  # Time-to-kill values
	
	# Initialize RNG with seed for reproducible results
	var rng_service = load("res://autoload/RNG.gd").new()
	rng_service.seed_run(seed_value)
	
	# Load balance data (same as real game)
	var balance_db = load("res://autoload/BalanceDB.gd").new()
	balance_db._setup_fallback_data()
	balance_db.load_all_balance_data()
	
	print("Starting simulation...")
	var start_time := Time.get_unix_time_from_system()
	
	for trial in range(trials):
		var trial_result = simulate_encounter(rng_service, balance_db, trial)
		results.append(trial_result.dps)
		ttk_results.append(trial_result.ttk)
		
		if trial % int(trials / 10.0) == 0:
			print("Progress: %d%%" % (trial * 100 / trials))
	
	var end_time := Time.get_unix_time_from_system()
	print("Simulation completed in %d seconds" % (end_time - start_time))
	
	calculate_and_print_statistics(results, ttk_results, trials)

func simulate_encounter(rng: Node, balance: Node, trial_id: int) -> Dictionary:
	# Get balance values
	var projectile_radius: float = balance.get_combat_value("projectile_radius")
	var enemy_radius: float = balance.get_combat_value("enemy_radius") 
	var base_damage: float = balance.get_combat_value("base_damage")
	var crit_chance: float = balance.get_combat_value("crit_chance")
	var crit_multiplier: float = balance.get_combat_value("crit_multiplier")
	
	var projectile_speed: float = balance.get_abilities_value("projectile_speed")
	var projectile_ttl: float = balance.get_abilities_value("projectile_ttl")
	
	var enemy_hp: float = balance.get_waves_value("enemy_hp")
	var enemy_speed: float = balance.get_waves_value("enemy_speed_min")  # Use min for consistency
	
	# Player stats (apply card bonuses)
	var projectile_count: int = 1 + balance.get_player_value("projectile_count_add")
	var fire_rate_mult: float = balance.get_player_value("fire_rate_mult")
	var damage_mult: float = balance.get_player_value("damage_mult")
	
	# Simulation state
	var enemy_pos: Vector2 = Vector2(200, 0)  # Start enemy at distance
	var player_pos: Vector2 = Vector2.ZERO
	var enemy_alive: bool = true
	var total_damage: float = 0.0
	var time_elapsed: float = 0.0
	var fire_timer: float = 0.0
	var projectiles: Array[Dictionary] = []
	
	var base_fire_rate: float = 2.0  # shots per second
	var fire_interval: float = 1.0 / (base_fire_rate * fire_rate_mult)
	
	# Simulate until enemy dies or timeout (prevent infinite loops)
	var max_time: float = 30.0  # 30 seconds max
	var combat_dt: float = 1.0 / 30.0  # Match real game's fixed timestep
	
	while enemy_alive and time_elapsed < max_time:
		time_elapsed += combat_dt
		fire_timer += combat_dt
		
		# Fire projectiles
		if fire_timer >= fire_interval:
			fire_timer = 0.0
			for i in range(projectile_count):
				var direction: Vector2 = (enemy_pos - player_pos).normalized()
				if i > 0:
					# Spread multiple projectiles slightly
					var angle_offset: float = (i - projectile_count/2.0) * 0.1
					direction = direction.rotated(angle_offset)
				
				projectiles.append({
					"pos": player_pos,
					"vel": direction * projectile_speed,
					"ttl": projectile_ttl,
					"alive": true
				})
		
		# Update projectiles
		for proj in projectiles:
			if not proj.alive:
				continue
			
			proj.pos += proj.vel * combat_dt
			proj.ttl -= combat_dt
			
			if proj.ttl <= 0.0:
				proj.alive = false
				continue
			
			# Check collision with enemy
			var distance: float = proj.pos.distance_to(enemy_pos)
			var collision_distance: float = projectile_radius + enemy_radius
			
			if distance <= collision_distance:
				# Hit! Calculate damage
				var is_crit: bool = rng.randf("crit") < crit_chance
				var damage: float = base_damage * damage_mult
				if is_crit:
					damage *= crit_multiplier
				
				total_damage += damage
				enemy_hp -= damage
				proj.alive = false
				
				if enemy_hp <= 0.0:
					enemy_alive = false
					break
		
		# Move enemy toward player (simplified AI)
		if enemy_alive:
			var direction: Vector2 = (player_pos - enemy_pos).normalized()
			enemy_pos += direction * enemy_speed * combat_dt
	
	# Calculate results
	var dps: float = total_damage / time_elapsed if time_elapsed > 0.0 else 0.0
	var ttk: float = time_elapsed if not enemy_alive else max_time
	
	return {
		"dps": dps,
		"ttk": ttk,
		"total_damage": total_damage,
		"enemy_killed": not enemy_alive
	}

func calculate_and_print_statistics(dps_data: Array[float], ttk_data: Array[float], trials: int) -> void:
	# Sort data for percentile calculations
	dps_data.sort()
	ttk_data.sort()
	
	# Calculate means
	var dps_sum: float = 0.0
	var ttk_sum: float = 0.0
	for i in range(trials):
		dps_sum += dps_data[i]
		ttk_sum += ttk_data[i]
	
	var dps_mean: float = dps_sum / trials
	var ttk_mean: float = ttk_sum / trials
	
	# Calculate percentiles
	var p50_idx: int = trials / 2
	var p95_idx: int = int(trials * 0.95)
	
	var dps_p50: float = dps_data[p50_idx]
	var dps_p95: float = dps_data[p95_idx]
	var ttk_p50: float = ttk_data[p50_idx]
	var ttk_p95: float = ttk_data[p95_idx]
	
	# Count outliers (3 standard deviations)
	var dps_variance: float = 0.0
	for dps in dps_data:
		dps_variance += pow(dps - dps_mean, 2)
	var dps_stddev: float = sqrt(dps_variance / trials)
	var dps_threshold: float = 3.0 * dps_stddev
	
	var outliers: int = 0
	for dps in dps_data:
		if abs(dps - dps_mean) > dps_threshold:
			outliers += 1
	
	print("\n=== SIMULATION RESULTS ===")
	print("DPS Statistics:")
	print("  Mean: %.2f" % dps_mean)
	print("  P50:  %.2f" % dps_p50)
	print("  P95:  %.2f" % dps_p95)
	print("\nTTK Statistics:")
	print("  Mean: %.2f seconds" % ttk_mean)
	print("  P50:  %.2f seconds" % ttk_p50)
	print("  P95:  %.2f seconds" % ttk_p95)
	print("\nOutliers: %d (%.1f%%)" % [outliers, outliers * 100.0 / trials])
	print("=========================\n")
	
	# Write results to JSON
	write_results_to_json(dps_mean, dps_p50, dps_p95, ttk_mean, ttk_p50, ttk_p95, outliers, trials)

func write_results_to_json(dps_mean: float, dps_p50: float, dps_p95: float, 
						  ttk_mean: float, ttk_p50: float, ttk_p95: float, 
						  outliers: int, trials: int) -> void:
	var json_data: Dictionary = {
		"dps": {
			"mean": dps_mean,
			"p50": dps_p50,
			"p95": dps_p95
		},
		"ttk": {
			"mean": ttk_mean,
			"p50": ttk_p50,
			"p95": ttk_p95
		},
		"outliers": {
			"count": outliers,
			"pct": outliers * 100.0 / trials
		}
	}
	
	var json_string: String = JSON.stringify(json_data)
	var file_path: String = "res://tests/results/baseline.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("Results written to %s" % file_path)
	else:
		print("ERROR: Could not write to %s" % file_path)
