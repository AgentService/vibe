extends SceneTree

## Performance benchmark comparing current Logger vs Limbo Console logging performance
## Simulates high-frequency logging scenarios typical in the 30Hz combat loop

func _initialize():
	print("=== CONSOLE LOGGING PERFORMANCE BENCHMARK ===")
	
	# Wait a frame to ensure autoloads are ready
	await process_frame
	
	run_logging_benchmarks()
	quit()

func run_logging_benchmarks():
	var iterations = 10000  # Simulate high-frequency logging
	var combat_steps = 1000  # 30Hz for ~33 seconds of combat
	
	print("\nBenchmark Configuration:")
	print("- Iterations per test: ", iterations)
	print("- Combat simulation: ", combat_steps, " steps (~33s at 30Hz)")
	print("- Testing memory allocation and string processing overhead")
	
	# Test 1: Current Logger System Performance
	print("\n1. Current Logger System (Simple)")
	var logger_times = benchmark_current_logger(iterations)
	
	# Test 2: Limbo Console System Performance  
	print("\n2. Limbo Console System")
	var limbo_times = benchmark_limbo_console(iterations)
	
	# Test 3: Combat Step Simulation with Logger
	print("\n3. Combat Simulation - Current Logger")
	var combat_logger_times = benchmark_combat_simulation_logger(combat_steps)
	
	# Test 4: Combat Step Simulation with Limbo Console
	print("\n4. Combat Simulation - Limbo Console")
	var combat_limbo_times = benchmark_combat_simulation_limbo(combat_steps)
	
	# Test 5: Memory allocation stress test
	print("\n5. Memory Stress Test")
	benchmark_memory_usage()
	
	# Results Summary
	print_results_summary(logger_times, limbo_times, combat_logger_times, combat_limbo_times)

func benchmark_current_logger(iterations: int) -> Dictionary:
	var start_time = Time.get_time_dict_from_system()
	var start_msec = Time.get_unix_time_from_system() * 1000
	
	# Test different log levels and categories
	for i in range(iterations):
		Logger.debug("Combat step %d: Projectile collision check" % i, "combat")
		Logger.info("Enemy spawned at position %s" % Vector2(i, i*2), "waves")
		Logger.warn("Pool utilization at 80%% - index %d" % i, "performance")
		
		# Simulate conditional debug logging (common pattern)
		if Logger.is_debug() and i % 100 == 0:
			Logger.debug("Periodic debug: Frame %d stats" % i, "debug")
	
	var end_msec = Time.get_unix_time_from_system() * 1000
	var duration = end_msec - start_msec
	
	print("  Duration: %.2f ms" % duration)
	print("  Avg per log: %.4f ms" % (duration / (iterations * 3.5))) # 3.5 logs per iteration avg
	
	return {"duration": duration, "iterations": iterations}

func benchmark_limbo_console(iterations: int) -> Dictionary:
	if not LimboConsole:
		print("  ERROR: LimboConsole not available")
		return {"duration": 0, "iterations": 0}
	
	var start_msec = Time.get_unix_time_from_system() * 1000
	
	# Test Limbo Console logging methods
	for i in range(iterations):
		LimboConsole.debug("Combat step %d: Projectile collision check" % i)
		LimboConsole.info("Enemy spawned at position %s" % Vector2(i, i*2))
		LimboConsole.warn("Pool utilization at 80%% - index %d" % i)
		
		# Test command execution performance (less frequent)
		if i % 1000 == 0:
			LimboConsole.execute_command("help", true)  # Silent execution
	
	var end_msec = Time.get_unix_time_from_system() * 1000
	var duration = end_msec - start_msec
	
	print("  Duration: %.2f ms" % duration)
	print("  Avg per log: %.4f ms" % (duration / (iterations * 3.001))) # 3.001 logs per iteration avg
	
	return {"duration": duration, "iterations": iterations}

func benchmark_combat_simulation_logger(combat_steps: int) -> Dictionary:
	print("  Simulating 30Hz combat with current Logger...")
	
	var start_msec = Time.get_unix_time_from_system() * 1000
	var projectile_count = 50
	var enemy_count = 100
	
	for step in range(combat_steps):
		# Simulate DamageSystem._on_combat_step logging
		for p in range(projectile_count):
			for e in range(enemy_count):
				if RNG.randf() < 0.001:  # 0.1% collision rate
					Logger.debug("Collision detected: proj[%d] -> enemy[%d]" % [p, e], "combat")
				
				# Occasional warnings (pool exhaustion, etc.)
				if RNG.randf() < 0.0001:  # 0.01% warning rate
					Logger.warn("Pool indices mismatch: proj=%d enemy=%d" % [p, e], "combat")
		
		# Wave director logging
		if step % 30 == 0:  # Once per second at 30Hz
			Logger.info("Combat step %d: %d enemies alive" % [step, enemy_count], "waves")
	
	var end_msec = Time.get_unix_time_from_system() * 1000
	var duration = end_msec - start_msec
	
	print("  Duration: %.2f ms" % duration)
	print("  Avg per combat step: %.4f ms" % (duration / combat_steps))
	
	return {"duration": duration, "steps": combat_steps}

func benchmark_combat_simulation_limbo(combat_steps: int) -> Dictionary:
	if not LimboConsole:
		print("  ERROR: LimboConsole not available")
		return {"duration": 0, "steps": 0}
		
	print("  Simulating 30Hz combat with Limbo Console...")
	
	var start_msec = Time.get_unix_time_from_system() * 1000
	var projectile_count = 50
	var enemy_count = 100
	
	for step in range(combat_steps):
		# Simulate DamageSystem._on_combat_step logging
		for p in range(projectile_count):
			for e in range(enemy_count):
				if RNG.randf() < 0.001:  # 0.1% collision rate
					LimboConsole.debug("Collision detected: proj[%d] -> enemy[%d]" % [p, e])
				
				# Occasional warnings (pool exhaustion, etc.)
				if RNG.randf() < 0.0001:  # 0.01% warning rate
					LimboConsole.warn("Pool indices mismatch: proj=%d enemy=%d" % [p, e])
		
		# Wave director logging
		if step % 30 == 0:  # Once per second at 30Hz
			LimboConsole.info("Combat step %d: %d enemies alive" % [step, enemy_count])
	
	var end_msec = Time.get_unix_time_from_system() * 1000
	var duration = end_msec - start_msec
	
	print("  Duration: %.2f ms" % duration)
	print("  Avg per combat step: %.4f ms" % (duration / combat_steps))
	
	return {"duration": duration, "steps": combat_steps}

func benchmark_memory_usage():
	var initial_memory = Performance.get_monitor(Performance.MONITOR_TYPE_MEMORY, Performance.MEMORY_TYPE_STATIC)
	
	# Stress test: rapid string formatting and logging
	var large_iterations = 50000
	print("  Running memory stress test with %d iterations..." % large_iterations)
	
	var test_data = []
	for i in range(1000):
		test_data.append("Entity_%d_pos_%s_hp_%.2f" % [i, Vector2(i*10, i*20), randf() * 100])
	
	# Test 1: Current Logger
	var start_memory = Performance.get_monitor(Performance.MONITOR_TYPE_MEMORY, Performance.MEMORY_TYPE_STATIC)
	for i in range(large_iterations):
		Logger.debug(test_data[i % test_data.size()], "memory_test")
	var logger_memory = Performance.get_monitor(Performance.MONITOR_TYPE_MEMORY, Performance.MEMORY_TYPE_STATIC)
	
	# Force garbage collection
	for i in range(10):
		OS.delay_usec(1000)  # Small delay
	
	# Test 2: Limbo Console  
	var limbo_start_memory = Performance.get_monitor(Performance.MONITOR_TYPE_MEMORY, Performance.MEMORY_TYPE_STATIC)
	if LimboConsole:
		for i in range(large_iterations):
			LimboConsole.debug(test_data[i % test_data.size()])
	var limbo_memory = Performance.get_monitor(Performance.MONITOR_TYPE_MEMORY, Performance.MEMORY_TYPE_STATIC)
	
	print("  Logger Memory Delta: %.2f MB" % ((logger_memory - start_memory) / 1024.0 / 1024.0))
	if LimboConsole:
		print("  Limbo Console Memory Delta: %.2f MB" % ((limbo_memory - limbo_start_memory) / 1024.0 / 1024.0))

func print_results_summary(logger_times: Dictionary, limbo_times: Dictionary, combat_logger_times: Dictionary, combat_limbo_times: Dictionary):
	print("\n=== PERFORMANCE ANALYSIS SUMMARY ===")
	
	if logger_times.duration > 0 and limbo_times.duration > 0:
		var perf_ratio = limbo_times.duration / logger_times.duration
		print("\nBasic Logging Performance:")
		print("  Current Logger: %.2f ms" % logger_times.duration)
		print("  Limbo Console: %.2f ms" % limbo_times.duration)
		print("  Performance Ratio: %.2fx %s" % [perf_ratio, "SLOWER" if perf_ratio > 1 else "FASTER"])
	
	if combat_logger_times.duration > 0 and combat_limbo_times.duration > 0:
		var combat_ratio = combat_limbo_times.duration / combat_logger_times.duration
		print("\nCombat Simulation Performance:")
		print("  Current Logger: %.2f ms" % combat_logger_times.duration)  
		print("  Limbo Console: %.2f ms" % combat_limbo_times.duration)
		print("  Performance Ratio: %.2fx %s" % [combat_ratio, "SLOWER" if combat_ratio > 1 else "FASTER"])
	
	print("\n=== RELIABILITY & FEATURE ANALYSIS ===")
	print("\nCurrent Logger Strengths:")
	print("  + Lightweight, minimal overhead")
	print("  + Configurable log levels and categories")
	print("  + Hot-reload support for configuration")
	print("  + Deterministic behavior")
	print("  + No UI dependencies")
	
	print("\nLimbo Console Strengths:")
	print("  + Interactive command execution")
	print("  + Rich text formatting and theming")
	print("  + Command history and autocomplete")
	print("  + Integrated debugging interface")
	print("  + Extensible command system")
	
	print("\nLimbo Console Concerns:")
	print("  - Development status (breaking changes expected)")
	print("  - UI rendering overhead during gameplay")
	print("  - More complex codebase (higher risk of bugs)")
	print("  - Memory overhead from console UI")
	print("  - Input handling conflicts possible")
	
	print("\n=== RECOMMENDATIONS ===")
	print("For this project's 30Hz combat loop:")
	print("  1. Current Logger is optimized for performance-critical paths")
	print("  2. Limbo Console better for development/debugging features")  
	print("  3. Consider hybrid approach: Logger for core systems, Limbo for dev tools")
	print("  4. Monitor frame time impact if using Limbo during gameplay")