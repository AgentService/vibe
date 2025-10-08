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

## OPTION A constants (only used if Option A is active):
const COMBAT_DT: float = 1.0 / 30.0  # Custom accumulator: 10 Hz (100ms per step)
const MAX_PHYSICS_STEPS_PER_FRAME: int = 30  # Custom accumulator: Prevent lag spiral

## OPTION B: Physics tick rate configured in project.godot [physics] section
## Set common/physics_ticks_per_second=10 (or 15, 30) to control update frequency

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

# Accumulator stores leftover frame time between combat steps
var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game (stops time accumulation)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Initialize RNG with seed (0 = use system time for random seed)
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	Logger.info("RunManager initialized (Option A: custom accumulator with interpolation)", "systems")


## OPTION A: Custom Accumulator + Interpolation (ACTIVE)
## ================================================================
## Pros: Deterministic replays, networkable, full control
## Cons: Complex, requires tracking previous/current state in all entities
func _process(delta: float) -> void:
	## Fixed-step accumulator loop
	## Runs multiple combat steps if frame took longer than COMBAT_DT
	## Runs zero steps if frame was too fast (accumulator carries forward)

	# Don't accumulate time when game is paused
	if get_tree().paused:
		return

	# Add frame time to accumulator
	_accumulator += delta

	# Process as many fixed steps as accumulated time allows (up to limit)
	var steps_this_frame: int = 0
	while _accumulator >= COMBAT_DT and steps_this_frame < MAX_PHYSICS_STEPS_PER_FRAME:
		# Create typed payload with fixed timestep
		var payload := EventBus.CombatStepPayload_Type.new(COMBAT_DT)

		# Emit combat step - all systems process this at exactly 30 Hz
		EventBus.combat_step.emit(payload)

		# Subtract one fixed step from accumulator
		_accumulator -= COMBAT_DT
		steps_this_frame += 1

	# If we hit the step limit, clamp accumulator to prevent infinite spiral
	if steps_this_frame >= MAX_PHYSICS_STEPS_PER_FRAME:
		_accumulator = 0.0  # Reset instead of letting debt build up

	# OPTION A: Interpolation for smooth rendering (Glenn Fiedler pattern)
	# Calculate alpha [0,1] representing how far between physics steps we are
	# alpha = 0.0 means we just finished a physics step
	# alpha = 1.0 means we're about to take the next physics step
	var alpha: float = _accumulator / COMBAT_DT

	# Emit render interpolation signal for entities to update visual positions
	# Entities use: render_pos = prev_pos * (1-alpha) + current_pos * alpha
	EventBus.render_interpolate.emit(alpha)

	# HOW TO USE INTERPOLATION IN ENTITIES:
	# ======================================
	# In BaseEnemy/BaseBoss/AbilityProjectile:
	#
	# var _physics_position: Vector2  # Updated in combat_step
	# var _previous_position: Vector2  # Store before updating physics
	#
	# func _on_combat_step(payload):
	#     _previous_position = _physics_position
	#     _physics_position += velocity * payload.delta_time
	#
	# func _on_render_interpolate(alpha: float):
	#     # Smoothly blend between previous and current for rendering
	#     global_position = _previous_position.lerp(_physics_position, alpha)
	#
	# Benefits:
	# - Eliminates visual stuttering at 10Hz physics
	# - Enemies/projectiles appear to move smoothly at 60fps display
	# - Physics logic stays deterministic at fixed timestep


## OPTION B: Godot's _physics_process() (COMMENTED OUT)
## ================================================================
## Pros: Simple, engine-optimized, automatic interpolation, easy tuning
## Cons: Non-deterministic, can't do lockstep networking, no frame-perfect replays
##
## Configure physics tick rate in project.godot:
##   [physics] common/physics_ticks_per_second=10 (for 10Hz)
##   [physics] common/physics_ticks_per_second=30 (for 30Hz)
##
#func _physics_process(delta: float) -> void:
	### Godot's built-in fixed timestep
	### delta is always constant (e.g., 0.1s for 10Hz, 0.033s for 30Hz)
	### Godot automatically handles interpolation for smooth rendering
#
	## Create typed payload with Godot's fixed physics delta
	#var payload := EventBus.CombatStepPayload_Type.new(delta)
#
	## Emit combat step - all systems process at physics tick rate
	#EventBus.combat_step.emit(payload)

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(run_seed)