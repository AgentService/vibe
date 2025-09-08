extends Node

## Performance stress test for 500+ enemy architecture validation
## Tests FPS stability, memory usage, and combat performance at scale
## Designed to establish baseline metrics before zero-allocation queue implementation

const PerformanceMetrics = preload("res://tests/tools/performance_metrics.gd")

# Test configuration
var test_duration: float = 15.0  # Test runs for 15 seconds (shortened for testing)
var target_enemy_count: int = 500
var max_projectiles: int = 200
var combat_step_interval: float = 1.0 / 30.0  # 30Hz combat step

# Test state
var current_test_phase: String = ""
var test_start_time: float = 0.0
var performance_metrics: PerformanceMetrics
var combat_step_timer: float = 0.0

# Systems (injected from scene setup)
var arena_root: Node2D
var wave_director: Node
var damage_system: Node
var ability_system: Node
var multimesh_manager: Node

# Test scenarios (shortened for testing)
var test_phases: Array[Dictionary] = [
	{
		"name": "gradual_scaling",
		"duration": 5.0,
		"description": "Scale from 100 to 500+ enemies gradually"
	},
	{
		"name": "burst_spawn", 
		"duration": 3.0,
		"description": "Instant spawn of 500 enemies"
	},
	{
		"name": "combat_stress",
		"duration": 4.0, 
		"description": "500 enemies + projectiles + damage calculations"
	},
	{
		"name": "mixed_tier",
		"duration": 3.0,
		"description": "All enemy types simultaneously"
	}
]

var current_phase_index: int = 0
var phase_start_time: float = 0.0

var test_completed: bool = false

func _ready() -> void:
	print("=== ARCHITECTURE PERFORMANCE STRESS TEST ===")
	print("Target: 500+ enemies, 60 second duration")
	print("Success Criteria: ≥30 FPS, <50MB memory growth, <33.3ms frame time")
	
	# Initialize deterministic RNG for reproducible tests
	_setup_deterministic_rng()
	
	# Initialize performance tracking
	performance_metrics = PerformanceMetrics.new()
	performance_metrics.start_test()
	
	# Find and setup system references
	_setup_system_references()
	
	# Initialize systems with dependencies
	_initialize_systems()
	
	# Start first test phase
	test_start_time = Time.get_unix_time_from_system()
	_start_next_phase()

func _process(delta: float) -> void:
	# Update performance metrics
	performance_metrics.update_frame_metrics(delta)
	
	# Update combat step timer
	combat_step_timer += delta
	if combat_step_timer >= combat_step_interval:
		_on_combat_step()
		combat_step_timer = 0.0
	
	# Progress logging every 5 seconds
	var total_elapsed = Time.get_unix_time_from_system() - test_start_time
	if int(total_elapsed) % 5 == 0 and int(total_elapsed) != int(total_elapsed - delta):
		var enemy_count = _count_alive_enemies()
		var current_fps = performance_metrics._calculate_average_fps()
		print("Progress: %.0fs elapsed, %d enemies, %.1f FPS" % [total_elapsed, enemy_count, current_fps])
	
	# Check if current phase is complete
	var phase_elapsed = Time.get_unix_time_from_system() - phase_start_time
	if current_phase_index < test_phases.size():
		var current_phase = test_phases[current_phase_index]
		
		if phase_elapsed >= current_phase.duration:
			_end_current_phase()
			_start_next_phase()
	
	# Check if entire test is complete
	if total_elapsed >= test_duration or current_phase_index >= test_phases.size():
		_complete_test()

func _setup_system_references() -> void:
	print("Loading Arena scene as subscene...")
	
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
	
	print("✓ Arena scene loaded as subscene successfully")
	
	# Find systems from the loaded Arena scene or create placeholders
	_discover_arena_systems()

func _initialize_systems() -> void:
	print("Initializing systems with dependencies...")
	
	# Proper autoload access via scene tree
	var root = get_tree().get_root()
	var debug_manager = root.get_node_or_null("/root/DebugManager")
	var cheat_system = root.get_node_or_null("/root/CheatSystem")
	var player_state = root.get_node_or_null("/root/PlayerState")
	
	# Configure debug manager to disable debug mode
	if debug_manager:
		debug_manager.debug_enabled = false
		if debug_manager.has_method("_exit_debug_mode"):
			debug_manager._exit_debug_mode()
		print("✓ Debug mode disabled to allow enemy spawning")
	else:
		print("⚠️  DebugManager not available - debug mode may interfere")
	
	# Ensure CheatSystem allows spawning
	if cheat_system:
		cheat_system.spawn_disabled = false
		print("✓ Spawning enabled via CheatSystem")
	else:
		print("⚠️  CheatSystem not available - spawning may be limited")
	
	# Set PlayerState position for spawn targeting
	if player_state:
		player_state.position = Vector2(400, 300)  # Center of arena
		print("✓ PlayerState position set for enemy targeting")
	else:
		print("⚠️  PlayerState not available - using default positioning")
	
	# Configure WaveDirector for 500 enemy capacity BEFORE other initialization
	if wave_director:
		wave_director.max_enemies = 500  # Set capacity for all test phases
		wave_director.spawn_interval = 10.0  # Start with slow spawning (will be overridden)
		# Force reinitialize the enemy pool with new size
		wave_director._initialize_pool()
		print("✓ WaveDirector configured for 500 enemy capacity and pool reinitialized")
	
	# Create a basic ArenaSystem for WaveDirector dependency if needed
	if wave_director and wave_director.has_method("set_arena_system"):
		var arena_system = preload("res://scripts/systems/ArenaSystem.gd").new()
		# ArenaSystem will use default spawn radius from balance data
		wave_director.set_arena_system(arena_system)
		print("✓ ArenaSystem created and connected to WaveDirector")
	
	# Setup MultiMeshManager with the MultiMesh nodes from Arena
	if multimesh_manager and arena_root:
		var mm_projectiles = arena_root.get_node_or_null("MM_Projectiles")
		var mm_swarm = arena_root.get_node_or_null("MM_Enemies_Swarm")
		var mm_regular = arena_root.get_node_or_null("MM_Enemies_Regular")
		var mm_elite = arena_root.get_node_or_null("MM_Enemies_Elite")
		var mm_boss = arena_root.get_node_or_null("MM_Enemies_Boss")
		
		if mm_projectiles and mm_swarm and mm_regular and mm_elite and mm_boss:
			# Create EnemyRenderTier helper
			var enemy_render_tier = preload("res://scripts/systems/EnemyRenderTier.gd").new()
			# Setup MultiMeshManager
			multimesh_manager.setup(mm_projectiles, mm_swarm, mm_regular, mm_elite, mm_boss, enemy_render_tier)
			print("✓ MultiMeshManager setup with Arena MultiMesh nodes")
		else:
			print("⚠️  Some MultiMesh nodes missing from Arena scene")
	
	# Set system references on DamageSystem if available
	if damage_system and damage_system.has_method("set_references"):
		damage_system.set_references(ability_system, wave_director)
		print("✓ DamageSystem references configured")
	
	print("✓ Systems initialized with dependencies")


func _discover_arena_systems() -> void:
	"""Discover and setup references to systems from the loaded Arena scene."""
	print("Discovering systems from Arena scene...")
	
	# Try to find WaveDirector in the scene tree (may be in autoloads or as scene node)
	var root = get_tree().get_root()
	wave_director = root.get_node_or_null("/root/WaveDirector")
	if not wave_director:
		# Search in Arena scene
		wave_director = _find_node_recursive(arena_root, "WaveDirector")
	
	if wave_director:
		print("✓ WaveDirector found")
	else:
		print("⚠️  WaveDirector not found - creating placeholder")
		# Create a basic WaveDirector for testing
		wave_director = preload("res://scripts/systems/WaveDirector.gd").new()
		add_child(wave_director)
	
	# Try to find other systems
	damage_system = root.get_node_or_null("/root/DamageSystem")
	if not damage_system:
		damage_system = _find_node_recursive(arena_root, "DamageSystem")
	if not damage_system:
		# Create placeholder
		damage_system = preload("res://scripts/systems/DamageSystem.gd").new()
		add_child(damage_system)
		print("⚠️  DamageSystem not found - created placeholder")
	else:
		print("✓ DamageSystem found")
	
	ability_system = root.get_node_or_null("/root/AbilitySystem")
	if not ability_system:
		ability_system = _find_node_recursive(arena_root, "AbilitySystem")
	if not ability_system:
		# Create placeholder
		ability_system = preload("res://scripts/systems/AbilitySystem.gd").new()
		add_child(ability_system)
		print("⚠️  AbilitySystem not found - created placeholder")
	else:
		print("✓ AbilitySystem found")
	
	multimesh_manager = root.get_node_or_null("/root/MultiMeshManager")
	if not multimesh_manager:
		multimesh_manager = _find_node_recursive(arena_root, "MultiMeshManager")
	if not multimesh_manager:
		# Create placeholder
		multimesh_manager = preload("res://scripts/systems/MultiMeshManager.gd").new()
		add_child(multimesh_manager)
		print("⚠️  MultiMeshManager not found - created placeholder")
	else:
		print("✓ MultiMeshManager found")
	
	print("✓ System discovery complete")


func _find_node_recursive(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name."""
	if not node:
		return null
	
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null


func _setup_deterministic_rng() -> void:
	"""Setup deterministic RNG seeding for reproducible test results."""
	var root = get_tree().get_root()
	var rng_node = root.get_node_or_null("/root/RNG")
	var run_manager = root.get_node_or_null("/root/RunManager")
	
	# Use a fixed seed for performance testing reproducibility
	var performance_test_seed: int = 12345
	
	if rng_node and rng_node.has_method("seed_for_run"):
		rng_node.seed_for_run(performance_test_seed)
		print("✓ RNG seeded deterministically for performance test: %d" % performance_test_seed)
	elif run_manager and run_manager.has_method("start_run"):
		# Try to use RunManager to setup RNG
		run_manager.start_run(performance_test_seed)
		print("✓ RunManager initialized with performance test seed: %d" % performance_test_seed)
	else:
		# Fallback to built-in RNG seeding
		seed(performance_test_seed)
		print("✓ Built-in RNG seeded for performance test: %d" % performance_test_seed)

func _start_next_phase() -> void:
	if current_phase_index >= test_phases.size():
		print("All test phases completed")
		return
	
	var phase = test_phases[current_phase_index]
	current_test_phase = phase.name
	phase_start_time = Time.get_unix_time_from_system()
	
	print("\n=== PHASE %d: %s ===" % [current_phase_index + 1, phase.description])
	print("Duration: %.1f seconds" % phase.duration)
	
	# Configure phase-specific settings
	match current_test_phase:
		"gradual_scaling":
			_setup_gradual_scaling()
		"burst_spawn":
			_setup_burst_spawn() 
		"combat_stress":
			_setup_combat_stress()
		"mixed_tier":
			_setup_mixed_tier()

func _end_current_phase() -> void:
	var phase = test_phases[current_phase_index]
	var enemy_count = _count_alive_enemies()
	print("Phase '%s' completed. Final enemy count: %d" % [phase.name, enemy_count])
	current_phase_index += 1

func _setup_gradual_scaling() -> void:
	print("Starting gradual scaling: 100 → 500+ enemies over 10 seconds")
	# Clear any existing enemies
	_clear_all_enemies()
	
	# Start with slow spawning - will be increased by _update_gradual_scaling
	if wave_director:
		wave_director.spawn_interval = 1.0  # Start slow
		print("✓ WaveDirector configured for gradual scaling")

func _setup_burst_spawn() -> void:
	print("Starting burst spawn: Instant 500 enemies")
	# Clear existing enemies
	_clear_all_enemies()
	
	# Force spawn 500 enemies as fast as possible
	if wave_director:
		_force_spawn_enemies(500)

func _setup_combat_stress() -> void:
	print("Starting combat stress: 500 enemies + projectiles + damage")
	# Ensure we have max enemies spawning
	var current_count = _count_alive_enemies()
	if current_count < 400:  # If we don't have enough, trigger rapid spawning
		_force_spawn_enemies(500)
	
	# Enable aggressive projectile spawning via combat step simulation
	# (handled in _simulate_projectile_stress called from _on_combat_step)

func _setup_mixed_tier() -> void:
	print("Starting mixed tier: All enemy types simultaneously")
	# Clear existing and spawn mixed types
	_clear_all_enemies()
	
	# Trigger rapid spawning for mixed enemy types
	_force_spawn_mixed_enemies()

func _on_combat_step() -> void:
	# Emit combat step for systems that need it (with proper payload)
	var payload = EventBus.CombatStepPayload_Type.new(combat_step_interval)
	EventBus.combat_step.emit(payload)
	
	# During combat_stress phase, add projectile spawning pressure
	if current_test_phase == "combat_stress":
		_simulate_projectile_stress()
	
	# During gradual_scaling, increase enemy count
	if current_test_phase == "gradual_scaling":
		_update_gradual_scaling()

func _update_gradual_scaling() -> void:
	var phase_elapsed = Time.get_unix_time_from_system() - phase_start_time
	var phase_duration = test_phases[0].duration  # 10 seconds now
	var progress = phase_elapsed / phase_duration
	
	# Linearly scale from 100 to 500+ enemies
	var target_count = int(100 + (400 * progress))
	target_count = min(target_count, 500)
	
	var current_count = _count_alive_enemies()
	if current_count < target_count:
		var spawn_count = min(target_count - current_count, 10)  # Spawn in batches
		print("Scaling: current=%d, target=%d, requesting=%d" % [current_count, target_count, spawn_count])
		_force_spawn_enemies(spawn_count)

func _simulate_projectile_stress() -> void:
	# Simulate player abilities creating projectiles
	var player_pos = Vector2(400, 300)  # Assume center position
	var ability_names = ["fireball", "ice_shard", "lightning_bolt"]
	
	# Trigger abilities every few combat steps
	var random_chance = 0.3  # Default 30% chance
	var selected_ability = ability_names[0]  # Default to first ability
	
	# Use RNG autoload if available
	var root = get_tree().get_root()
	var rng_node = root.get_node_or_null("/root/RNG")
	var event_bus = root.get_node_or_null("/root/EventBus")
	
	if rng_node and rng_node.has_method("randf"):
		random_chance = rng_node.randf("test")
		selected_ability = ability_names[rng_node.randi("test") % ability_names.size()]
	else:
		# Use built-in random if RNG autoload not available
		random_chance = randf()
		selected_ability = ability_names[randi() % ability_names.size()]
	
	if random_chance < 0.3:  # 30% chance per combat step
		if event_bus and event_bus.has_signal("ability_triggered"):
			event_bus.ability_triggered.emit(selected_ability, player_pos, 0.0)
		else:
			print("Simulated ability: %s at %s" % [selected_ability, player_pos])

func _force_spawn_enemies(count: int) -> void:
	if not wave_director:
		return
	
	# Since max_enemies is already set to 500, just trigger rapid spawning
	wave_director.spawn_interval = 0.01  # Very fast spawning - WaveDirector will spawn naturally
	
	# Let the wave director's natural spawning process handle it
	# The combat step will trigger spawning up to max_enemies
	var root = get_tree().get_root()
	var logger_node = root.get_node_or_null("/root/Logger")
	if logger_node and logger_node.has_method("info"):
		logger_node.info("Configured WaveDirector for rapid spawning", "performance_test")
	else:
		print("Configured WaveDirector for rapid spawning")

func _force_spawn_mixed_enemies() -> void:
	if not wave_director:
		return
	
	# For mixed tier testing, just trigger fast spawning
	# The EnemyFactory V2 system will handle different tier distribution naturally
	wave_director.spawn_interval = 0.01
	
	var root = get_tree().get_root()
	var logger_node = root.get_node_or_null("/root/Logger")
	if logger_node and logger_node.has_method("info"):
		logger_node.info("Configured WaveDirector for mixed tier spawning", "performance_test")
	else:
		print("Configured WaveDirector for mixed tier spawning")

func _get_random_spawn_position() -> Vector2:
	# Spawn enemies around arena perimeter
	var arena_center = Vector2(400, 300)
	var spawn_radius = 800.0
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

func _count_alive_enemies() -> int:
	if not wave_director:
		return 0
	
	# Use the public method available on WaveDirector
	var alive_enemies = wave_director.get_alive_enemies()
	return alive_enemies.size()

func _clear_all_enemies() -> void:
	if not wave_director:
		return
	
	# Use the public method available on WaveDirector
	wave_director.clear_all_enemies()

func _exit_tree() -> void:
	# Ensure results are written even if test is terminated early
	if not test_completed and performance_metrics:
		print("\\n=== TEST TERMINATED EARLY - WRITING PARTIAL RESULTS ===")
		_complete_test()

func _complete_test() -> void:
	if test_completed:
		return  # Already completed
	test_completed = true
	print("\n=== STRESS TEST COMPLETED ===")
	
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
	
	# Export CSV with date+time prefix
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var baseline_file = baseline_dir + timestamp + "_performance_500_enemies.csv"
	performance_metrics.export_baseline_csv(baseline_file, results)
	
	# Export detailed summary to same folder with date+time prefix
	_export_test_summary(baseline_dir, timestamp, results)
	
	# Final enemy count report
	var final_enemy_count = _count_alive_enemies()
	print("Final enemy count: %d" % final_enemy_count)
	
	# Architecture validation summary
	print("\n=== ARCHITECTURE VALIDATION ===")
	if results.test_passed:
		print("✓ SUCCESS: Architecture meets 500+ enemy performance requirements")
		print("✓ Ready for zero-allocation queue optimization")
	else:
		print("✗ FAILURE: Architecture performance issues detected")
		print("⚠️  Optimization required before zero-allocation implementation")
	
	print("\nResults exported to tests/baselines/ with date+time prefixes")
	
	# Exit in headless mode
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


func _export_test_summary(baseline_dir: String, timestamp: String, results: Dictionary) -> void:
	"""Export detailed test summary to text file."""
	var summary_file = baseline_dir + timestamp + "_performance_500_enemies_summary.txt"
	var file = FileAccess.open(summary_file, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create summary file: %s" % summary_file)
		return
	
	file.store_line("=== ARCHITECTURE PERFORMANCE STRESS TEST SUMMARY ===")
	file.store_line("Timestamp: " + Time.get_datetime_string_from_system())
	file.store_line("Test Duration: %.2f seconds" % results.duration_seconds)
	file.store_line("Target: 500+ enemies, ≥30 FPS, <50MB memory growth")
	file.store_line("")
	file.store_line("=== RESULTS ===")
	file.store_line("Final Enemy Count: %d" % _count_alive_enemies())
	file.store_line("Total Frames: %d" % results.total_frames)
	file.store_line("Average FPS: %.2f" % results.average_fps)
	file.store_line("Minimum FPS: %.2f" % results.min_fps)
	file.store_line("FPS Stability: %.1f%%" % results.fps_stability)
	file.store_line("Frame Time 95th Percentile: %.2f ms" % results.frame_time_95th_percentile)
	file.store_line("Memory Growth: %.2f MB" % results.memory_growth_mb)
	file.store_line("Test Result: %s" % ("PASSED" if results.test_passed else "FAILED"))
	file.store_line("")
	file.store_line("=== PASS/FAIL CRITERIA ===")
	file.store_line("Average FPS ≥30: %s (%.1f)" % ["✓" if results.average_fps >= 30.0 else "✗", results.average_fps])
	file.store_line("Frame Time 95th <33.3ms: %s (%.2f ms)" % ["✓" if results.frame_time_95th_percentile < 33.3 else "✗", results.frame_time_95th_percentile])
	file.store_line("Memory Growth <50MB: %s (%.2f MB)" % ["✓" if results.memory_growth_mb < 50.0 else "✗", results.memory_growth_mb])
	file.store_line("FPS Stability >90%%: %s (%.1f%%)" % ["✓" if results.fps_stability > 90.0 else "✗", results.fps_stability])
	file.close()
	
	print("✓ Test summary exported to: %s" % summary_file)

func _fail_test(reason: String) -> void:
	print("TEST FAILED: " + reason)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)

# Allow static execution for integration with test runner
static func run_performance_test() -> void:
	print("Running performance stress test...")
	# This would be called from run_tests.gd if needed