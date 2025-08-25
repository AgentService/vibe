extends RefCounted

## Monte-Carlo DPS/TTK simulation for balance validation.
## Runs headless combat simulations using game's actual balance data and RNG streams.
## Provides statistical baseline for balance changes and regression detection.

class_name BalanceSims

const COMBAT_DT := 1.0 / 30.0  # Match real game's fixed timestep
const DEFAULT_TRIALS := 10000
const DEFAULT_SEED := 12345

# Simulation results structure
class SimResult:
	var dps_mean: float
	var dps_p50: float 
	var dps_p95: float
	var ttk_mean: float
	var ttk_p50: float
	var ttk_p95: float
	var outliers: int
	var total_trials: int

static func run_baseline_simulation(trials: int = DEFAULT_TRIALS, seed_value: int = DEFAULT_SEED) -> SimResult:
	print("=== Monte-Carlo DPS/TTK Baseline Simulation ===")
	print("Trials: %d | Seed: %d" % [trials, seed_value])
	
	var results: Array[float] = []  # DPS values
	var ttk_results: Array[float] = []  # Time-to-kill values
	
	# Initialize RNG with seed for reproducible results
	var rng_service: RngService
	if Engine.has_singleton("RNG"):
		rng_service = Engine.get_singleton("RNG")
	else:
		# Fallback: create instance manually for headless mode
		rng_service = load("res://autoload/RNG.gd").new()
	rng_service.seed_run(seed_value)
	
	# Load balance data (same as real game)
	var balance_db: Node
	if Engine.has_singleton("BalanceDB"):
		balance_db = Engine.get_singleton("BalanceDB")
	else:
		# Fallback: create instance manually for headless mode
		balance_db = load("res://autoload/BalanceDB.gd").new()
		balance_db._setup_fallback_data()
		balance_db.load_all_balance_data()
	
	print("Starting simulation...")
	var start_time: int = int(Time.get_unix_time_from_system())
	
	for trial in range(trials):
		var trial_result: Dictionary = _simulate_encounter(rng_service, balance_db, trial)
		results.append(trial_result.dps)
		ttk_results.append(trial_result.ttk)
		
		if trial % int(trials / 10.0) == 0:
			print("Progress: %d%%" % (trial * 100 / trials))
	
	var end_time: int = int(Time.get_unix_time_from_system())
	print("Simulation completed in %d seconds" % (end_time - start_time))
	
	return _calculate_statistics(results, ttk_results, trials)

static func _simulate_encounter(rng: RngService, balance: Node, trial_id: int) -> Dictionary:
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
	
	while enemy_alive and time_elapsed < max_time:
		time_elapsed += COMBAT_DT
		fire_timer += COMBAT_DT
		
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
			
			proj.pos += proj.vel * COMBAT_DT
			proj.ttl -= COMBAT_DT
			
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
			enemy_pos += direction * enemy_speed * COMBAT_DT
	
	# Calculate results
	var dps: float = total_damage / time_elapsed if time_elapsed > 0.0 else 0.0
	var ttk: float = time_elapsed if not enemy_alive else max_time
	
	return {
		"dps": dps,
		"ttk": ttk,
		"total_damage": total_damage,
		"enemy_killed": not enemy_alive
	}

static func _calculate_statistics(dps_data: Array[float], ttk_data: Array[float], trials: int) -> SimResult:
	# Sort data for percentile calculations
	dps_data.sort()
	ttk_data.sort()
	
	var result: SimResult = SimResult.new()
	result.total_trials = trials
	
	# Calculate means
	var dps_sum: float = 0.0
	var ttk_sum: float = 0.0
	for i in range(trials):
		dps_sum += dps_data[i]
		ttk_sum += ttk_data[i]
	
	result.dps_mean = dps_sum / trials
	result.ttk_mean = ttk_sum / trials
	
	# Calculate percentiles
	var p50_idx: int = trials // 2
	var p95_idx: int = int(trials * 0.95)
	
	result.dps_p50 = dps_data[p50_idx]
	result.dps_p95 = dps_data[p95_idx]
	result.ttk_p50 = ttk_data[p50_idx]
	result.ttk_p95 = ttk_data[p95_idx]
	
	# Count outliers (3 standard deviations)
	var dps_variance: float = 0.0
	for dps in dps_data:
		dps_variance += pow(dps - result.dps_mean, 2)
	var dps_stddev: float = sqrt(dps_variance / trials)
	var dps_threshold: float = 3.0 * dps_stddev
	
	result.outliers = 0
	for dps in dps_data:
		if abs(dps - result.dps_mean) > dps_threshold:
			result.outliers += 1
	
	_print_results(result)
	_write_results_to_json(result)
	return result

static func _print_results(result: SimResult) -> void:
	print("\n=== SIMULATION RESULTS ===")
	print("DPS Statistics:")
	print("  Mean: %.2f" % result.dps_mean)
	print("  P50:  %.2f" % result.dps_p50)
	print("  P95:  %.2f" % result.dps_p95)
	print("\nTTK Statistics:")
	print("  Mean: %.2f seconds" % result.ttk_mean)
	print("  P50:  %.2f seconds" % result.ttk_p50)
	print("  P95:  %.2f seconds" % result.ttk_p95)
	print("\nOutliers: %d (%.1f%%)" % [result.outliers, result.outliers * 100.0 / result.total_trials])
	print("=========================\n")

static func _write_results_to_json(result: SimResult) -> void:
	var json_data: Dictionary = {
		"dps": {
			"mean": result.dps_mean,
			"p50": result.dps_p50,
			"p95": result.dps_p95
		},
		"ttk": {
			"mean": result.ttk_mean,
			"p50": result.ttk_p50,
			"p95": result.ttk_p95
		},
		"outliers": {
			"count": result.outliers,
			"pct": result.outliers * 100.0 / result.total_trials
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

# Static function to run from command line or other scripts
static func run_from_command_line() -> void:
	var result: SimResult = run_baseline_simulation()
	# CI-friendly output format
	print("CI_METRICS: DPS_MEAN=%.2f TTK_MEAN=%.2f OUTLIERS=%d TRIALS=%d" % [
		result.dps_mean, result.ttk_mean, result.outliers, result.total_trials
	])
