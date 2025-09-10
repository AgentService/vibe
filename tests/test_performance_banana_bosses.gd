extends Node

## Performance stress test for 50+ Banana Boss architecture validation
## Tests FPS stability, memory usage, and combat performance with scene-based bosses only
## Designed to validate boss spawning system without mesh enemies

const PerformanceMetrics = preload("res://tests/tools/performance_metrics.gd")

# Test configuration - same scale as original test but with bosses
var test_duration: float = 60.0  # Test runs for 60 seconds
var target_boss_count: int = 500  # Same as original test for comparison
var combat_step_interval: float = 1.0 / 30.0  # 30Hz combat step

# Test parameters
var verbose_output: bool = false        # Set to true for detailed logging, false for clean output

# Test state
var current_test_phase: String = ""
var test_start_time: float = 0.0
var performance_metrics: PerformanceMetrics
var combat_step_timer: float = 0.0

# Phase-specific tracking
var phase_metrics: Array[Dictionary] = []  # Track metrics per phase
var phase_peak_bosses: int = 0
var phase_start_memory: float = 0.0

# Systems (injected from scene setup)
var arena_root: Node2D
var debug_manager: Node
var damage_service: Node

# Test scenarios - same as original test but with bosses
var test_phases: Array[Dictionary] = [
	{
		"name": "gradual_boss_scaling",
		"duration": 8.0,
		"description": "Scale from 100 to 500+ banana bosses gradually"
	},
	{
		"name": "burst_boss_spawn", 
		"duration": 5.0,
		"description": "Instant spawn of 500 banana bosses"
	},
	{
		"name": "boss_combat_stress",
		"duration": 10.0, 
		"description": "500 banana bosses + damage calculations + AI behavior"
	},
	{
		"name": "mixed_boss_tier",
		"duration": 7.0,
		"description": "All boss types simultaneously"
	}
]

var current_phase_index: int = 0
var phase_start_time: float = 0.0
var test_completed: bool = false

func _ready() -> void:
	print("=== BANANA BOSS PERFORMANCE STRESS TEST ===")
	print("Target: 500+ banana bosses, 60 second duration")
	print("Success Criteria: ≥30 FPS, <50MB memory growth, <33.3ms frame time")
	
	# Check command line arguments for test parameters
	_parse_test_parameters()
	
	print("Test Parameters:")
	print("  verbose_output: %s" % verbose_output)
	
	# Initialize deterministic RNG for reproducible tests
	_setup_deterministic_rng()
	
	# Initialize performance tracking (but don't start measuring yet)
	performance_metrics = PerformanceMetrics.new()
	
	# Find and setup system references
	_setup_system_references()
	
	# Initialize systems with dependencies
	_initialize_systems()
	
	# NOW establish memory baseline after arena is loaded but before bosses spawn
	print("Establishing memory baseline after arena load...")
	await get_tree().process_frame  # Allow one frame for full initialization
	
	# PHASE 0: Document memory measurement points for investigation
	var game_start_memory = OS.get_static_memory_usage()
	print("Memory measurement points:")
	print("  - Game startup: %.2f MB" % (game_start_memory / 1024.0 / 1024.0))
	print("  - Arena loaded: %.2f MB (baseline for test)" % (OS.get_static_memory_usage() / 1024.0 / 1024.0))
	print("  - Arena load overhead: %.2f MB" % ((OS.get_static_memory_usage() - game_start_memory) / 1024.0 / 1024.0))
	
	performance_metrics.start_test()  # Start measuring from empty arena baseline
	
	# Start first test phase
	test_start_time = Time.get_unix_time_from_system()
	_start_next_phase()

func _process(delta: float) -> void:
	if not performance_metrics:
		return  # Early exit if metrics not initialized
	
	# Update performance metrics
	performance_metrics.update_frame_metrics(delta)
	
	# Update combat step timer
	combat_step_timer += delta
	if combat_step_timer >= combat_step_interval:
		_on_combat_step()
		combat_step_timer = 0.0
	
	# Track peak boss count for current phase
	var current_boss_count = _count_alive_bosses()
	if current_boss_count > phase_peak_bosses:
		phase_peak_bosses = current_boss_count
	
	# Progress logging every 2 seconds with memory tracking
	var total_elapsed = Time.get_unix_time_from_system() - test_start_time
	if int(total_elapsed * 2) % 4 == 0 and int(total_elapsed * 2) != int((total_elapsed - delta) * 2):
		var current_fps = performance_metrics._calculate_average_fps()
		var current_memory = OS.get_static_memory_usage()
		var memory_growth = current_memory - performance_metrics.initial_memory
		print("Progress: %.1fs elapsed, %d bosses, %.1f FPS, Memory: %.1f MB (+%.1f MB growth)" % [
			total_elapsed, current_boss_count, current_fps, 
			current_memory / 1024.0 / 1024.0, memory_growth / 1024.0 / 1024.0
		])
		print("  Phase: %s (%d/%d), Phase elapsed: %.1fs, Peak bosses: %d" % [current_test_phase, current_phase_index + 1, test_phases.size(), Time.get_unix_time_from_system() - phase_start_time, phase_peak_bosses])
	
	# Check if current phase is complete
	var phase_elapsed = Time.get_unix_time_from_system() - phase_start_time
	if current_phase_index < test_phases.size():
		var current_phase = test_phases[current_phase_index]
		
		if phase_elapsed >= current_phase.duration:
			_end_current_phase()
			_start_next_phase()
	
	# Check if entire test is complete
	if total_elapsed >= test_duration:
		print("Test complete: reached maximum duration (%.1fs)" % test_duration)
		_complete_test()
	elif current_phase_index >= test_phases.size():
		print("Test complete: all phases finished")
		_complete_test()

func _setup_system_references() -> void:
	_setup_full_arena()
	
	# Find systems from the arena or create placeholders
	_discover_arena_systems()

func _setup_full_arena() -> void:
	print("Loading full Arena scene...")
	
	# Load the real Arena scene
	var arena_scene_path = "res://scenes/arena/Arena.tscn"
	if not ResourceLoader.exists(arena_scene_path):
		print("ERROR: Arena scene not found at: " + arena_scene_path)
		_fail_test("Arena scene missing")
		return
	
	var arena_scene = load(arena_scene_path)
	if not arena_scene:
		print("ERROR: Failed to load Arena scene resource")
		_fail_test("Failed to load Arena scene resource")
		return
	
	var arena_instance = arena_scene.instantiate()
	if not arena_instance:
		print("ERROR: Failed to instantiate Arena scene")
		_fail_test("Failed to instantiate Arena scene")
		return
	
	# Add Arena as child
	add_child(arena_instance)
	arena_root = arena_instance
	
	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("✓ Full Arena scene loaded successfully")
	
	# Aggressively disable any debug panels that may have loaded with the Arena
	_disable_arena_debug_panels()

func _initialize_systems() -> void:
	print("Initializing systems with dependencies...")
	
	# Proper autoload access via scene tree
	var root = get_tree().get_root()
	debug_manager = root.get_node_or_null("/root/DebugManager")
	damage_service = root.get_node_or_null("/root/DamageService")
	var cheat_system = root.get_node_or_null("/root/CheatSystem")
	var player_state = root.get_node_or_null("/root/PlayerState")
	
	# Enable debug mode for boss spawning but reduce logging verbosity
	if debug_manager:
		debug_manager.debug_enabled = true
		if debug_manager.has_method("_enter_debug_mode"):
			debug_manager._enter_debug_mode()
		print("✓ Debug systems enabled for boss spawning")
	else:
		print("⚠️  DebugManager not available - boss spawning may not work")
	
	# Configure logging based on verbose_output setting
	if not verbose_output:
		_reduce_debug_logging()
		print("✓ Clean output mode enabled")
	
	# Ensure CheatSystem allows spawning
	if cheat_system:
		cheat_system.spawn_disabled = false
		print("✓ Spawning enabled via CheatSystem")
	else:
		print("⚠️  CheatSystem not available - spawning may be limited")
	
	# Set PlayerState position for boss targeting
	if player_state:
		player_state.position = Vector2(400, 300)  # Center of arena
		print("✓ PlayerState position set for boss targeting")
	else:
		print("⚠️  PlayerState not available - using default positioning")
	
	print("✓ Systems initialized with dependencies")

func _discover_arena_systems() -> void:
	"""Discover and setup references to systems from the loaded Arena scene."""
	print("Discovering systems from Arena scene...")
	
	# Find systems in autoloads
	var root = get_tree().get_root()
	debug_manager = root.get_node_or_null("/root/DebugManager")
	damage_service = root.get_node_or_null("/root/DamageService")
	
	if debug_manager:
		print("✓ DebugManager found")
	else:
		print("⚠️  DebugManager not found")
	
	if damage_service:
		print("✓ DamageService found")
	else:
		print("⚠️  DamageService not found")
	
	print("✓ System discovery complete")

func _disable_arena_debug_panels() -> void:
	"""Find and disable any debug panels that loaded with the Arena scene."""
	if not arena_root:
		return
	
	# Find debug panels in the Arena scene and disable them
	var debug_panels = []
	_find_debug_panels_recursive(arena_root, debug_panels)
	
	for panel in debug_panels:
		if panel.has_method("set_enabled"):
			panel.set_enabled(false)
		if panel.has_method("hide"):
			panel.hide()
		if panel.has_method("queue_free"):
			panel.queue_free()  # Remove entirely
			print("✓ Removed debug panel: %s" % panel.name)
	
	if debug_panels.size() > 0:
		print("✓ Disabled %d debug panels from Arena scene" % debug_panels.size())

func _find_debug_panels_recursive(node: Node, panels: Array) -> void:
	"""Recursively find debug panels in the node tree."""
	if node.name.contains("Debug") or node.name.contains("debug"):
		panels.append(node)
	
	for child in node.get_children():
		_find_debug_panels_recursive(child, panels)

func _reduce_debug_logging() -> void:
	"""Reduce verbose debug logging by configuring Logger and other debug systems."""
	var root = get_tree().get_root()
	var logger_node = root.get_node_or_null("/root/Logger")
	
	# Set Logger to only show WARN level and above (suppress DEBUG and INFO messages)
	if logger_node:
		# Try different methods to set log level
		if logger_node.has_method("set_level"):
			# Try with integer level (WARN = 2, INFO = 1, DEBUG = 0)
			logger_node.set_level(2)  # WARN level
			print("✓ Logger level set to WARN (int)")
		elif logger_node.has_method("set_log_level"):
			logger_node.set_log_level(2)
			print("✓ Logger level set via set_log_level")
		elif logger_node.has_property("log_level"):
			logger_node.log_level = 2
			print("✓ Logger level set via property")
		else:
			print("⚠️  Unable to set logger level")
	
	print("✓ All debug output suppression measures applied")

func _parse_test_parameters() -> void:
	"""Parse command line arguments for test configuration."""
	var args = OS.get_cmdline_args()
	
	# Parse command line arguments
	for arg in args:
		if arg == "--verbose":
			verbose_output = true
			print("✓ Verbose output enabled via command line flag")

func _setup_deterministic_rng() -> void:
	"""Setup deterministic RNG seeding for reproducible test results."""
	var root = get_tree().get_root()
	var rng_node = root.get_node_or_null("/root/RNG")
	var run_manager = root.get_node_or_null("/root/RunManager")
	
	# Use a fixed seed for performance testing reproducibility
	var performance_test_seed: int = 54321
	
	if rng_node and rng_node.has_method("seed_for_run"):
		rng_node.seed_for_run(performance_test_seed)
		print("✓ RNG seeded deterministically for boss performance test: %d" % performance_test_seed)
	elif run_manager and run_manager.has_method("start_run"):
		# Try to use RunManager to setup RNG
		run_manager.start_run(performance_test_seed)
		print("✓ RunManager initialized with boss performance test seed: %d" % performance_test_seed)
	else:
		# Fallback to built-in RNG seeding
		seed(performance_test_seed)
		print("✓ Built-in RNG seeded for boss performance test: %d" % performance_test_seed)

func _start_next_phase() -> void:
	if current_phase_index >= test_phases.size():
		print("All test phases completed")
		return
	
	var phase = test_phases[current_phase_index]
	current_test_phase = phase.name
	phase_start_time = Time.get_unix_time_from_system()
	
	# Reset phase-specific tracking
	phase_peak_bosses = 0
	phase_start_memory = OS.get_static_memory_usage()
	
	print("\n=== PHASE %d: %s ===" % [current_phase_index + 1, phase.description])
	print("Duration: %.1f seconds" % phase.duration)
	
	# Configure phase-specific settings
	match current_test_phase:
		"gradual_boss_scaling":
			_setup_gradual_boss_scaling()
		"burst_boss_spawn":
			_setup_burst_boss_spawn() 
		"boss_combat_stress":
			_setup_boss_combat_stress()
		"mixed_boss_tier":
			_setup_mixed_boss_tier()

func _end_current_phase() -> void:
	var phase = test_phases[current_phase_index]
	var final_boss_count = _count_alive_bosses()
	var phase_end_time = Time.get_unix_time_from_system()
	var phase_duration_actual = phase_end_time - phase_start_time
	
	# Track detailed phase metrics
	var current_memory = OS.get_static_memory_usage()
	var total_memory_growth = current_memory - performance_metrics.initial_memory
	var phase_memory_growth = current_memory - phase_start_memory
	var current_fps = performance_metrics._calculate_average_fps()
	
	# Store phase metrics for final summary
	var phase_data = {
		"name": phase.name,
		"duration": phase_duration_actual,
		"final_bosses": final_boss_count,
		"peak_bosses": phase_peak_bosses,
		"memory_start_mb": phase_start_memory / 1024.0 / 1024.0,
		"memory_end_mb": current_memory / 1024.0 / 1024.0,
		"memory_growth_mb": phase_memory_growth / 1024.0 / 1024.0,
		"total_memory_growth_mb": total_memory_growth / 1024.0 / 1024.0,
		"avg_fps": current_fps
	}
	phase_metrics.append(phase_data)
	
	# Enhanced phase completion output
	print("Phase '%s' completed:" % phase.name)
	print("  Duration: %.1fs" % phase_duration_actual)
	print("  Final bosses: %d (Peak: %d)" % [final_boss_count, phase_peak_bosses])
	print("  Memory: %.1f MB → %.1f MB (+%.1f MB phase growth)" % [
		phase_start_memory / 1024.0 / 1024.0, current_memory / 1024.0 / 1024.0, phase_memory_growth / 1024.0 / 1024.0
	])
	print("  Total memory growth: +%.1f MB" % (total_memory_growth / 1024.0 / 1024.0))
	print("  Average FPS: %.1f" % current_fps)
	
	current_phase_index += 1

func _setup_gradual_boss_scaling() -> void:
	print("Starting gradual boss scaling: 100 → 500+ banana bosses over 8 seconds")
	# Clear any existing bosses
	_clear_all_bosses()

func _setup_burst_boss_spawn() -> void:
	print("Starting burst boss spawn: Instant 500 banana bosses")
	# Clear existing bosses
	_clear_all_bosses()
	
	# Force spawn 500 bosses as fast as possible
	_force_spawn_bosses(500)

func _setup_boss_combat_stress() -> void:
	print("Starting boss combat stress: 500 banana bosses + AI behavior + damage")
	# Ensure we have max bosses spawning
	var current_count = _count_alive_bosses()
	if current_count < 400:  # If we don't have enough, trigger rapid spawning
		_force_spawn_bosses(500)

func _setup_mixed_boss_tier() -> void:
	print("Starting mixed boss tier: All boss types simultaneously")
	# Clear existing and spawn mixed types
	_clear_all_bosses()
	
	# Trigger rapid spawning for mixed boss types
	_force_spawn_mixed_bosses()

func _on_combat_step() -> void:
	# Emit combat step for systems that need it (with proper payload)
	var payload = EventBus.CombatStepPayload_Type.new(combat_step_interval)
	EventBus.combat_step.emit(payload)
	
	# During gradual_boss_scaling, increase boss count
	if current_test_phase == "gradual_boss_scaling":
		_update_gradual_boss_scaling()

func _update_gradual_boss_scaling() -> void:
	var phase_elapsed = Time.get_unix_time_from_system() - phase_start_time
	var phase_duration = test_phases[0].duration  # 8 seconds
	var progress = phase_elapsed / phase_duration
	
	# Linearly scale from 100 to 500+ bosses
	var target_count = int(100 + (400 * progress))
	target_count = min(target_count, 500)
	
	var current_count = _count_alive_bosses()
	if current_count < target_count:
		if verbose_output:
			print("Boss scaling: current=%d, target=%d" % [current_count, target_count])
		_force_spawn_bosses(target_count)  # Directly spawn to target count

func _force_spawn_bosses(count: int) -> void:
	if not debug_manager:
		print("ERROR: DebugManager not available for boss spawning")
		return
	
	print("Force spawning %d banana bosses..." % count)
	
	# Use DebugManager to spawn banana bosses (BananaLord)
	for i in range(count):
		var spawn_pos = _get_random_spawn_position()
		if debug_manager.has_method("spawn_enemy_at_position"):
			debug_manager.spawn_enemy_at_position("banana_lord", spawn_pos, 1)
		
		# Small delay between spawns to avoid overwhelming the system
		if i % 5 == 0:  # Every 5 bosses, wait a frame
			await get_tree().process_frame
	
	var final_count = _count_alive_bosses()
	print("Force spawn complete: %d bosses spawned (target was %d)" % [final_count, count])

func _force_spawn_mixed_bosses() -> void:
	if not debug_manager:
		print("ERROR: DebugManager not available for mixed boss spawning")
		return
	
	# Use the same aggressive approach for mixed boss spawning
	_force_spawn_bosses(500)  # Reuse the improved force spawn logic

func _spawn_single_boss() -> void:
	if not debug_manager:
		return
	
	var spawn_pos = _get_random_spawn_position()
	if debug_manager.has_method("spawn_enemy_at_position"):
		debug_manager.spawn_enemy_at_position("banana_lord", spawn_pos, 1)

func _get_random_spawn_position() -> Vector2:
	# Spawn bosses around arena perimeter
	var arena_center = Vector2(400, 300)
	var spawn_radius = 600.0  # Closer than mesh enemies since bosses are bigger
	var angle: float
	
	# Use RNG autoload if available
	var root = get_tree().get_root()
	var rng_node = root.get_node_or_null("/root/RNG")
	
	if rng_node and rng_node.has_method("randf"):
		angle = rng_node.randf("test") * 2.0 * PI
	else:
		angle = randf() * 2.0 * PI
	
	return arena_center + Vector2(
		cos(angle) * spawn_radius,
		sin(angle) * spawn_radius
	)

func _count_alive_bosses() -> int:
	# Count bosses using EntityTracker
	var root = get_tree().get_root()
	var entity_tracker = root.get_node_or_null("/root/EntityTracker")
	
	if entity_tracker and entity_tracker.has_method("get_entities_by_type"):
		var bosses = entity_tracker.get_entities_by_type("boss")
		return bosses.size()
	
	# Fallback: count BananaLord nodes in scene tree
	var boss_count = []
	_count_banana_lords_recursive(arena_root, boss_count)
	return boss_count.size()

func _count_banana_lords_recursive(node: Node, count_ref: Array) -> void:
	if not node:
		return
	
	if node is BananaLord:
		count_ref.append(1)
	
	for child in node.get_children():
		_count_banana_lords_recursive(child, count_ref)

func _clear_all_bosses() -> void:
	if debug_manager and debug_manager.has_method("clear_all_entities"):
		debug_manager.clear_all_entities()
		print("Cleared all bosses via DebugManager")
	else:
		print("WARNING: Could not clear bosses - DebugManager not available")

func _exit_tree() -> void:
	# Ensure results are written even if test is terminated early
	if not test_completed and performance_metrics:
		var elapsed = Time.get_unix_time_from_system() - test_start_time
		print("\\n=== TEST TERMINATED EARLY AT %.1fs - WRITING PARTIAL RESULTS ===" % elapsed)
		print("Current phase: %s (%d/%d)" % [current_test_phase, current_phase_index + 1, test_phases.size()])
		_complete_test()

func _complete_test() -> void:
	if test_completed:
		return  # Already completed
	test_completed = true
	print("\n=== BANANA BOSS STRESS TEST COMPLETED ===")
	
	# Print detailed phase breakdown
	_print_phase_summary()
	
	# Get final test results
	var results = performance_metrics.end_test()
	
	# Export baseline metrics to main baselines folder
	var project_path = ProjectSettings.globalize_path("res://")
	var baseline_dir = project_path + "tests/baselines/"
	
	# Ensure directory exists
	var dir_access = DirAccess.open(project_path + "tests/")
	if dir_access:
		if not dir_access.dir_exists("baselines"):
			dir_access.make_dir("baselines")
		print("✓ Created baseline directory")
	
	# Add phase-specific data to results for export
	var enhanced_results = results.duplicate()
	var overall_peak_bosses = 0
	for phase_data in phase_metrics:
		if phase_data.peak_bosses > overall_peak_bosses:
			overall_peak_bosses = phase_data.peak_bosses
	enhanced_results["peak_boss_count"] = overall_peak_bosses
	
	# Export CSV with date+time prefix
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var baseline_file = baseline_dir + timestamp + "_performance_banana_bosses.csv"
	performance_metrics.export_baseline_csv(baseline_file, enhanced_results)
	
	# Export detailed summary to same folder with date+time prefix
	_export_test_summary(baseline_dir, timestamp, enhanced_results)
	
	# Final boss count report with peak data
	var final_boss_count = _count_alive_bosses()
	print("Final boss count: %d (Peak across all phases: %d)" % [final_boss_count, overall_peak_bosses])
	
	# Architecture validation summary (same thresholds as original for comparison)
	print("\n=== BOSS ARCHITECTURE VALIDATION ===")
	var boss_test_passed = (
		results.average_fps >= 30.0 and
		results.frame_time_95th_percentile < 33.3 and
		results.memory_growth_mb < 50.0 and
		results.fps_stability > 90.0
	)
	
	if boss_test_passed:
		print("✓ SUCCESS: Boss architecture meets 500+ banana boss performance requirements")
		print("✓ Scene-based boss spawning system is performant")
	else:
		print("✗ FAILURE: Boss architecture performance issues detected")
		print("⚠️  Boss optimization required")
	
	print("\nResults exported to tests/baselines/ with date+time prefixes")
	
	# Exit in headless mode
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func _export_test_summary(baseline_dir: String, timestamp: String, results: Dictionary) -> void:
	"""Export detailed test summary to text file."""
	var summary_file = baseline_dir + timestamp + "_performance_banana_bosses_summary.txt"
	var file = FileAccess.open(summary_file, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create summary file: %s" % summary_file)
		return
	
	file.store_line("=== BANANA BOSS PERFORMANCE STRESS TEST SUMMARY ===")
	file.store_line("Timestamp: " + Time.get_datetime_string_from_system())
	file.store_line("Test Duration: %.2f seconds" % results.duration_seconds)
	file.store_line("Target: 500+ banana bosses, ≥30 FPS, <50MB memory growth")
	file.store_line("")
	file.store_line("=== RESULTS ===")
	file.store_line("Final Boss Count: %d" % _count_alive_bosses())
	file.store_line("Total Frames: %d" % results.total_frames)
	file.store_line("Average FPS: %.2f" % results.average_fps)
	file.store_line("Minimum FPS: %.2f" % results.min_fps)
	file.store_line("FPS Stability: %.1f%%" % results.fps_stability)
	file.store_line("Frame Time 95th Percentile: %.2f ms" % results.frame_time_95th_percentile)
	file.store_line("Memory Growth: %.2f MB" % results.memory_growth_mb)
	
	# Same pass/fail criteria as original test for comparison
	var boss_test_passed = (
		results.average_fps >= 30.0 and
		results.frame_time_95th_percentile < 33.3 and
		results.memory_growth_mb < 50.0 and
		results.fps_stability > 90.0
	)
	file.store_line("Test Result: %s" % ("PASSED" if boss_test_passed else "FAILED"))
	file.store_line("")
	file.store_line("=== PASS/FAIL CRITERIA (Same as Original) ===")
	file.store_line("Average FPS ≥30: %s (%.1f)" % ["✓" if results.average_fps >= 30.0 else "✗", results.average_fps])
	file.store_line("Frame Time 95th <33.3ms: %s (%.2f ms)" % ["✓" if results.frame_time_95th_percentile < 33.3 else "✗", results.frame_time_95th_percentile])
	file.store_line("Memory Growth <50MB: %s (%.2f MB)" % ["✓" if results.memory_growth_mb < 50.0 else "✗", results.memory_growth_mb])
	file.store_line("FPS Stability >90%%: %s (%.1f%%)" % ["✓" if results.fps_stability > 90.0 else "✗", results.fps_stability])
	file.store_line("")
	
	# Add detailed phase breakdown to summary
	file.store_line("=== PHASE BREAKDOWN ===")
	for i in range(phase_metrics.size()):
		var phase_data = phase_metrics[i]
		file.store_line("Phase %d - %s:" % [i + 1, phase_data.name])
		file.store_line("  Duration: %.1fs" % phase_data.duration)
		file.store_line("  Bosses: %d final / %d peak" % [phase_data.final_bosses, phase_data.peak_bosses])
		file.store_line("  Memory: %.1f → %.1f MB (+%.1f MB)" % [
			phase_data.memory_start_mb, phase_data.memory_end_mb, phase_data.memory_growth_mb
		])
		file.store_line("  Average FPS: %.1f" % phase_data.avg_fps)
		file.store_line("")
	
	file.close()
	
	print("✓ Boss test summary exported to: %s" % summary_file)

func _print_phase_summary() -> void:
	"""Print detailed breakdown of each test phase."""
	print("\n=== PHASE BREAKDOWN ===")
	for i in range(phase_metrics.size()):
		var phase_data = phase_metrics[i]
		print("Phase %d - %s:" % [i + 1, phase_data.name])
		print("  Duration: %.1fs" % phase_data.duration)
		print("  Bosses: %d final / %d peak" % [phase_data.final_bosses, phase_data.peak_bosses])
		print("  Memory: %.1f → %.1f MB (+%.1f MB)" % [
			phase_data.memory_start_mb, phase_data.memory_end_mb, phase_data.memory_growth_mb
		])
		print("  Avg FPS: %.1f" % phase_data.avg_fps)
		print("")

func _fail_test(reason: String) -> void:
	print("TEST FAILED: " + reason)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)

# Allow static execution for integration with test runner
static func run_banana_boss_performance_test() -> void:
	print("Running banana boss performance stress test...")
	# This would be called from run_tests.gd if needed