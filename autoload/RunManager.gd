extends Node

## Fixed-Step Combat Timing Manager (30 Hz) - Task 04 Phase 2 Complete
##
## ARCHITECTURE PATTERN: Fixed-Step Game Loop with Accumulator
## ============================================================
##
## PURPOSE:
## Ensures deterministic, frame-rate-independent combat timing by running game logic
## at a fixed 30 Hz timestep, regardless of the display's refresh rate (60Hz, 144Hz, etc).
##
## NOTE: Run statistics tracking has been migrated to SessionState autoload (Task 04 Phase 2).
##
## WHY 30 HZ?
## - Balance between performance and responsiveness
## - Gives systems 33.33ms per frame to execute logic
## - Smooth enough for top-down action gameplay
## - Compatible with Godot's physics tick rate
##
## ACCUMULATOR PATTERN:
## The accumulator pattern solves the "variable delta time" problem:
##
##   1. Every frame: Add frame time (delta) to accumulator
##   2. While accumulator >= COMBAT_DT (33.33ms):
##      - Emit one combat_step signal
##      - Subtract COMBAT_DT from accumulator
##   3. Leftover accumulator time carries to next frame
##
## EXAMPLE BEHAVIOR:
##   Frame 1 (60 FPS, 16.67ms delta):
##     _accumulator = 16.67ms
##     16.67ms < 33.33ms → No combat step this frame
##
##   Frame 2 (60 FPS, 16.67ms delta):
##     _accumulator = 16.67 + 16.67 = 33.34ms
##     33.34ms >= 33.33ms → Emit 1 combat step
##     _accumulator = 33.34 - 33.33 = 0.01ms (carries forward)
##
##   Frame 3 (144 FPS, 6.94ms delta):
##     _accumulator = 0.01 + 6.94 = 6.95ms
##     6.95ms < 33.33ms → No combat step this frame
##
## RESULT: Combat logic runs at exactly 30 Hz, independent of frame rate.
##
## DETERMINISM:
## - Fixed timestep (COMBAT_DT) ensures consistent physics
## - RNG seeding (run_seed) makes runs reproducible
## - Same seed + same inputs = same results (critical for replays, testing)
##
## SIGNAL EMISSION:
## Systems connect to EventBus.combat_step to run their fixed-step logic:
##   - DamageSystem: Collision detection
##   - SpawnDirector: Enemy spawning
##   - MeleeSystem: Attack cooldowns
##   - Movement: Position updates
##
## PAUSE INTEGRATION:
## - process_mode = PAUSABLE stops accumulator when game paused
## - No time accumulation during pause → freeze game state
## - Resume from exact same state when unpaused
##
## REFERENCES:
## - Glenn Fiedler's "Fix Your Timestep" article: https://gafferongames.com/post/fix_your_timestep/
## - Godot fixed timestep docs: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
## - ARCHITECTURE.md - Fixed-Step Combat Loop (Decision 5a)

## Physics tick rate configured in project.godot [physics] section
## Set common/physics_ticks_per_second to control update frequency (default: 30)
## Set common/physics_interpolation=true for smooth rendering

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

func _ready() -> void:
	# RunManager should pause with the game (stops time accumulation)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Initialize RNG with seed (0 = use system time for random seed)
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	Logger.info("RunManager initialized (using Godot physics_process)", "systems")


## Godot's Built-in Physics Process (ACTIVE)
## ================================================================
## Uses Godot's optimized _physics_process() for fixed timestep combat.
##
## Benefits:
## - Engine-optimized C++ implementation (faster than GDScript accumulator)
## - Automatic physics interpolation via physics_interpolation=true
## - Simple, maintainable code
## - Easy tuning via project.godot settings
##
## Configuration in project.godot:
##   [physics]
##   common/physics_ticks_per_second=30       # Physics tick rate
##   common/physics_interpolation=true        # Smooth rendering
##
## Physics Interpolation:
## - Godot automatically interpolates transforms between physics ticks
## - Works on local transforms in 2D (preserves scene tree pivots)
## - No manual position tracking needed
## - Call reset_physics_interpolation() when teleporting entities
##
func _physics_process(delta: float) -> void:
	# Godot's built-in fixed timestep
	# delta is always constant (e.g., 0.033s for 30Hz)
	# Interpolation handled automatically by engine

	# Create typed payload with Godot's fixed physics delta
	var payload := EventBus.CombatStepPayload_Type.new(delta)

	# Emit combat step - all systems process at physics tick rate
	EventBus.combat_step.emit(payload)

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(run_seed)